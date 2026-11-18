package system

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/proxy"
)

var (
	usernameRegex = regexp.MustCompile(`^[a-z_][a-z0-9_-]{0,31}$`)
	uuidRegex     = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
	uuidHexRegex  = regexp.MustCompile(`(?i)^[0-9a-f]{32}$`)
)

type AccountStatus string

const (
	StatusActive  AccountStatus = "active"
	StatusExpired AccountStatus = "expired"
	StatusLocked  AccountStatus = "locked"
)

type Account struct {
	Username          string        `json:"username"`
	UID               int           `json:"uid"`
	GID               int           `json:"gid"`
	GECOS             string        `json:"gecos"`
	UUID              string        `json:"uuid,omitempty"`
	HasUUID           bool          `json:"has_uuid"`
	Limit             int           `json:"limit"`
	HasLimit          bool          `json:"has_limit"`
	TrafficLimitBytes int64         `json:"traffic_limit_bytes,omitempty"`
	HasTrafficLimit   bool          `json:"has_traffic_limit"`
	ExpiryDays        int64         `json:"expiry_days"`
	ExpiryDate        string        `json:"expiry_date"`
	DaysLeft          int           `json:"days_left"` // -999 = ilimitado, 0 = expira hoje, negativo = expirado
	Status            AccountStatus `json:"status"`
	Shell             string        `json:"shell"`
	Home              string        `json:"home"`
}

type AccountManager struct {
	PasswdPath  string
	ShadowPath  string
	Runner      func(name string, args ...string) ([]byte, error)
	StdinRunner func(stdin, name string, args ...string) ([]byte, error)
}

func NewAccountManager(passwdPath, shadowPath string) *AccountManager {
	if passwdPath == "" {
		passwdPath = "/etc/passwd"
	}
	if shadowPath == "" {
		shadowPath = "/etc/shadow"
	}
	return &AccountManager{
		PasswdPath:  passwdPath,
		ShadowPath:  shadowPath,
		Runner:      defaultRunner,
		StdinRunner: defaultStdinRunner,
	}
}

var defaultMgr = NewAccountManager("/etc/passwd", "/etc/shadow")

func DefaultAccountManager() *AccountManager {
	return defaultMgr
}

func defaultRunner(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	return cmd.CombinedOutput()
}

func defaultStdinRunner(stdin, name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.Stdin = bytes.NewBufferString(stdin)
	return cmd.CombinedOutput()
}

// GenerateUUIDv4 gera um UUID versão 4 criptograficamente aleatório RFC 4122
func GenerateUUIDv4() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = (b[6] & 0x0f) | 0x40 // version 4
	b[8] = (b[8] & 0x3f) | 0x80 // variant RFC 4122
	return FormatUUID(b)
}

// FormatUUID formata 16 bytes em string canônica de 36 caracteres
func FormatUUID(b [16]byte) string {
	var buf [36]byte
	hex.Encode(buf[0:8], b[0:4])
	buf[8] = '-'
	hex.Encode(buf[9:13], b[4:6])
	buf[13] = '-'
	hex.Encode(buf[14:18], b[6:8])
	buf[18] = '-'
	hex.Encode(buf[19:23], b[8:10])
	buf[23] = '-'
	hex.Encode(buf[24:36], b[10:16])
	return string(buf[:])
}

// NormalizeUUID converte qualquer formato de UUID (32 hex ou 36 canônico) para 36 caracteres minúsculos
func NormalizeUUID(raw string) (string, bool) {
	raw = strings.TrimSpace(strings.ToLower(raw))
	if uuidRegex.MatchString(raw) {
		return raw, true
	}
	clean := strings.ReplaceAll(raw, "-", "")
	if len(clean) == 32 && uuidHexRegex.MatchString(clean) {
		decoded, err := hex.DecodeString(clean)
		if err == nil && len(decoded) == 16 {
			var b [16]byte
			copy(b[:], decoded)
			return FormatUUID(b), true
		}
	}
	return "", false
}

// GenerateSecurePassword gera uma senha alfanumérica legível de tamanho configurável
func GenerateSecurePassword(length int) string {
	if length < 6 {
		length = 8
	}
	const chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	b := make([]byte, length)
	for i := range b {
		num, err := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		if err != nil {
			b[i] = chars[i%len(chars)]
		} else {
			b[i] = chars[num.Int64()]
		}
	}
	return string(b)
}

// IsValidUsername valida se o nome de usuário é compatível com Linux e não é reservado
func IsValidUsername(u string) bool {
	u = strings.TrimSpace(u)
	if !usernameRegex.MatchString(u) || len(u) < 2 {
		return false
	}
	reserved := map[string]bool{
		"root": true, "daemon": true, "bin": true, "sys": true, "sync": true,
		"games": true, "man": true, "lp": true, "mail": true, "news": true,
		"uucp": true, "proxy": true, "majordomo": true, "postgres": true,
		"mysql": true, "www-data": true, "backup": true, "operator": true,
		"list": true, "irc": true, "gnats": true, "nobody": true, "systemd": true,
	}
	return !reserved[strings.ToLower(u)]
}

// ParseLimitFromGecos extrai limit=N ou limit:N do GECOS (sem confundir com traffic_limit)
func ParseLimitFromGecos(gecos string) (int, bool) {
	gecos = strings.TrimSpace(gecos)
	if gecos == "" {
		return 0, false
	}
	for _, field := range strings.FieldsFunc(gecos, func(r rune) bool {
		return r == ',' || r == ';' || r == ' ' || r == '\t'
	}) {
		key, valStr, found := strings.Cut(field, "=")
		if !found {
			key, valStr, found = strings.Cut(field, ":")
		}
		if !found || !strings.EqualFold(strings.TrimSpace(key), "limit") {
			continue
		}
		if end := strings.IndexByte(valStr, ':'); end >= 0 {
			valStr = valStr[:end]
		}
		if n, err := strconv.Atoi(strings.TrimSpace(valStr)); err == nil && n > 0 {
			return n, true
		}
	}
	return 0, false
}

// ParseTrafficLimitFromGecos extrai traffic_limit_bytes=N ou traffic_limit=N do GECOS
func ParseTrafficLimitFromGecos(gecos string) (int64, bool) {
	gecos = strings.TrimSpace(gecos)
	if gecos == "" {
		return 0, false
	}
	for _, field := range strings.FieldsFunc(gecos, func(r rune) bool {
		return r == ',' || r == ';' || r == ' ' || r == '\t'
	}) {
		key, valStr, found := strings.Cut(field, "=")
		if !found {
			key, valStr, found = strings.Cut(field, ":")
		}
		if !found {
			continue
		}
		key = strings.ToLower(strings.TrimSpace(key))
		if key != "traffic_limit_bytes" && key != "traffic_limit" {
			continue
		}
		if end := strings.IndexByte(valStr, ':'); end >= 0 {
			valStr = valStr[:end]
		}
		if n, err := strconv.ParseInt(strings.TrimSpace(valStr), 10, 64); err == nil && n > 0 {
			return n, true
		}
	}
	return 0, false
}

// ParseTrafficQuotaInput interpreta "0", bytes puros ou unidades como "500MB", "10GB", "1TB".
func ParseTrafficQuotaInput(raw string) (int64, error) {
	s := strings.ToUpper(strings.TrimSpace(raw))
	if s == "" || s == "0" || s == "-" || s == "NONE" || s == "OFF" {
		return 0, nil
	}
	multiplier := float64(1)
	switch {
	case strings.HasSuffix(s, "TIB"):
		multiplier = 1024 * 1024 * 1024 * 1024
		s = strings.TrimSuffix(s, "TIB")
	case strings.HasSuffix(s, "TB"):
		multiplier = 1024 * 1024 * 1024 * 1024
		s = strings.TrimSuffix(s, "TB")
	case strings.HasSuffix(s, "GIB"):
		multiplier = 1024 * 1024 * 1024
		s = strings.TrimSuffix(s, "GIB")
	case strings.HasSuffix(s, "GB"):
		multiplier = 1024 * 1024 * 1024
		s = strings.TrimSuffix(s, "GB")
	case strings.HasSuffix(s, "G"):
		multiplier = 1024 * 1024 * 1024
		s = strings.TrimSuffix(s, "G")
	case strings.HasSuffix(s, "MIB"):
		multiplier = 1024 * 1024
		s = strings.TrimSuffix(s, "MIB")
	case strings.HasSuffix(s, "MB"):
		multiplier = 1024 * 1024
		s = strings.TrimSuffix(s, "MB")
	case strings.HasSuffix(s, "M"):
		multiplier = 1024 * 1024
		s = strings.TrimSuffix(s, "M")
	case strings.HasSuffix(s, "KIB"):
		multiplier = 1024
		s = strings.TrimSuffix(s, "KIB")
	case strings.HasSuffix(s, "KB"):
		multiplier = 1024
		s = strings.TrimSuffix(s, "KB")
	case strings.HasSuffix(s, "K"):
		multiplier = 1024
		s = strings.TrimSuffix(s, "K")
	case strings.HasSuffix(s, "B"):
		s = strings.TrimSuffix(s, "B")
	}
	s = strings.TrimSpace(strings.ReplaceAll(s, ",", "."))
	if multiplier == 1 && !strings.Contains(s, ".") {
		n, err := strconv.ParseInt(s, 10, 64)
		if err != nil || n < 0 {
			return 0, fmt.Errorf("cota inválida: %q", raw)
		}
		return n, nil
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil || f < 0 {
		return 0, fmt.Errorf("cota inválida: %q", raw)
	}
	return int64(f * multiplier), nil
}

// FormatTrafficBytes formata cota em bytes de forma legível (GB/MB/KB).
func FormatTrafficBytes(b int64) string {
	if b <= 0 {
		return "0"
	}
	const (
		kb = 1024
		mb = 1024 * kb
		gb = 1024 * mb
		tb = 1024 * gb
	)
	switch {
	case b >= tb && b%tb == 0:
		return fmt.Sprintf("%d TB", b/tb)
	case b >= gb && b%gb == 0:
		return fmt.Sprintf("%d GB", b/gb)
	case b >= gb:
		return fmt.Sprintf("%.2f GB", float64(b)/float64(gb))
	case b >= mb && b%mb == 0:
		return fmt.Sprintf("%d MB", b/mb)
	case b >= mb:
		return fmt.Sprintf("%.1f MB", float64(b)/float64(mb))
	case b >= kb:
		return fmt.Sprintf("%d KB", b/kb)
	default:
		return fmt.Sprintf("%d B", b)
	}
}

// ParseUUIDFromGecos extrai uuid=... ou uuid:... do GECOS
func ParseUUIDFromGecos(gecos string) (string, bool) {
	gecos = strings.TrimSpace(gecos)
	if gecos == "" {
		return "", false
	}
	lower := strings.ToLower(gecos)
	for _, prefix := range []string{"uuid=", "uuid:"} {
		if idx := strings.Index(lower, prefix); idx != -1 {
			valStr := gecos[idx+len(prefix):]
			if end := strings.IndexAny(valStr, ",; \t"); end != -1 {
				valStr = valStr[:end]
			}
			return NormalizeUUID(valStr)
		}
	}
	return "", false
}

// BuildGecos formata o campo GECOS preservando limite e uuid
func BuildGecos(limit int, uuidStr string) string {
	return BuildGecosWithQuota(limit, 0, uuidStr)
}

// BuildGecosWithQuota formata o campo GECOS preservando limit, traffic_limit_bytes e uuid
func BuildGecosWithQuota(limit int, trafficLimitBytes int64, uuidStr string) string {
	parts := make([]string, 0, 3)
	if limit > 0 {
		parts = append(parts, fmt.Sprintf("limit=%d", limit))
	}
	if trafficLimitBytes > 0 {
		parts = append(parts, fmt.Sprintf("traffic_limit_bytes=%d", trafficLimitBytes))
	}
	if norm, ok := NormalizeUUID(uuidStr); ok {
		parts = append(parts, fmt.Sprintf("uuid=%s", norm))
	}
	return strings.Join(parts, ",")
}

// ListAccounts lista todas as contas de proxy cadastradas no sistema
func (m *AccountManager) ListAccounts() ([]Account, error) {
	passwdFile, err := os.Open(m.PasswdPath)
	if err != nil {
		return nil, fmt.Errorf("abrir %s: %w", m.PasswdPath, err)
	}
	defer passwdFile.Close()

	// Carrega dados de expiração e bloqueio do /etc/shadow
	shadowMap := make(map[string]shadowEntry)
	if shadowFile, err := os.Open(m.ShadowPath); err == nil {
		defer shadowFile.Close()
		scanner := bufio.NewScanner(shadowFile)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.Split(line, ":")
			if len(parts) < 2 {
				continue
			}
			u := parts[0]
			hash := parts[1]
			var expDays int64 = -1
			if len(parts) >= 8 && parts[7] != "" {
				if d, err := strconv.ParseInt(parts[7], 10, 64); err == nil {
					expDays = d
				}
			}
			shadowMap[u] = shadowEntry{
				hash:       hash,
				expiryDays: expDays,
			}
		}
	}

	var accounts []Account
	nowDays := time.Now().Unix() / 86400

	scanner := bufio.NewScanner(passwdFile)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.Split(line, ":")
		if len(parts) < 7 {
			continue
		}

		username := parts[0]
		uid, _ := strconv.Atoi(parts[2])
		gid, _ := strconv.Atoi(parts[3])
		gecos := parts[4]
		home := parts[5]
		shell := parts[6]

		// Ignora conta nobody do sistema (UID 65534)
		if uid == 65534 || username == "nobody" {
			continue
		}

		limit, hasLimit := ParseLimitFromGecos(gecos)
		trafficBytes, hasTraffic := ParseTrafficLimitFromGecos(gecos)
		uuidStr, hasUUID := ParseUUIDFromGecos(gecos)

		// Filtro de contas do proxy:
		// Deve ter UID >= 1000 OU possuir limit/traffic_limit/uuid no GECOS OU possuir shell /bin/false / /usr/sbin/nologin
		isProxyUser := (uid >= 1000) || hasLimit || hasTraffic || hasUUID ||
			strings.HasSuffix(shell, "false") || strings.HasSuffix(shell, "nologin")

		if !isProxyUser || !IsValidUsername(username) {
			continue
		}

		acc := Account{
			Username:          username,
			UID:               uid,
			GID:               gid,
			GECOS:             gecos,
			UUID:              uuidStr,
			HasUUID:           hasUUID,
			Limit:             limit,
			HasLimit:          hasLimit,
			TrafficLimitBytes: trafficBytes,
			HasTrafficLimit:   hasTraffic,
			Shell:             shell,
			Home:              home,
			DaysLeft:          -999, // ilimitado por padrão
			Status:            StatusActive,
		}

		// Checa sombra
		if sh, ok := shadowMap[username]; ok {
			if sh.hash == "*" || sh.hash == "!" || strings.HasPrefix(sh.hash, "!") || len(sh.hash) < 13 {
				acc.Status = StatusLocked
			}
			if sh.expiryDays >= 0 {
				acc.ExpiryDays = sh.expiryDays
				expTime := time.Unix(sh.expiryDays*86400, 0).UTC()
				acc.ExpiryDate = expTime.Format("2006-01-02")
				diff := int(sh.expiryDays - nowDays)
				acc.DaysLeft = diff
				if diff < 0 || (sh.expiryDays == 0) {
					acc.Status = StatusExpired
				}
			}
		}

		accounts = append(accounts, acc)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("ler %s: %w", m.PasswdPath, err)
	}

	sort.Slice(accounts, func(i, j int) bool {
		return accounts[i].Username < accounts[j].Username
	})

	return accounts, nil
}

type shadowEntry struct {
	hash       string
	expiryDays int64
}

// GetAccount busca uma conta específica pelo nome de usuário
func (m *AccountManager) GetAccount(username string) (*Account, error) {
	username = strings.TrimSpace(username)
	if username == "" {
		return nil, errors.New("usuário não informado")
	}
	accounts, err := m.ListAccounts()
	if err != nil {
		return nil, err
	}
	for _, acc := range accounts {
		if acc.Username == username {
			return &acc, nil
		}
	}
	return nil, fmt.Errorf("conta '%s' não encontrada", username)
}

// CreateAccount cria um novo usuário no sistema Linux configurado para o ProxyVT
func (m *AccountManager) CreateAccount(username, password, uuidStr string, limit, days int) error {
	return m.CreateAccountWithQuota(username, password, uuidStr, limit, 0, days)
}

// CreateAccountWithQuota cria um novo usuário Linux incluindo cota opcional de tráfego (traffic_limit_bytes)
func (m *AccountManager) CreateAccountWithQuota(username, password, uuidStr string, limit int, trafficLimitBytes int64, days int) error {
	username = strings.TrimSpace(strings.ToLower(username))
	if !IsValidUsername(username) {
		return fmt.Errorf("nome de usuário '%s' inválido ou reservado pelo sistema", username)
	}
	password = strings.TrimSpace(password)
	if password == "" {
		return errors.New("a senha não pode ser vazia")
	}

	// Verifica se a conta já existe
	if _, err := m.GetAccount(username); err == nil {
		return fmt.Errorf("a conta '%s' já existe", username)
	}

	gecos := BuildGecosWithQuota(limit, trafficLimitBytes, uuidStr)

	// useradd -M -s /bin/false -c "<gecos>" "<username>"
	out, err := m.Runner("useradd", "-M", "-s", "/bin/false", "-c", gecos, username)
	if err != nil {
		return fmt.Errorf("useradd falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}

	// chpasswd para definir a senha com segurança
	chpassInput := fmt.Sprintf("%s:%s\n", username, password)
	if out, err := m.StdinRunner(chpassInput, "chpasswd"); err != nil {
		return fmt.Errorf("chpasswd falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}

	// Se dias > 0, configura data de expiração
	if days > 0 {
		targetDate := time.Now().AddDate(0, 0, days).Format("2006-01-02")
		if out, err := m.Runner("chage", "-E", targetDate, username); err != nil {
			return fmt.Errorf("chage falhou: %s (%w)", strings.TrimSpace(string(out)), err)
		}
	}

	_ = proxy.ReloadPasswd()
	return nil
}

// UpdatePassword altera a senha de um usuário existente
func (m *AccountManager) UpdatePassword(username, newPass string) error {
	username = strings.TrimSpace(username)
	newPass = strings.TrimSpace(newPass)
	if username == "" || newPass == "" {
		return errors.New("usuário e nova senha são obrigatórios")
	}
	input := fmt.Sprintf("%s:%s\n", username, newPass)
	out, err := m.StdinRunner(input, "chpasswd")
	if err != nil {
		return fmt.Errorf("chpasswd falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	return nil
}

// UpdateExpiryDays define a validade em dias a partir de hoje (-1 = ilimitado, 0 = expira hoje, >0 = dias)
func (m *AccountManager) UpdateExpiryDays(username string, days int) error {
	username = strings.TrimSpace(username)
	if username == "" {
		return errors.New("usuário não informado")
	}

	var targetDate string
	if days < 0 {
		targetDate = "-1"
	} else if days == 0 {
		targetDate = "0"
	} else {
		targetDate = time.Now().AddDate(0, 0, days).Format("2006-01-02")
	}

	out, err := m.Runner("chage", "-E", targetDate, username)
	if err != nil {
		return fmt.Errorf("chage falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}

	_ = proxy.ReloadPasswd()
	return nil
}

// UpdateLimit altera o limite de conexões simultâneas preservando cota de tráfego e UUID
func (m *AccountManager) UpdateLimit(username string, newLimit int) error {
	acc, err := m.GetAccount(username)
	if err != nil {
		return err
	}
	newGecos := BuildGecosWithQuota(newLimit, acc.TrafficLimitBytes, acc.UUID)
	out, err := m.Runner("usermod", "-c", newGecos, username)
	if err != nil {
		return fmt.Errorf("usermod falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.ReloadPasswd()
	return nil
}

// UpdateTrafficLimit altera a cota acumulada em bytes (0 = ilimitado) preservando limite e UUID
func (m *AccountManager) UpdateTrafficLimit(username string, trafficLimitBytes int64) error {
	acc, err := m.GetAccount(username)
	if err != nil {
		return err
	}
	if trafficLimitBytes < 0 {
		trafficLimitBytes = 0
	}
	newGecos := BuildGecosWithQuota(acc.Limit, trafficLimitBytes, acc.UUID)
	out, err := m.Runner("usermod", "-c", newGecos, username)
	if err != nil {
		return fmt.Errorf("usermod falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.ReloadPasswd()
	return nil
}

// SetUUID atribui ou rotaciona o UUID de uma conta preservando limite e cota de tráfego
func (m *AccountManager) SetUUID(username, uuidStr string) error {
	acc, err := m.GetAccount(username)
	if err != nil {
		return err
	}
	norm, ok := NormalizeUUID(uuidStr)
	if !ok {
		return fmt.Errorf("uuid '%s' inválido", uuidStr)
	}
	newGecos := BuildGecosWithQuota(acc.Limit, acc.TrafficLimitBytes, norm)
	out, err := m.Runner("usermod", "-c", newGecos, username)
	if err != nil {
		return fmt.Errorf("usermod falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.ReloadPasswd()
	return nil
}

// RemoveUUID remove o UUID de uma conta (rebaixando para SSH puro) e preserva limite e cota
func (m *AccountManager) RemoveUUID(username string) error {
	acc, err := m.GetAccount(username)
	if err != nil {
		return err
	}
	newGecos := BuildGecosWithQuota(acc.Limit, acc.TrafficLimitBytes, "")
	out, err := m.Runner("usermod", "-c", newGecos, username)
	if err != nil {
		return fmt.Errorf("usermod falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.ReloadPasswd()
	return nil
}

// LockAccount bloqueia o acesso da conta no shadow e derruba sessões ativas imediatamente
func (m *AccountManager) LockAccount(username string) error {
	username = strings.TrimSpace(username)
	if username == "" {
		return errors.New("usuário não informado")
	}
	out, err := m.Runner("passwd", "-l", username)
	if err != nil {
		return fmt.Errorf("passwd -l falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.KillUser(username)
	_ = proxy.ReloadPasswd()
	return nil
}

// UnlockAccount desbloqueia a conta no shadow
func (m *AccountManager) UnlockAccount(username string) error {
	username = strings.TrimSpace(username)
	if username == "" {
		return errors.New("usuário não informado")
	}
	out, err := m.Runner("passwd", "-u", username)
	if err != nil {
		return fmt.Errorf("passwd -u falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.ReloadPasswd()
	return nil
}

// DeleteAccount desconecta e exclui permanentemente o usuário do sistema
func (m *AccountManager) DeleteAccount(username string) error {
	username = strings.TrimSpace(username)
	if username == "" {
		return errors.New("usuário não informado")
	}
	_ = proxy.KillUser(username)
	out, err := m.Runner("userdel", "-f", username)
	if err != nil {
		return fmt.Errorf("userdel -f falhou: %s (%w)", strings.TrimSpace(string(out)), err)
	}
	_ = proxy.ReloadPasswd()
	return nil
}

// PurgeExpiredAccounts remove todas as contas com status expirado em massa
func (m *AccountManager) PurgeExpiredAccounts() (int, error) {
	accounts, err := m.ListAccounts()
	if err != nil {
		return 0, err
	}

	count := 0
	for _, acc := range accounts {
		if acc.Status == StatusExpired {
			if err := m.DeleteAccount(acc.Username); err == nil {
				count++
			}
		}
	}
	return count, nil
}

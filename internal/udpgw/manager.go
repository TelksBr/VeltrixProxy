package udpgw

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/system"
)

const (
	ConfigDir        = "/etc/udpgw/conf.d"
	LegacyConfigFile = "/etc/udpgw/config.conf"
	LegacyService    = "udpgw"
	SystemdDir       = "/etc/systemd/system"
	DefaultBinary    = "/usr/local/bin/udpgw"
	DefaultPort      = 7400
)

// Config representa as opções de configuração de uma porta UDPGW
type Config struct {
	Port                int    `json:"port"`
	Listen              string `json:"listen"`                 // ex: 0.0.0.0:7400
	Debug               bool   `json:"debug"`                  // -debug
	MetricsListen       string `json:"metrics_listen"`         // -metrics-listen (vazio por padrão em produção)
	MaxFrame            string `json:"max_frame"`              // -max-frame
	WriteChan           string `json:"write_chan"`             // -write-chan
	UDPBind             string `json:"udp_bind"`               // -udp-bind
	UDPRbuf             string `json:"udp_rbuf"`               // -udp-rbuf
	UDPWbuf             string `json:"udp_wbuf"`               // -udp-wbuf
	MapTTL              string `json:"map_ttl"`                // -map-ttl
	ReapEvery           string `json:"reap_every"`             // -reap-every
	IdleTimeout         string `json:"idle_timeout"`           // -idle-timeout
	MaxClientConns      string `json:"max_client_conns"`       // -max-client-conns
	MaxMapEntries       string `json:"max_map_entries"`        // -max-map-entries
	MaxClients          string `json:"max_clients"`            // -max-clients
	AutoRestartInterval string `json:"auto_restart_interval"`  // -auto-restart-interval
	AutoRestartGrace    string `json:"auto_restart_grace"`     // -auto-restart-grace
}

// GetBinaryPath retorna o caminho do binário udpgw instalado
func GetBinaryPath() string {
	if _, err := os.Stat(DefaultBinary); err == nil {
		return DefaultBinary
	}
	if p, err := exec.LookPath("udpgw"); err == nil {
		return p
	}
	return DefaultBinary
}

// GetServiceName retorna o nome do serviço systemd para a porta (ex: udpgw-7400)
func GetServiceName(port int) string {
	return fmt.Sprintf("udpgw-%d", port)
}

// GetConfigPath retorna o caminho do arquivo de configuração para a porta
func GetConfigPath(port int) string {
	return filepath.Join(ConfigDir, fmt.Sprintf("udpgw-%d.conf", port))
}

// GetServicePath retorna o caminho do arquivo .service para a porta
func GetServicePath(port int) string {
	return filepath.Join(SystemdDir, fmt.Sprintf("udpgw-%d.service", port))
}

// BuildExecStart monta a linha de comando completa do udpgw baseada na configuração
// IMPORTANTE: MetricsListen fica vazio por padrão em produção, não gerando a flag -metrics-listen.
func BuildExecStart(cfg *Config) string {
	bin := GetBinaryPath()
	listen := strings.TrimSpace(cfg.Listen)
	if listen == "" {
		listen = fmt.Sprintf("0.0.0.0:%d", cfg.Port)
	}

	parts := []string{bin, "-listen", listen}
	if cfg.Debug {
		parts = append(parts, "-debug")
	}
	// Métricas são incluídas apenas se expressamente configuradas no menu avançado
	if m := strings.TrimSpace(cfg.MetricsListen); m != "" {
		parts = append(parts, "-metrics-listen", m)
	}
	if v := strings.TrimSpace(cfg.MaxFrame); v != "" {
		parts = append(parts, "-max-frame", v)
	}
	if v := strings.TrimSpace(cfg.WriteChan); v != "" {
		parts = append(parts, "-write-chan", v)
	}
	if v := strings.TrimSpace(cfg.UDPBind); v != "" {
		parts = append(parts, "-udp-bind", v)
	}
	if v := strings.TrimSpace(cfg.UDPRbuf); v != "" {
		parts = append(parts, "-udp-rbuf", v)
	}
	if v := strings.TrimSpace(cfg.UDPWbuf); v != "" {
		parts = append(parts, "-udp-wbuf", v)
	}
	if v := strings.TrimSpace(cfg.MapTTL); v != "" {
		parts = append(parts, "-map-ttl", v)
	}
	if v := strings.TrimSpace(cfg.ReapEvery); v != "" {
		parts = append(parts, "-reap-every", v)
	}
	if v := strings.TrimSpace(cfg.IdleTimeout); v != "" {
		parts = append(parts, "-idle-timeout", v)
	}
	if v := strings.TrimSpace(cfg.MaxClientConns); v != "" {
		parts = append(parts, "-max-client-conns", v)
	}
	if v := strings.TrimSpace(cfg.MaxMapEntries); v != "" {
		parts = append(parts, "-max-map-entries", v)
	}
	if v := strings.TrimSpace(cfg.MaxClients); v != "" {
		parts = append(parts, "-max-clients", v)
	}
	if v := strings.TrimSpace(cfg.AutoRestartInterval); v != "" {
		parts = append(parts, "-auto-restart-interval", v)
	}
	if v := strings.TrimSpace(cfg.AutoRestartGrace); v != "" {
		parts = append(parts, "-auto-restart-grace", v)
	}

	return strings.Join(parts, " ")
}

// LoadPortConfig carrega a configuração da porta a partir de /etc/udpgw/conf.d/udpgw-<port>.conf
func LoadPortConfig(port int) (*Config, error) {
	cfg := &Config{
		Port:          port,
		Listen:        fmt.Sprintf("0.0.0.0:%d", port),
		Debug:         false,
		MetricsListen: "",
	}

	path := GetConfigPath(port)
	data, err := os.ReadFile(path)
	if err != nil {
		// Fallback para legacy config se for a porta padrão
		if port == DefaultPort {
			if legData, err := os.ReadFile(LegacyConfigFile); err == nil {
				parseConfigFile(string(legData), cfg)
			}
		}
		return cfg, nil
	}

	parseConfigFile(string(data), cfg)
	return cfg, nil
}

func parseConfigFile(content string, cfg *Config) {
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.Trim(strings.TrimSpace(parts[1]), "\"")

		switch key {
		case "PORT":
			if p, err := strconv.Atoi(val); err == nil && p > 0 {
				cfg.Port = p
			}
		case "LISTEN":
			if val != "" {
				cfg.Listen = val
			}
		case "DEBUG":
			cfg.Debug = strings.EqualFold(val, "true") || val == "1"
		case "METRICS_LISTEN":
			cfg.MetricsListen = val
		case "MAX_FRAME":
			cfg.MaxFrame = val
		case "WRITE_CHAN":
			cfg.WriteChan = val
		case "UDP_BIND":
			cfg.UDPBind = val
		case "UDP_RBUF":
			cfg.UDPRbuf = val
		case "UDP_WBUF":
			cfg.UDPWbuf = val
		case "MAP_TTL":
			cfg.MapTTL = val
		case "REAP_EVERY":
			cfg.ReapEvery = val
		case "IDLE_TIMEOUT":
			cfg.IdleTimeout = val
		case "MAX_CLIENT_CONNS":
			cfg.MaxClientConns = val
		case "MAX_MAP_ENTRIES":
			cfg.MaxMapEntries = val
		case "MAX_CLIENTS":
			cfg.MaxClients = val
		case "AUTO_RESTART_INTERVAL":
			cfg.AutoRestartInterval = val
		case "AUTO_RESTART_GRACE":
			cfg.AutoRestartGrace = val
		}
	}
}

// WritePortConfig salva a configuração no arquivo /etc/udpgw/conf.d/udpgw-<port>.conf
func WritePortConfig(cfg *Config) error {
	if err := os.MkdirAll(ConfigDir, 0755); err != nil {
		return fmt.Errorf("falha ao criar diretório %s: %w", ConfigDir, err)
	}

	listen := cfg.Listen
	if listen == "" {
		listen = fmt.Sprintf("0.0.0.0:%d", cfg.Port)
	}

	debugStr := "false"
	if cfg.Debug {
		debugStr = "true"
	}

	content := fmt.Sprintf(`PORT=%d
LISTEN=%s
DEBUG=%s
METRICS_LISTEN=%s
MAX_FRAME=%s
WRITE_CHAN=%s
UDP_BIND=%s
UDP_RBUF=%s
UDP_WBUF=%s
MAP_TTL=%s
REAP_EVERY=%s
IDLE_TIMEOUT=%s
MAX_CLIENT_CONNS=%s
MAX_MAP_ENTRIES=%s
MAX_CLIENTS=%s
AUTO_RESTART_INTERVAL=%s
AUTO_RESTART_GRACE=%s
`,
		cfg.Port,
		listen,
		debugStr,
		cfg.MetricsListen,
		cfg.MaxFrame,
		cfg.WriteChan,
		cfg.UDPBind,
		cfg.UDPRbuf,
		cfg.UDPWbuf,
		cfg.MapTTL,
		cfg.ReapEvery,
		cfg.IdleTimeout,
		cfg.MaxClientConns,
		cfg.MaxMapEntries,
		cfg.MaxClients,
		cfg.AutoRestartInterval,
		cfg.AutoRestartGrace,
	)

	return os.WriteFile(GetConfigPath(cfg.Port), []byte(content), 0644)
}

// GenerateServiceUnit cria o arquivo .service systemd para a porta
func GenerateServiceUnit(cfg *Config) error {
	execCmd := BuildExecStart(cfg)
	content := fmt.Sprintf(`[Unit]
Description=Veltrix UDP Gateway port %d
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=%s
Restart=always
RestartSec=2
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
`, cfg.Port, execCmd)

	serviceFile := GetServicePath(cfg.Port)
	if err := os.WriteFile(serviceFile, []byte(content), 0644); err != nil {
		return fmt.Errorf("falha ao criar arquivo de serviço %s: %w", serviceFile, err)
	}
	_ = system.DaemonReload()
	return nil
}

// ListConfiguredPorts lista todas as portas configuradas no sistema
func ListConfiguredPorts() []int {
	portMap := make(map[int]bool)

	// 1. Escanear /etc/systemd/system/udpgw-*.service
	if matches, err := filepath.Glob(filepath.Join(SystemdDir, "udpgw-*.service")); err == nil {
		for _, m := range matches {
			base := filepath.Base(m)
			base = strings.TrimPrefix(base, "udpgw-")
			base = strings.TrimSuffix(base, ".service")
			if p, err := strconv.Atoi(base); err == nil && p > 0 {
				portMap[p] = true
			}
		}
	}

	// 2. Escanear /etc/udpgw/conf.d/udpgw-*.conf
	if matches, err := filepath.Glob(filepath.Join(ConfigDir, "udpgw-*.conf")); err == nil {
		for _, m := range matches {
			base := filepath.Base(m)
			base = strings.TrimPrefix(base, "udpgw-")
			base = strings.TrimSuffix(base, ".conf")
			if p, err := strconv.Atoi(base); err == nil && p > 0 {
				portMap[p] = true
			}
		}
	}

	// 3. Fallback: Checar legacy /etc/udpgw/config.conf
	if len(portMap) == 0 {
		if data, err := os.ReadFile(LegacyConfigFile); err == nil {
			var legCfg Config
			parseConfigFile(string(data), &legCfg)
			if legCfg.Port > 0 {
				portMap[legCfg.Port] = true
			}
		}
	}

	// 4. Fallback: Checar se legacy udpgw.service existe
	if len(portMap) == 0 {
		if _, err := os.Stat(filepath.Join(SystemdDir, "udpgw.service")); err == nil {
			portMap[DefaultPort] = true
		}
	}

	var ports []int
	for p := range portMap {
		ports = append(ports, p)
	}
	sort.Ints(ports)
	return ports
}

// IsPortActive verifica se o serviço da porta está ativo
func IsPortActive(port int) bool {
	svc := GetServiceName(port)
	if system.IsServiceActive(svc) {
		return true
	}
	if port == DefaultPort && system.IsServiceActive(LegacyService) {
		return true
	}
	return false
}

// IsActive verifica se qualquer porta configurada do UDPGW está ativa
func IsActive() bool {
	ports := ListConfiguredPorts()
	for _, p := range ports {
		if IsPortActive(p) {
			return true
		}
	}
	return system.IsServiceActive(LegacyService)
}

// EnsureServiceExists assegura que a unit systemd existe para a porta antes de iniciar
func EnsureServiceExists(port int) error {
	svcPath := GetServicePath(port)
	if _, err := os.Stat(svcPath); err == nil {
		return nil
	}
	cfg, err := LoadPortConfig(port)
	if err != nil {
		return err
	}
	return GenerateServiceUnit(cfg)
}

// CreatePort cria a configuração e o serviço systemd para uma nova porta UDPGW e inicia
func CreatePort(port int) error {
	if port <= 0 || port > 65535 {
		return fmt.Errorf("porta inválida: %d", port)
	}

	cfg := &Config{
		Port:          port,
		Listen:        fmt.Sprintf("0.0.0.0:%d", port),
		Debug:         false,
		MetricsListen: "", // Sem métricas por padrão em produção!
	}

	if err := WritePortConfig(cfg); err != nil {
		return err
	}

	if err := GenerateServiceUnit(cfg); err != nil {
		return err
	}

	svcName := GetServiceName(port)
	_ = system.EnableService(svcName)
	return system.StartService(svcName)
}

// DeletePort para, desabilita e remove a porta UDPGW e seus arquivos
func DeletePort(port int) error {
	svcName := GetServiceName(port)
	_ = system.StopService(svcName)
	cmd := exec.Command("systemctl", "disable", svcName)
	_ = cmd.Run()

	_ = os.Remove(GetServicePath(port))
	_ = os.Remove(GetConfigPath(port))

	if port == DefaultPort {
		if _, err := os.Stat(filepath.Join(SystemdDir, "udpgw.service")); err == nil {
			_ = system.StopService(LegacyService)
			_ = exec.Command("systemctl", "disable", LegacyService).Run()
			_ = os.Remove(filepath.Join(SystemdDir, "udpgw.service"))
		}
	}

	_ = system.DaemonReload()
	_ = exec.Command("systemctl", "reset-failed").Run()
	return nil
}

// StartPort inicia o serviço da porta UDPGW
func StartPort(port int) error {
	if err := EnsureServiceExists(port); err != nil {
		return err
	}
	svcName := GetServiceName(port)
	_ = system.EnableService(svcName)
	return system.StartService(svcName)
}

// StopPort para o serviço da porta UDPGW
func StopPort(port int) error {
	svcName := GetServiceName(port)
	err := system.StopService(svcName)
	if port == DefaultPort && system.IsServiceActive(LegacyService) {
		_ = system.StopService(LegacyService)
	}
	return err
}

// RestartPort reinicia o serviço da porta UDPGW
func RestartPort(port int) error {
	if err := EnsureServiceExists(port); err != nil {
		return err
	}
	svcName := GetServiceName(port)
	_ = system.EnableService(svcName)
	return system.RestartService(svcName)
}

// SaveAndApply salva a configuração e atualiza o serviço systemd correspondente
func SaveAndApply(cfg *Config) error {
	if err := WritePortConfig(cfg); err != nil {
		return err
	}
	if err := GenerateServiceUnit(cfg); err != nil {
		return err
	}
	if IsPortActive(cfg.Port) {
		return RestartPort(cfg.Port)
	}
	return nil
}

// GetConfiguredPort retorna a primeira porta encontrada ou 7400
func GetConfiguredPort() int {
	ports := ListConfiguredPorts()
	if len(ports) > 0 {
		return ports[0]
	}
	return DefaultPort
}

// SetPort função compatível legada para criar/atualizar porta
func SetPort(port int) error {
	return CreatePort(port)
}

// HasLegacyUnits indica se ainda existem units/configs do BadVPN externo (VeltrixUPGW).
func HasLegacyUnits() bool {
	if len(ListConfiguredPorts()) > 0 {
		return true
	}
	if _, err := os.Stat(filepath.Join(SystemdDir, "udpgw.service")); err == nil {
		return true
	}
	if matches, err := filepath.Glob(filepath.Join(SystemdDir, "udpgw-*.service")); err == nil && len(matches) > 0 {
		return true
	}
	if _, err := os.Stat(LegacyConfigFile); err == nil {
		return true
	}
	if matches, err := filepath.Glob(filepath.Join(ConfigDir, "udpgw-*.conf")); err == nil && len(matches) > 0 {
		return true
	}
	return false
}

// DisableAndRemoveAll para, desabilita e remove todos os serviços/configs do udpgw externo.
func DisableAndRemoveAll() error {
	var errs []string

	ports := ListConfiguredPorts()
	seen := make(map[int]bool, len(ports))
	for _, p := range ports {
		seen[p] = true
		if err := DeletePort(p); err != nil {
			errs = append(errs, fmt.Sprintf("porta %d: %v", p, err))
		}
	}

	// Units órfãs (sem conf correspondente) e serviço legado
	if matches, err := filepath.Glob(filepath.Join(SystemdDir, "udpgw-*.service")); err == nil {
		for _, m := range matches {
			base := filepath.Base(m)
			name := strings.TrimSuffix(base, ".service")
			portStr := strings.TrimPrefix(name, "udpgw-")
			if p, err := strconv.Atoi(portStr); err == nil && seen[p] {
				continue
			}
			_ = system.StopService(name)
			_ = exec.Command("systemctl", "disable", name).Run()
			_ = os.Remove(m)
		}
	}

	legacyPath := filepath.Join(SystemdDir, "udpgw.service")
	if _, err := os.Stat(legacyPath); err == nil {
		_ = system.StopService(LegacyService)
		_ = exec.Command("systemctl", "disable", LegacyService).Run()
		_ = os.Remove(legacyPath)
	}

	_ = os.Remove(LegacyConfigFile)
	if matches, err := filepath.Glob(filepath.Join(ConfigDir, "udpgw-*.conf")); err == nil {
		for _, m := range matches {
			_ = os.Remove(m)
		}
	}

	_ = system.DaemonReload()
	_ = exec.Command("systemctl", "reset-failed").Run()

	if len(errs) > 0 {
		return fmt.Errorf("%s", strings.Join(errs, "; "))
	}
	return nil
}

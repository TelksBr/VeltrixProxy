package config

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// PortEntry representa uma porta configurada, podendo conter :ssl
type PortEntry struct {
	Port int  `json:"port"`
	SSL  bool `json:"ssl"`
}

// String retorna a representação no formato "80" ou "443:ssl"
func (p PortEntry) String() string {
	if p.SSL {
		return fmt.Sprintf("%d:ssl", p.Port)
	}
	return strconv.Itoa(p.Port)
}

// ParsePortEntry converte uma string como "443:ssl", "80" ou número em PortEntry
func ParsePortEntry(raw string) (PortEntry, error) {
	raw = strings.TrimSpace(raw)
	isSSL := false
	if strings.HasSuffix(strings.ToLower(raw), ":ssl") {
		isSSL = true
		raw = raw[:len(raw)-4]
	}
	portNum, err := strconv.Atoi(raw)
	if err != nil || portNum <= 0 || portNum > 65535 {
		return PortEntry{}, fmt.Errorf("porta inválida: %s", raw)
	}
	return PortEntry{Port: portNum, SSL: isSSL}, nil
}

// PortList é uma lista flexível de portas que aceita strings ("80", "443:ssl"), inteiros (80) ou objetos
type PortList []string

// UnmarshalJSON suporta array heterogêneo de strings, inteiros ou objetos
func (pl *PortList) UnmarshalJSON(data []byte) error {
	var rawList []json.RawMessage
	if err := json.Unmarshal(data, &rawList); err != nil {
		return err
	}

	result := make([]string, 0, len(rawList))
	for _, raw := range rawList {
		var s string
		if err := json.Unmarshal(raw, &s); err == nil {
			result = append(result, strings.TrimSpace(s))
			continue
		}

		var num int
		if err := json.Unmarshal(raw, &num); err == nil {
			result = append(result, strconv.Itoa(num))
			continue
		}

		var obj struct {
			Port interface{} `json:"port"`
			SSL  bool        `json:"ssl"`
		}
		if err := json.Unmarshal(raw, &obj); err == nil {
			pStr := fmt.Sprintf("%v", obj.Port)
			if obj.SSL {
				pStr += ":ssl"
			}
			result = append(result, pStr)
			continue
		}
	}
	*pl = result
	return nil
}

// Config representa a estrutura principal do /etc/proxyvt/config.json
type Config struct {
	Token          string           `json:"token"`
	Ports          PortList         `json:"ports"`
	LogLevel       string           `json:"log_level"`
	LogFile        string           `json:"log_file"`
	BufferSize     int              `json:"buffer_size"`
	MaxConnections int              `json:"max_connections"`
	IdleTimeout    int              `json:"idle_timeout"`
	WriteTimeout   int              `json:"write_timeout"`
	Cert           string           `json:"cert"`
	CertInternal   bool             `json:"cert_internal"`
	DisplayBanner  bool             `json:"display_banner"`
	Response       string           `json:"response"`
	SSHOnly        bool             `json:"ssh_only"`
	Ulimit         int              `json:"ulimit"`
	SSH            SSHConfig        `json:"ssh"`
	BTUN           BTUNConfig       `json:"btun"`
	Limits         LimitsConfig     `json:"limits"`
	Connectors     ConnectorsConfig `json:"connectors"`
	XHTTP          XHTTPConfig      `json:"xhttp"`
	DNSTT          DNSTTConfig      `json:"dnstt"`
}

// SSHConfig define parâmetros do servidor SSH interno/legado
type SSHConfig struct {
	Internal     bool   `json:"internal"`
	InternalPort int    `json:"internal_port"`
	Port         int    `json:"port"`
	Auth         string `json:"auth"`
	AuthFile     string `json:"auth_file"`
	AllowRoot    bool   `json:"allow_root"`
	Banner       string `json:"banner"`
}

// BTUNConfig define parâmetros do servidor UDP / DT-Proto via interface TUN
type BTUNConfig struct {
	Enable   bool   `json:"enable"`
	Tun      string `json:"tun"`
	Subnet   string `json:"subnet"`
	Auth     string `json:"auth"`
	AuthFile string `json:"auth_file"`
	UDPPort  int    `json:"udp_port"`
}

// LimitsConfig define o controle de limites por usuário e expiração
type LimitsConfig struct {
	Enable              bool   `json:"enable"`
	DefaultUserLimit    int    `json:"default_user_limit"`
	PasswdFile          string `json:"passwd_file"`
	ExpireCheckInterval string `json:"expire_check_interval"`
	KillExpired         bool   `json:"kill_expired"`
}

// ConnectorsConfig define portas para backends externos (OpenVPN e V2Ray)
type ConnectorsConfig struct {
	OpenVPNPort int `json:"openvpn_port"`
	V2RayPort   int `json:"v2ray_port"`
}

// XHTTPConfig define configurações do transporte SplitHTTP (VOID)
type XHTTPConfig struct {
	Path  string `json:"path"`
	Grace int    `json:"grace"`
	Idle  int    `json:"idle"`
}

// DNSTTConfig define parâmetros do servidor DNS Tunneling integrado
type DNSTTConfig struct {
	Enable      bool   `json:"enable"`
	Domain      string `json:"domain"`
	UDP         string `json:"udp"`
	Privkey     string `json:"privkey"`
	PrivkeyFile string `json:"privkey_file"`
	Fallback    string `json:"fallback"`
	Upstream    string `json:"upstream"`
	MTU         int    `json:"mtu"`
}

// NewDefaultConfig gera uma configuração com todos os valores padrão recomendados
func NewDefaultConfig(token string) *Config {
	return &Config{
		Token:          token,
		Ports:          PortList{"80", "443:ssl"},
		LogLevel:       "info",
		LogFile:        "/var/log/proxy/proxy.log",
		BufferSize:     32768,
		MaxConnections: 0,
		IdleTimeout:    0,
		WriteTimeout:   0,
		Cert:           "",
		CertInternal:   true,
		DisplayBanner:  true,
		Response:       "VeltrixProxy",
		SSHOnly:        false,
		Ulimit:         65536,
		SSH: SSHConfig{
			Internal:     true,
			InternalPort: 0,
			Port:         22,
			Auth:         "shadow",
			AuthFile:     "",
			AllowRoot:    true,
			Banner:       "SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3",
		},
		BTUN: BTUNConfig{
			Enable:   true,
			Tun:      "btun0",
			Subnet:   "10.77.0.0/16",
			Auth:     "shadow",
			AuthFile: "/etc/btun/users",
			UDPPort:  0,
		},
		Limits: LimitsConfig{
			Enable:              true,
			DefaultUserLimit:    0,
			PasswdFile:          "/etc/passwd",
			ExpireCheckInterval: "1m",
			KillExpired:         false,
		},
		Connectors: ConnectorsConfig{
			OpenVPNPort: 1194,
			V2RayPort:   1080,
		},
		XHTTP: XHTTPConfig{
			Path:  "/ssh",
			Grace: 15,
			Idle:  60,
		},
		DNSTT: DNSTTConfig{
			Enable:      false,
			Domain:      "",
			UDP:         ":53",
			Privkey:     "",
			PrivkeyFile: "/etc/dnstt/server.key",
			Fallback:    "",
			Upstream:    "",
			MTU:         1232,
		},
	}
}

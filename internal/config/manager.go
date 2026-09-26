package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

const (
	DefaultConfigPath = "/etc/proxyvt/config.json"
	DefaultConfigDir  = "/etc/proxyvt"
)

// Manager gerencia a persistência e manipulação thread-safe do config.json
type Manager struct {
	mu   sync.RWMutex
	path string
	cfg  *Config
}

// NewManager cria uma nova instância do gerenciador
func NewManager(path string) *Manager {
	if path == "" {
		if envPath := os.Getenv("PROXYVT_CONFIG"); envPath != "" {
			path = envPath
		} else {
			path = DefaultConfigPath
		}
	}
	return &Manager{path: path}
}

// Path retorna o caminho do arquivo configurado
func (m *Manager) Path() string {
	return m.path
}

// Load lê o arquivo config.json ou cria o padrão se não existir
func (m *Manager) Load() (*Config, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, err := os.Stat(m.path); os.IsNotExist(err) {
		token := LoadToken()
		m.cfg = NewDefaultConfig(token)
		if err := m.saveLocked(); err != nil {
			return nil, fmt.Errorf("falha ao criar configuração padrão: %w", err)
		}
		return m.cfg, nil
	}

	data, err := os.ReadFile(m.path)
	if err != nil {
		return nil, fmt.Errorf("erro ao ler arquivo %s: %w", m.path, err)
	}

	// Começa com defaults para preencher campos omitidos
	token := LoadToken()
	cfg := NewDefaultConfig(token)
	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("erro ao decodificar JSON de %s: %w", m.path, err)
	}

	needsSave := false
	if cfg.LogFile == "" {
		cfg.LogFile = "/var/log/proxy/proxy.log"
		needsSave = true
	}

	// Persiste seções novas (ztun / hcr / xray / udpgw) se o JSON antigo ainda não as tiver
	var rawKeys map[string]json.RawMessage
	if err := json.Unmarshal(data, &rawKeys); err == nil {
		defaults := NewDefaultConfig(token)
		if rawSSH, ok := rawKeys["ssh"]; ok {
			var sshKeys map[string]json.RawMessage
			if err := json.Unmarshal(rawSSH, &sshKeys); err == nil {
				if _, ok := sshKeys["banner_file"]; !ok {
					cfg.SSH.BannerFile = defaults.SSH.BannerFile
					needsSave = true
				}
				if _, ok := sshKeys["banner_enable"]; !ok {
					cfg.SSH.BannerEnable = defaults.SSH.BannerEnable
					needsSave = true
				}
			}
		} else if cfg.SSH.BannerFile == "" {
			cfg.SSH.BannerFile = defaults.SSH.BannerFile
			needsSave = true
		}
		if _, ok := rawKeys["ztun"]; !ok {
			cfg.Ztun = defaults.Ztun
			needsSave = true
		}
		if rawHCR, ok := rawKeys["hcr"]; !ok {
			cfg.HCR = defaults.HCR
			needsSave = true
		} else {
			var hcrKeys map[string]json.RawMessage
			if err := json.Unmarshal(rawHCR, &hcrKeys); err == nil {
				if _, ok := hcrKeys["transport"]; !ok {
					cfg.HCR.Transport = defaults.HCR.Transport
					needsSave = true
				}
				if _, ok := hcrKeys["tls_internal"]; !ok {
					cfg.HCR.TLSInternal = defaults.HCR.TLSInternal
					needsSave = true
				}
				if _, ok := hcrKeys["tls_cert"]; !ok {
					cfg.HCR.TLSCert = defaults.HCR.TLSCert
					needsSave = true
				}
				if _, ok := hcrKeys["tls_key"]; !ok {
					cfg.HCR.TLSKey = defaults.HCR.TLSKey
					needsSave = true
				}
				if _, ok := hcrKeys["max_sessions"]; !ok {
					cfg.HCR.MaxSessions = defaults.HCR.MaxSessions
					needsSave = true
				}
				if _, ok := hcrKeys["max_source_sessions"]; !ok {
					cfg.HCR.MaxSourceSessions = defaults.HCR.MaxSourceSessions
					needsSave = true
				}
				if _, ok := hcrKeys["max_connections"]; !ok {
					cfg.HCR.MaxConnections = defaults.HCR.MaxConnections
					needsSave = true
				}
				if _, ok := hcrKeys["poll_timeout"]; !ok {
					cfg.HCR.PollTimeout = defaults.HCR.PollTimeout
					needsSave = true
				}
				if _, ok := hcrKeys["idle"]; !ok {
					cfg.HCR.Idle = defaults.HCR.Idle
					needsSave = true
				}
				if _, ok := hcrKeys["max_download_frame"]; !ok {
					cfg.HCR.MaxDownloadFrame = defaults.HCR.MaxDownloadFrame
					needsSave = true
				}
				if _, ok := hcrKeys["max_replay_bytes"]; !ok {
					cfg.HCR.MaxReplayBytes = defaults.HCR.MaxReplayBytes
					needsSave = true
				}
				if _, ok := hcrKeys["session_stats_interval"]; !ok {
					cfg.HCR.SessionStatsInterval = defaults.HCR.SessionStatsInterval
					needsSave = true
				}
			}
		}
		if rawXray, ok := rawKeys["xray"]; !ok {
			cfg.Xray = defaultXrayConfig("")
			needsSave = true
		} else {
			var xrayKeys map[string]json.RawMessage
			if err := json.Unmarshal(rawXray, &xrayKeys); err == nil {
				if _, ok := xrayKeys["enable"]; !ok {
					cfg.Xray.Enable = defaults.Xray.Enable
					needsSave = true
				}
				if _, ok := xrayKeys["path"]; !ok {
					cfg.Xray.Path = defaults.Xray.Path
					needsSave = true
				}
				if _, ok := xrayKeys["protocols"]; !ok {
					cfg.Xray.Protocols = append([]string(nil), defaults.Xray.Protocols...)
					needsSave = true
				}
				if _, ok := xrayKeys["transports"]; !ok {
					cfg.Xray.Transports = append([]string(nil), defaults.Xray.Transports...)
					needsSave = true
				}
				if rawTLS, ok := xrayKeys["tls"]; !ok {
					cfg.Xray.TLS = defaults.Xray.TLS
					needsSave = true
				} else {
					var tlsKeys map[string]json.RawMessage
					if err := json.Unmarshal(rawTLS, &tlsKeys); err == nil {
						if _, ok := tlsKeys["inherit_port"]; !ok {
							cfg.Xray.TLS.InheritPort = defaults.Xray.TLS.InheritPort
							needsSave = true
						}
						if _, ok := tlsKeys["cert_internal"]; !ok {
							cfg.Xray.TLS.CertInternal = defaults.Xray.TLS.CertInternal
							needsSave = true
						}
						if _, ok := tlsKeys["cert_file"]; !ok {
							cfg.Xray.TLS.CertFile = defaults.Xray.TLS.CertFile
							needsSave = true
						}
						if _, ok := tlsKeys["key_file"]; !ok {
							cfg.Xray.TLS.KeyFile = defaults.Xray.TLS.KeyFile
							needsSave = true
						}
					}
				}
				if rawLegacy, ok := xrayKeys["legacy"]; !ok {
					cfg.Xray.Legacy = defaults.Xray.Legacy
					needsSave = true
				} else {
					var legacyKeys map[string]json.RawMessage
					if err := json.Unmarshal(rawLegacy, &legacyKeys); err == nil {
						if _, ok := legacyKeys["enable"]; !ok {
							cfg.Xray.Legacy.Enable = true
							needsSave = true
						}
						if _, ok := legacyKeys["config_file"]; !ok || strings.TrimSpace(cfg.Xray.Legacy.ConfigFile) == "" {
							cfg.Xray.Legacy.ConfigFile = defaults.Xray.Legacy.ConfigFile
							needsSave = true
						}
					}
				}
			}
		}
		if rawUDPGW, ok := rawKeys["udpgw"]; !ok {
			cfg.UDPGW = defaults.UDPGW
			needsSave = true
		} else {
			var udpgwKeys map[string]json.RawMessage
			if err := json.Unmarshal(rawUDPGW, &udpgwKeys); err == nil {
				if _, ok := udpgwKeys["port_min"]; !ok {
					cfg.UDPGW.PortMin = defaults.UDPGW.PortMin
					needsSave = true
				}
				if _, ok := udpgwKeys["port_max"]; !ok {
					cfg.UDPGW.PortMax = defaults.UDPGW.PortMax
					needsSave = true
				}
			}
		}
	}

	beforeMin, beforeMax := cfg.UDPGW.PortMin, cfg.UDPGW.PortMax
	cfg.UDPGW.Normalize()
	if cfg.UDPGW.PortMin != beforeMin || cfg.UDPGW.PortMax != beforeMax {
		needsSave = true
	}

	beforeHCR := cfg.HCR
	cfg.HCR.Normalize()
	if cfg.HCR != beforeHCR {
		needsSave = true
	}

	beforeXray := cfg.Xray
	cfg.Xray.Normalize()
	if !xrayConfigEqual(beforeXray, cfg.Xray) {
		needsSave = true
	}

	m.cfg = cfg
	if needsSave {
		_ = m.saveLocked()
	} else if m.cfg.LogFile != "" {
		_ = os.MkdirAll(filepath.Dir(m.cfg.LogFile), 0755)
	}

	return m.cfg, nil
}

// Get retorna a cópia atual em memória da configuração (ou carrega se nil)
func (m *Manager) Get() (*Config, error) {
	m.mu.RLock()
	if m.cfg != nil {
		defer m.mu.RUnlock()
		return m.cfg, nil
	}
	m.mu.RUnlock()
	return m.Load()
}

// Save persiste a configuração atual atomicamente em disco
func (m *Manager) Save(cfg *Config) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if cfg != nil {
		cfg.UDPGW.Normalize()
		cfg.HCR.Normalize()
		cfg.Xray.Normalize()
	}
	m.cfg = cfg
	return m.saveLocked()
}

// saveLocked grava a configuração atomicamente usando arquivo temporário
func (m *Manager) saveLocked() error {
	if m.cfg == nil {
		return fmt.Errorf("configuração nula")
	}

	dir := filepath.Dir(m.path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("falha ao criar diretório %s: %w", dir, err)
	}

	if m.cfg.LogFile != "" {
		logDir := filepath.Dir(m.cfg.LogFile)
		_ = os.MkdirAll(logDir, 0755)
	}

	data, err := json.MarshalIndent(m.cfg, "", "  ")
	if err != nil {
		return fmt.Errorf("falha ao serializar JSON: %w", err)
	}
	data = append(data, '\n')

	tempFile := m.path + ".tmp"
	if err := os.WriteFile(tempFile, data, 0644); err != nil {
		return fmt.Errorf("falha ao gravar arquivo temporário: %w", err)
	}

	if err := os.Rename(tempFile, m.path); err != nil {
		// Fallback para SOs onde rename sobre arquivo existente falha
		_ = os.Remove(m.path)
		if err := os.Rename(tempFile, m.path); err != nil {
			return fmt.Errorf("falha ao renomear arquivo temporário: %w", err)
		}
	}

	return nil
}

// AddPort adiciona uma porta na lista de portas ativas
func (m *Manager) AddPort(portStr string) error {
	cfg, err := m.Get()
	if err != nil {
		return err
	}

	entry, err := ParsePortEntry(portStr)
	if err != nil {
		return err
	}
	formatted := entry.String()
	basePort := fmt.Sprintf("%d", entry.Port)

	// Remove de portas ativas se já existir (evita duplicatas e atualiza sufixo :ssl se alterado)
	cleanedActive := make([]string, 0, len(cfg.Ports))
	for _, p := range cfg.Ports {
		if !strings.HasPrefix(p, basePort+":") && p != basePort {
			cleanedActive = append(cleanedActive, p)
		}
	}

	cleanedActive = append(cleanedActive, formatted)
	cfg.Ports = cleanedActive

	return m.Save(cfg)
}

// RemovePort remove completamente uma porta do config.json
func (m *Manager) RemovePort(portStr string) error {
	cfg, err := m.Get()
	if err != nil {
		return err
	}

	cleanStr := strings.TrimSpace(portStr)
	basePort := strings.Split(cleanStr, ":")[0]

	cleanedActive := make([]string, 0, len(cfg.Ports))
	for _, p := range cfg.Ports {
		if !strings.HasPrefix(p, basePort+":") && p != basePort {
			cleanedActive = append(cleanedActive, p)
		}
	}

	cfg.Ports = cleanedActive

	return m.Save(cfg)
}

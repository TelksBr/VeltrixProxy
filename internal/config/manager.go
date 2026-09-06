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

	m.cfg = cfg
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

	// Remove de portas ativas se já existir (evita duplicatas)
	cleanedActive := make([]string, 0, len(cfg.Ports))
	for _, p := range cfg.Ports {
		if !strings.HasPrefix(p, basePort+":") && p != basePort {
			cleanedActive = append(cleanedActive, p)
		}
	}

	// Remove de portas desativadas se estiver lá
	cleanedDisabled := make([]string, 0, len(cfg.DisabledPorts))
	for _, p := range cfg.DisabledPorts {
		if !strings.HasPrefix(p, basePort+":") && p != basePort {
			cleanedDisabled = append(cleanedDisabled, p)
		}
	}

	cleanedActive = append(cleanedActive, formatted)
	cfg.Ports = cleanedActive
	cfg.DisabledPorts = cleanedDisabled

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

	cleanedDisabled := make([]string, 0, len(cfg.DisabledPorts))
	for _, p := range cfg.DisabledPorts {
		if !strings.HasPrefix(p, basePort+":") && p != basePort {
			cleanedDisabled = append(cleanedDisabled, p)
		}
	}

	cfg.Ports = cleanedActive
	cfg.DisabledPorts = cleanedDisabled

	return m.Save(cfg)
}

// TogglePort alterna uma porta entre ativa e desativada
func (m *Manager) TogglePort(portStr string) (bool, error) {
	cfg, err := m.Get()
	if err != nil {
		return false, err
	}

	cleanStr := strings.TrimSpace(portStr)
	basePort := strings.Split(cleanStr, ":")[0]

	isActive := false
	var matchingPort string

	for _, p := range cfg.Ports {
		if strings.HasPrefix(p, basePort+":") || p == basePort {
			isActive = true
			matchingPort = p
			break
		}
	}

	if isActive {
		// Desativar: mover de Ports para DisabledPorts
		newActive := make([]string, 0, len(cfg.Ports))
		for _, p := range cfg.Ports {
			if !strings.HasPrefix(p, basePort+":") && p != basePort {
				newActive = append(newActive, p)
			}
		}
		cfg.Ports = newActive
		cfg.DisabledPorts = append(cfg.DisabledPorts, matchingPort)
		return false, m.Save(cfg)
	}

	// Ativar: mover de DisabledPorts para Ports
	for _, p := range cfg.DisabledPorts {
		if strings.HasPrefix(p, basePort+":") || p == basePort {
			matchingPort = p
			break
		}
	}

	if matchingPort == "" {
		matchingPort = cleanStr
	}

	newDisabled := make([]string, 0, len(cfg.DisabledPorts))
	for _, p := range cfg.DisabledPorts {
		if !strings.HasPrefix(p, basePort+":") && p != basePort {
			newDisabled = append(newDisabled, p)
		}
	}
	cfg.DisabledPorts = newDisabled
	cfg.Ports = append(cfg.Ports, matchingPort)

	return true, m.Save(cfg)
}

package config

import (
	"encoding/json"
	"path/filepath"
	"testing"
)

func TestDefaultConfig(t *testing.T) {
	cfg := NewDefaultConfig("TEST_TOKEN")
	if cfg.Token != "TEST_TOKEN" {
		t.Fatalf("esperado TEST_TOKEN, obtido %s", cfg.Token)
	}
	if !cfg.Limits.Enable {
		t.Fatalf("esperado Limits.Enable true por padrão")
	}
	if cfg.XHTTP.Grace != 15 || cfg.XHTTP.Idle != 60 {
		t.Fatalf("esperado xhttp grace=15 e idle=60, obtido %d e %d", cfg.XHTTP.Grace, cfg.XHTTP.Idle)
	}
	if cfg.LogFile != "/var/log/proxy/proxy.log" {
		t.Fatalf("esperado log_file /var/log/proxy/proxy.log, obtido %s", cfg.LogFile)
	}
}

func TestManagerLoadSave(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")

	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatalf("erro ao carregar config: %v", err)
	}

	if len(cfg.Ports) != 2 {
		t.Fatalf("esperado 2 portas por padrão, obtido %d", len(cfg.Ports))
	}

	// Adicionar porta
	if err := mgr.AddPort("8080"); err != nil {
		t.Fatalf("erro ao adicionar porta: %v", err)
	}

	cfg, _ = mgr.Get()
	found := false
	for _, p := range cfg.Ports {
		if p == "8080" {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("porta 8080 não encontrada em Ports")
	}

	// Remover porta
	if err := mgr.RemovePort("8080"); err != nil {
		t.Fatalf("erro ao remover: %v", err)
	}
	cfg, _ = mgr.Get()
	for _, p := range cfg.Ports {
		if p == "8080" {
			t.Fatalf("porta 8080 ainda presente após remoção")
		}
	}
}

func TestHeterogeneousPortList(t *testing.T) {
	jsonRaw := `{"ports": [80, "443:ssl", {"port": 8080, "ssl": false}]}`
	var cfg Config
	if err := json.Unmarshal([]byte(jsonRaw), &cfg); err != nil {
		t.Fatalf("erro ao decodificar portas heterogêneas: %v", err)
	}

	if len(cfg.Ports) != 3 {
		t.Fatalf("esperado 3 portas, obtido %d", len(cfg.Ports))
	}
	if cfg.Ports[0] != "80" || cfg.Ports[1] != "443:ssl" || cfg.Ports[2] != "8080" {
		t.Fatalf("portas inesperadas: %v", cfg.Ports)
	}
}

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

func TestDNSTTConfig(t *testing.T) {
	cfg := NewDefaultConfig("TEST_TOKEN")
	if cfg.DNSTT.Enable != false {
		t.Fatalf("esperado DNSTT.Enable false por padrão")
	}
	if cfg.DNSTT.UDP != ":53" {
		t.Fatalf("esperado DNSTT.UDP :53, obtido %s", cfg.DNSTT.UDP)
	}
	if cfg.DNSTT.MTU != 1232 {
		t.Fatalf("esperado DNSTT.MTU 1232, obtido %d", cfg.DNSTT.MTU)
	}

	jsonRaw := `{
		"dnstt": {
			"enable": true,
			"domain": "t.exemplo.com",
			"udp": ":5300",
			"privkey": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
			"fallback": "127.0.0.1:8888",
			"upstream": "127.0.0.1:22",
			"mtu": 1200
		}
	}`
	var loaded Config
	if err := json.Unmarshal([]byte(jsonRaw), &loaded); err != nil {
		t.Fatalf("erro ao decodificar dnstt: %v", err)
	}
	if !loaded.DNSTT.Enable || loaded.DNSTT.Domain != "t.exemplo.com" || loaded.DNSTT.UDP != ":5300" || loaded.DNSTT.MTU != 1200 {
		t.Fatalf("valores inesperados em DNSTT: %+v", loaded.DNSTT)
	}
}


package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestManagedSSLConfigSurvivesMigration(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(`{"ports":["80","443:ssl"],"ssl":{"domain":"example.com","state_dir":"/secure/acme","auto_renew":false}}`), 0600); err != nil {
		t.Fatal(err)
	}
	mgr := NewManager(path)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.SSL.Domain != "example.com" || cfg.SSL.StateDir != "/secure/acme" || cfg.SSL.RenewEnabled() {
		t.Fatalf("lost SSL settings: %+v", cfg.SSL)
	}
	if err := mgr.Save(cfg); err != nil {
		t.Fatal(err)
	}
	reloaded, err := NewManager(path).Load()
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.SSL.Domain != cfg.SSL.Domain || reloaded.SSL.RenewEnabled() {
		t.Fatalf("migration overwrote SSL: %+v", reloaded.SSL)
	}
	if !(SSLConfig{}).RenewEnabled() {
		t.Fatal("auto renewal must default to enabled")
	}
}

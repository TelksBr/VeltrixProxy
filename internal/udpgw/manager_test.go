package udpgw

import (
	"strings"
	"testing"
)

func TestBuildExecStart_DefaultNoMetrics(t *testing.T) {
	cfg := &Config{
		Port:          7400,
		Listen:        "0.0.0.0:7400",
		Debug:         false,
		MetricsListen: "", // Produção: sem métricas por padrão
	}

	cmd := BuildExecStart(cfg)
	if strings.Contains(cmd, "-metrics-listen") {
		t.Fatalf("esperado que -metrics-listen NÃO estivesse presente por padrão em produção, mas comando gerou: %s", cmd)
	}
	if !strings.Contains(cmd, "-listen 0.0.0.0:7400") {
		t.Fatalf("esperado -listen 0.0.0.0:7400 no comando, obteve: %s", cmd)
	}
	if strings.Contains(cmd, "-debug") {
		t.Fatalf("esperado que -debug estivesse ausente quando Debug=false, obteve: %s", cmd)
	}
}

func TestBuildExecStart_WithMetricsAndAdvancedFlags(t *testing.T) {
	cfg := &Config{
		Port:                7300,
		Listen:              "0.0.0.0:7300",
		Debug:               true,
		MetricsListen:       "127.0.0.1:9091",
		MaxFrame:            "1492",
		WriteChan:           "1024",
		UDPBind:             "192.168.1.1",
		UDPRbuf:             "524288",
		UDPWbuf:             "524288",
		MapTTL:              "90s",
		ReapEvery:           "10s",
		IdleTimeout:         "2m",
		MaxClientConns:      "200",
		MaxMapEntries:       "2048",
		MaxClients:          "100",
		AutoRestartInterval: "24h",
		AutoRestartGrace:    "30s",
	}

	cmd := BuildExecStart(cfg)
	expectedFlags := []string{
		"-listen 0.0.0.0:7300",
		"-debug",
		"-metrics-listen 127.0.0.1:9091",
		"-max-frame 1492",
		"-write-chan 1024",
		"-udp-bind 192.168.1.1",
		"-udp-rbuf 524288",
		"-udp-wbuf 524288",
		"-map-ttl 90s",
		"-reap-every 10s",
		"-idle-timeout 2m",
		"-max-client-conns 200",
		"-max-map-entries 2048",
		"-max-clients 100",
		"-auto-restart-interval 24h",
		"-auto-restart-grace 30s",
	}

	for _, flag := range expectedFlags {
		if !strings.Contains(cmd, flag) {
			t.Errorf("esperado flag %q no comando, obteve: %s", flag, cmd)
		}
	}
}

func TestParseConfigFile(t *testing.T) {
	content := `
PORT=7400
LISTEN=0.0.0.0:7400
DEBUG=true
METRICS_LISTEN=127.0.0.1:9092
MAX_FRAME=1500
MAP_TTL=60s
`
	var cfg Config
	parseConfigFile(content, &cfg)

	if cfg.Port != 7400 {
		t.Errorf("esperado Port=7400, obteve %d", cfg.Port)
	}
	if cfg.Listen != "0.0.0.0:7400" {
		t.Errorf("esperado Listen=0.0.0.0:7400, obteve %s", cfg.Listen)
	}
	if !cfg.Debug {
		t.Errorf("esperado Debug=true, obteve false")
	}
	if cfg.MetricsListen != "127.0.0.1:9092" {
		t.Errorf("esperado MetricsListen=127.0.0.1:9092, obteve %s", cfg.MetricsListen)
	}
	if cfg.MaxFrame != "1500" {
		t.Errorf("esperado MaxFrame=1500, obteve %s", cfg.MaxFrame)
	}
	if cfg.MapTTL != "60s" {
		t.Errorf("esperado MapTTL=60s, obteve %s", cfg.MapTTL)
	}
}

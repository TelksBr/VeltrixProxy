package config

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDefaultConfig(t *testing.T) {
	cfg := NewDefaultConfig("TEST_TOKEN")
	if cfg.Token != "TEST_TOKEN" {
		t.Fatalf("esperado TEST_TOKEN, obtido %s", cfg.Token)
	}
	if cfg.LogLevel != "error" {
		t.Fatalf("esperado LogLevel error por padrão, obtido %s", cfg.LogLevel)
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
	if !cfg.HCR.Enable || cfg.HCR.Transport != "auto" || !cfg.HCR.TLSInternal {
		t.Fatalf("esperado HCR padrão enable/auto/tls_internal, obtido %+v", cfg.HCR)
	}
	if !cfg.SSH.BannerEnable {
		t.Fatalf("esperado ssh.banner_enable=true")
	}
	if cfg.SSH.BannerFile != "/etc/bannerssh" {
		t.Fatalf("esperado ssh.banner_file=/etc/bannerssh, obtido %s", cfg.SSH.BannerFile)
	}
	if !cfg.Xray.Enable || cfg.Xray.Path != DefaultXrayPath || !cfg.Xray.Legacy.Enable {
		t.Fatalf("esperado xray enable/path/legacy, obtido %+v", cfg.Xray)
	}
	if cfg.Xray.Legacy.ConfigFile == "" {
		t.Fatalf("esperado xray.legacy.config_file preenchido")
	}
}

func TestNormalizeLogLevel(t *testing.T) {
	cases := map[string]string{
		"":        "info",
		"verbose": "trace",
		"TRACE":   "trace",
		"warning": "warn",
		"off":     "silent",
		"none":    "silent",
		"error":   "error",
		"debug":   "debug",
	}
	for in, want := range cases {
		if got := NormalizeLogLevel(in); got != want {
			t.Fatalf("NormalizeLogLevel(%q)=%q, esperado %q", in, got, want)
		}
	}
}

func TestManagerInjectsMissingZtun(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")

	// JSON antigo sem seção ztun
	old := `{
  "token": "TOK",
  "ports": ["80"],
  "log_level": "info",
  "log_file": "/var/log/proxy/proxy.log",
  "ssh": {"internal": true},
  "btun": {"enable": true}
}
`
	if err := os.WriteFile(configPath, []byte(old), 0644); err != nil {
		t.Fatalf("falha ao gravar JSON antigo: %v", err)
	}

	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatalf("erro ao carregar: %v", err)
	}
	if !cfg.Ztun.Enable || cfg.Ztun.Auth != "shadow" || cfg.Ztun.Idle != 180 {
		t.Fatalf("esperado ztun padrão ativo após Load, obtido %+v", cfg.Ztun)
	}

	raw, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("falha ao reler arquivo: %v", err)
	}
	var persisted map[string]interface{}
	if err := json.Unmarshal(raw, &persisted); err != nil {
		t.Fatalf("JSON persistido inválido: %v", err)
	}
	ztun, ok := persisted["ztun"].(map[string]interface{})
	if !ok {
		t.Fatalf("ztun não foi persistido no disco: %s", string(raw))
	}
	if enable, _ := ztun["enable"].(bool); !enable {
		t.Fatalf("esperado ztun.enable=true persistido, obtido %+v", ztun)
	}
}

func TestManagerInjectsMissingHCR(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")

	old := `{
  "token": "TOK",
  "ports": ["80"],
  "log_level": "info",
  "log_file": "/var/log/proxy/proxy.log",
  "ssh": {"internal": true},
  "btun": {"enable": true},
  "ztun": {"enable": true}
}
`
	if err := os.WriteFile(configPath, []byte(old), 0644); err != nil {
		t.Fatalf("falha ao gravar JSON antigo: %v", err)
	}

	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatalf("erro ao carregar: %v", err)
	}
	if !cfg.HCR.Enable || cfg.HCR.Transport != "auto" || !cfg.HCR.TLSInternal {
		t.Fatalf("esperado hcr enable/auto/tls_internal após Load, obtido %+v", cfg.HCR)
	}
	if cfg.HCR.MaxSessions != DefaultHCRMaxSessions ||
		cfg.HCR.MaxSourceSessions != DefaultHCRMaxSourceSessions ||
		cfg.HCR.MaxConnections != DefaultHCRMaxConnections ||
		cfg.HCR.PollTimeout != DefaultHCRPollTimeout ||
		cfg.HCR.Idle != DefaultHCRIdle ||
		cfg.HCR.MaxDownloadFrame != DefaultHCRMaxDownloadFrame ||
		cfg.HCR.MaxReplayBytes != DefaultHCRMaxReplayBytes ||
		cfg.HCR.SessionStatsInterval != DefaultHCRSessionStatsInterval {
		t.Fatalf("esperado hcr defaults após Load, obtido %+v", cfg.HCR)
	}

	raw, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("falha ao reler arquivo: %v", err)
	}
	var persisted map[string]interface{}
	if err := json.Unmarshal(raw, &persisted); err != nil {
		t.Fatalf("JSON persistido inválido: %v", err)
	}
	hcr, ok := persisted["hcr"].(map[string]interface{})
	if !ok {
		t.Fatalf("hcr não foi persistido no disco: %s", string(raw))
	}
	if enable, _ := hcr["enable"].(bool); !enable {
		t.Fatalf("esperado hcr.enable=true persistido, obtido %+v", hcr)
	}
	if transport, _ := hcr["transport"].(string); transport != "auto" {
		t.Fatalf("esperado hcr.transport=auto, obtido %+v", hcr)
	}
	if maxConn, _ := hcr["max_connections"].(float64); int(maxConn) != DefaultHCRMaxConnections {
		t.Fatalf("esperado hcr.max_connections=%d persistido, obtido %+v", DefaultHCRMaxConnections, hcr)
	}
}

func TestManagerInjectsMissingSSHBannerFile(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")

	old := `{
  "token": "TOK",
  "ports": ["80"],
  "log_level": "info",
  "log_file": "/var/log/proxy/proxy.log",
  "ssh": {"internal": true, "banner": "SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3"}
}
`
	if err := os.WriteFile(configPath, []byte(old), 0644); err != nil {
		t.Fatalf("falha ao gravar JSON antigo: %v", err)
	}

	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatalf("erro ao carregar: %v", err)
	}
	if !cfg.SSH.BannerEnable {
		t.Fatalf("esperado banner_enable=true após Load")
	}
	if cfg.SSH.BannerFile != "/etc/bannerssh" {
		t.Fatalf("esperado banner_file padrão após Load, obtido %q", cfg.SSH.BannerFile)
	}

	raw, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("falha ao reler arquivo: %v", err)
	}
	var persisted map[string]interface{}
	if err := json.Unmarshal(raw, &persisted); err != nil {
		t.Fatalf("JSON persistido inválido: %v", err)
	}
	ssh, ok := persisted["ssh"].(map[string]interface{})
	if !ok {
		t.Fatalf("ssh não persistido: %s", string(raw))
	}
	if path, _ := ssh["banner_file"].(string); path != "/etc/bannerssh" {
		t.Fatalf("esperado ssh.banner_file persistido, obtido %+v", ssh)
	}
	if enable, _ := ssh["banner_enable"].(bool); !enable {
		t.Fatalf("esperado ssh.banner_enable=true persistido, obtido %+v", ssh)
	}
}

func TestManagerKeepsExplicitSSHBannerEnableFalse(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")

	old := `{
  "token": "TOK",
  "ports": ["80"],
  "log_level": "info",
  "log_file": "/var/log/proxy/proxy.log",
  "ssh": {"internal": true, "banner_enable": false, "banner_file": "/etc/bannerssh"}
}
`
	if err := os.WriteFile(configPath, []byte(old), 0644); err != nil {
		t.Fatalf("falha ao gravar JSON: %v", err)
	}

	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatalf("erro ao carregar: %v", err)
	}
	if cfg.SSH.BannerEnable {
		t.Fatalf("esperado banner_enable=false preservado, obtido true")
	}
	if cfg.SSH.BannerFile != "/etc/bannerssh" {
		t.Fatalf("esperado banner_file preservado, obtido %q", cfg.SSH.BannerFile)
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

func TestZtunConfig(t *testing.T) {
	cfg := NewDefaultConfig("TEST_TOKEN")
	if !cfg.Ztun.Enable {
		t.Fatalf("esperado Ztun.Enable true por padrão")
	}
	if cfg.Ztun.Auth != "shadow" {
		t.Fatalf("esperado Ztun.Auth shadow, obtido %s", cfg.Ztun.Auth)
	}
	if cfg.Ztun.Idle != 180 {
		t.Fatalf("esperado Ztun.Idle 180, obtido %d", cfg.Ztun.Idle)
	}
	if cfg.Ztun.Upstream != "" || cfg.Ztun.AuthFile != "" {
		t.Fatalf("esperado upstream/auth_file vazios por padrão")
	}

	jsonRaw := `{
		"ztun": {
			"enable": false,
			"upstream": "127.0.0.1:9443",
			"auth": "file",
			"auth_file": "/etc/proxy/users",
			"idle": 120
		}
	}`
	var loaded Config
	if err := json.Unmarshal([]byte(jsonRaw), &loaded); err != nil {
		t.Fatalf("erro ao decodificar ztun: %v", err)
	}
	if loaded.Ztun.Enable || loaded.Ztun.Upstream != "127.0.0.1:9443" || loaded.Ztun.Auth != "file" || loaded.Ztun.AuthFile != "/etc/proxy/users" || loaded.Ztun.Idle != 120 {
		t.Fatalf("valores inesperados em Ztun: %+v", loaded.Ztun)
	}
}

func TestManagerInjectsMissingXray(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")
	legacy := filepath.Join(tempDir, "xray.json")
	if err := os.WriteFile(legacy, []byte(`{"inbounds":[]}`), 0644); err != nil {
		t.Fatal(err)
	}
	prev := XrayLegacyCandidates
	XrayLegacyCandidates = []string{legacy}
	t.Cleanup(func() { XrayLegacyCandidates = prev })

	old := `{
  "token": "TOK",
  "ports": ["80"],
  "log_level": "info",
  "log_file": "/var/log/proxy/proxy.log",
  "ssh": {"internal": true},
  "hcr": {"enable": true}
}
`
	if err := os.WriteFile(configPath, []byte(old), 0644); err != nil {
		t.Fatalf("falha ao gravar JSON antigo: %v", err)
	}

	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatalf("erro ao carregar: %v", err)
	}
	if !cfg.Xray.Enable || cfg.Xray.Path != DefaultXrayPath || !cfg.Xray.Legacy.Enable {
		t.Fatalf("esperado xray padrão após Load, obtido %+v", cfg.Xray)
	}
	if cfg.Xray.Legacy.ConfigFile != legacy {
		t.Fatalf("esperado legacy detectado %s, obtido %s", legacy, cfg.Xray.Legacy.ConfigFile)
	}

	raw, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	var persisted map[string]interface{}
	if err := json.Unmarshal(raw, &persisted); err != nil {
		t.Fatal(err)
	}
	xray, ok := persisted["xray"].(map[string]interface{})
	if !ok {
		t.Fatalf("xray não foi persistido: %s", string(raw))
	}
	legacyObj, _ := xray["legacy"].(map[string]interface{})
	if enable, _ := legacyObj["enable"].(bool); !enable {
		t.Fatalf("esperado xray.legacy.enable=true, obtido %+v", legacyObj)
	}
	if path, _ := legacyObj["config_file"].(string); path != legacy {
		t.Fatalf("esperado config_file detectado, obtido %+v", legacyObj)
	}
}

func TestManagerKeepsExplicitXrayLegacyFalse(t *testing.T) {
	tempDir := t.TempDir()
	configPath := filepath.Join(tempDir, "config.json")
	old := `{
  "token": "TOK",
  "ports": ["80"],
  "log_level": "info",
  "log_file": "/var/log/proxy/proxy.log",
  "xray": {
    "enable": true,
    "path": "/vtxray",
    "legacy": {"enable": false, "config_file": "/custom/xray.json"}
  }
}
`
	if err := os.WriteFile(configPath, []byte(old), 0644); err != nil {
		t.Fatal(err)
	}
	mgr := NewManager(configPath)
	cfg, err := mgr.Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Xray.Legacy.Enable {
		t.Fatalf("esperado legacy.enable=false preservado")
	}
	if cfg.Xray.Legacy.ConfigFile != "/custom/xray.json" {
		t.Fatalf("esperado config_file preservado, obtido %s", cfg.Xray.Legacy.ConfigFile)
	}
}

func TestDetectXrayLegacyConfig(t *testing.T) {
	tempDir := t.TempDir()
	hit := filepath.Join(tempDir, "config.json")
	miss := filepath.Join(tempDir, "missing.json")
	if err := os.WriteFile(hit, []byte(`{"inbounds":[]}`), 0644); err != nil {
		t.Fatal(err)
	}
	got, ok := detectXrayLegacyConfig([]string{miss, hit}, DefaultXrayLegacyConfig)
	if !ok || got != hit {
		t.Fatalf("detect=%s ok=%v, esperado %s", got, ok, hit)
	}
	got, ok = detectXrayLegacyConfig([]string{miss}, "/fallback.json")
	if ok || got != "/fallback.json" {
		t.Fatalf("fallback=%s ok=%v", got, ok)
	}
}

func TestEnsureXrayLegacyStub(t *testing.T) {
	tempDir := t.TempDir()
	path := filepath.Join(tempDir, "etc", "xray", "config.json")
	if err := EnsureXrayLegacyStub(path); err != nil {
		t.Fatal(err)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var root map[string]interface{}
	if err := json.Unmarshal(raw, &root); err != nil {
		t.Fatalf("stub inválido: %v", err)
	}
	inbounds, ok := root["inbounds"].([]interface{})
	if !ok || len(inbounds) != 1 {
		t.Fatalf("esperado 1 inbound, obtido %+v", root["inbounds"])
	}
	in, _ := inbounds[0].(map[string]interface{})
	if in["tag"] != "vless-in" || in["protocol"] != "vless" {
		t.Fatalf("esperado tag vless-in / vless, obtido %+v", in)
	}
	if !strings.Contains(string(raw), "/vtxray") || !strings.Contains(string(raw), "8fc81ef3-0156-4888-a89d-4520c38d7a3a") {
		t.Fatalf("stub sem path /vtxray ou client de exemplo: %s", raw)
	}
	original := string(raw)
	if err := os.WriteFile(path, []byte(`{"inbounds":[{"protocol":"vmess"}]}`), 0644); err != nil {
		t.Fatal(err)
	}
	if err := EnsureXrayLegacyStub(path); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(path)
	if string(after) == original {
		t.Fatal("stub sobrescreveu JSON existente")
	}
	if !strings.Contains(string(after), "vmess") {
		t.Fatalf("JSON existente perdido: %s", after)
	}
}

func TestDefaultXraySharePort(t *testing.T) {
	if got := DefaultXraySharePort(PortList{"80", "443:ssl"}); got != 443 {
		t.Fatalf("ssl primeiro: %d", got)
	}
	if got := DefaultXraySharePortFor(PortList{"80", "443:ssl"}, false); got != 80 {
		t.Fatalf("direct prefere plain: %d", got)
	}
	if got := DefaultXraySharePort(PortList{"8080"}); got != 8080 {
		t.Fatalf("unica porta: %d", got)
	}
	if got := DefaultXraySharePort(nil); got != 443 {
		t.Fatalf("vazio: %d", got)
	}
}

func TestXrayPortConfigured(t *testing.T) {
	ports := PortList{"80", "443:ssl"}
	if !XrayPortConfigured(ports, 80) || !XrayPortConfigured(ports, 443) {
		t.Fatal("80 e 443 deveriam estar ativas")
	}
	if XrayPortConfigured(ports, 8443) {
		t.Fatal("8443 não está no proxy")
	}
	if FormatPortList(ports) != "80, 443:ssl" {
		t.Fatalf("format: %s", FormatPortList(ports))
	}
}

func TestBuildXrayShareLinksVLESS(t *testing.T) {
	links, err := BuildXrayShareLinks(XrayShareParams{
		UUID:       "8fc81ef3-0156-4888-a89d-4520c38d7a3a",
		Address:    "1.2.3.4",
		SNI:        "cdn.example.com",
		Port:       443,
		Path:       "/vtxray",
		Remark:     "Talkera",
		TLS:        true,
		Protocols:  []string{"vless"},
		Transports: []string{"ws", "splithttp"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(links) != 2 {
		t.Fatalf("esperado 2 links, obtido %d", len(links))
	}
	ws := links[0].URI
	if !strings.HasPrefix(ws, "vless://8fc81ef3-0156-4888-a89d-4520c38d7a3a@1.2.3.4:443?") {
		t.Fatalf("vless ws: %s", ws)
	}
	if !strings.Contains(ws, "type=ws") || !strings.Contains(ws, "sni=cdn.example.com") {
		t.Fatalf("ws sem type/sni: %s", ws)
	}
	if !strings.Contains(ws, "path=%2Fvtxray") && !strings.Contains(ws, "path=/vtxray") {
		t.Fatalf("ws sem path: %s", ws)
	}
	xhttp := links[1].URI
	if !strings.Contains(xhttp, "type=xhttp") || !strings.Contains(xhttp, "mode=auto") {
		t.Fatalf("xhttp: %s", xhttp)
	}
}

func TestBuildXrayShareLinksVMess(t *testing.T) {
	links, err := BuildXrayShareLinks(XrayShareParams{
		UUID:       "8fc81ef3-0156-4888-a89d-4520c38d7a3a",
		Address:    "edge.example.com",
		SNI:        "edge.example.com",
		Port:       443,
		Path:       "/vtxray",
		Remark:     "vmess-ws",
		TLS:        true,
		Protocols:  []string{"vmess"},
		Transports: []string{"ws"},
	})
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v links=%d", err, len(links))
	}
	uri := links[0].URI
	if !strings.HasPrefix(uri, "vmess://") {
		t.Fatalf("prefixo: %s", uri)
	}
	raw, err := decodeVMessShare(uri)
	if err != nil {
		t.Fatal(err)
	}
	if raw["add"] != "edge.example.com" || raw["port"] != "443" || raw["path"] != "/vtxray" {
		t.Fatalf("card: %#v", raw)
	}
	if raw["net"] != "ws" || raw["tls"] != "tls" || raw["sni"] != "edge.example.com" {
		t.Fatalf("stream: %#v", raw)
	}
	if raw["id"] != "8fc81ef3-0156-4888-a89d-4520c38d7a3a" || raw["aid"] != "0" {
		t.Fatalf("id/aid: %#v", raw)
	}
}

func TestBuildXrayShareLinksVMessUsesXHTTP(t *testing.T) {
	if ShareTransportPrompt([]string{"ws", "splithttp"}) != "ws,xhttp" {
		t.Fatalf("prompt: %s", ShareTransportPrompt([]string{"ws", "splithttp"}))
	}
	links, err := BuildXrayShareLinks(XrayShareParams{
		Address:    "1.2.3.4",
		SNI:        "cdn.example.com",
		Port:       443,
		Path:       "/vtxray",
		TLS:        true,
		Protocols:  []string{"vmess"},
		Transports: []string{"splithttp"},
	})
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v n=%d", err, len(links))
	}
	if links[0].Transport != "xhttp" || strings.Contains(strings.ToLower(links[0].Label), "split") {
		t.Fatalf("label/transport: %+v", links[0])
	}
	raw, err := decodeVMessShare(links[0].URI)
	if err != nil {
		t.Fatal(err)
	}
	if raw["net"] != "xhttp" || raw["mode"] != "auto" {
		t.Fatalf("card v2 deve ser xhttp: %#v", raw)
	}
	if strings.Contains(links[0].URI, "splithttp") {
		t.Fatalf("client v2 ainda tem SplitHTTP: %s", links[0].URI)
	}
}

func TestBuildXrayShareLinksIPv6AndRejects(t *testing.T) {
	links, err := BuildXrayShareLinks(XrayShareParams{
		UUID:       "550e8400-e29b-41d4-a716-446655440000",
		Address:    "2001:db8::1",
		SNI:        "cdn.example.com",
		Port:       8443,
		Path:       "vtxray",
		TLS:        true,
		Protocols:  []string{"vless"},
		Transports: []string{"ws"},
	})
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v n=%d", err, len(links))
	}
	if !strings.Contains(links[0].URI, "[2001:db8::1]:8443") {
		t.Fatalf("ipv6: %s", links[0].URI)
	}
	if _, err := BuildXrayShareLinks(XrayShareParams{UUID: "nope", Address: "h", Port: 443, Protocols: []string{"vless"}, Transports: []string{"ws"}}); err == nil {
		t.Fatal("uuid inválido deveria falhar")
	}
	if _, err := BuildXrayShareLinks(XrayShareParams{UUID: "550e8400-e29b-41d4-a716-446655440000", Port: 443, Protocols: []string{"vless"}, Transports: []string{"ws"}}); err == nil {
		t.Fatal("host vazio deveria falhar")
	}
	if _, err := BuildXrayShareLinks(XrayShareParams{Address: "1.2.3.4", Port: 443, TLS: true, Protocols: []string{"vless"}, Transports: []string{"ws"}}); err == nil {
		t.Fatal("tls sem sni deveria falhar")
	}
}

func TestBuildXrayShareLinksDefaultUUIDAndDirect(t *testing.T) {
	links, err := BuildXrayShareLinks(XrayShareParams{
		Address:    "1.2.3.4",
		Port:       80,
		Path:       "/vtxray",
		TLS:        false,
		Protocols:  []string{"vless"},
		Transports: []string{"ws"},
	})
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v n=%d", err, len(links))
	}
	uri := links[0].URI
	if !strings.Contains(uri, "vless://"+DefaultXrayShareUUID+"@1.2.3.4:80") {
		t.Fatalf("uuid padrao: %s", uri)
	}
	if strings.Contains(uri, "sni=") || strings.Contains(uri, "security=tls") {
		t.Fatalf("direct nao pode ter sni/tls: %s", uri)
	}
	if !strings.Contains(uri, "security=none") {
		t.Fatalf("direct sem security=none: %s", uri)
	}
}

func TestBuildXrayShareLinksPCS(t *testing.T) {
	const pcs = "017e53a24035a56ef5a7688d92526a3907c396f8643163a4df5e4204be141e4e"
	base := XrayShareParams{
		Address:    "webportals.cachefly.net",
		SNI:        "webportals.cachefly.net",
		Port:       443,
		Path:       "/vtxray",
		TLS:        true,
		PCS:        strings.ToUpper(pcs),
		Transports: []string{"ws"},
	}

	vless := base
	vless.Protocols = []string{"vless"}
	links, err := BuildXrayShareLinks(vless)
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v n=%d", err, len(links))
	}
	if !strings.Contains(links[0].URI, "pcs="+pcs) {
		t.Fatalf("vless sem pcs: %s", links[0].URI)
	}

	vmess := base
	vmess.Protocols = []string{"vmess"}
	links, err = BuildXrayShareLinks(vmess)
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v n=%d", err, len(links))
	}
	card, err := decodeVMessShare(links[0].URI)
	if err != nil {
		t.Fatal(err)
	}
	if card["pcs"] != pcs {
		t.Fatalf("vmess sem pcs: %#v", card)
	}

	direct := vless
	direct.TLS = false
	links, err = BuildXrayShareLinks(direct)
	if err != nil || len(links) != 1 {
		t.Fatalf("err=%v n=%d", err, len(links))
	}
	if strings.Contains(links[0].URI, "pcs=") {
		t.Fatalf("direct nao pode ter pcs: %s", links[0].URI)
	}

	bad := vless
	bad.PCS = "xyz"
	if _, err := BuildXrayShareLinks(bad); err == nil {
		t.Fatal("pcs inválido deveria falhar")
	}
}

func decodeVMessShare(uri string) (map[string]string, error) {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(uri, "vmess://"))
	if err != nil {
		return nil, err
	}
	var card map[string]string
	if err := json.Unmarshal(raw, &card); err != nil {
		return nil, err
	}
	return card, nil
}



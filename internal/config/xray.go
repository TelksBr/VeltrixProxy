package config

import (
	"crypto/rand"
	"encoding/base64"
	"os"
	"path/filepath"
	"reflect"
	"strings"
)

const (
	DefaultXrayPath             = "/vtxray"
	DefaultXrayLegacyConfig     = "/usr/local/etc/xray/config.json"
	DefaultXrayShareUUID        = "8fc81ef3-0156-4888-a89d-4520c38d7a3a"
	DefaultXrayGRPCService      = "vtxray"
	DefaultXraySS2022Method     = "2022-blake3-aes-128-gcm"
	DefaultXrayMASQUESubnet     = "10.13.0.1/24"
	DefaultXrayMASQUEPath       = "/.well-known/masque/ip/*/*/"
	DefaultXrayTrafficUsageFile = "/var/lib/vtproxy/xray-traffic-usage.json"
)

var (
	DefaultXrayProtocols  = []string{"vless", "vmess", "trojan", "socks", "http", "shadowsocks"}
	DefaultXrayTransports = []string{"ws", "splithttp", "httpupgrade", "grpc", "tcp", "mkcp", "hysteria"}
)

// XrayLegacyCandidates is the install-time search order for an existing
// Xray/V2Ray/3x-ui config.json that panels use as the UUID source.
var XrayLegacyCandidates = []string{
	"/usr/local/etc/xray/config.json",
	"/etc/xray/config.json",
	"/usr/local/x-ui/bin/config.json",
	"/usr/local/etc/v2ray/config.json",
	"/etc/v2ray/config.json",
	"/etc/x-ui/x-ui.json",
}

// XrayTLSConfig mirrors proxyvt xray.tls (v1 inherits the proxy port TLS).
type XrayTLSConfig struct {
	InheritPort  bool   `json:"inherit_port"`
	CertFile     string `json:"cert_file"`
	KeyFile      string `json:"key_file"`
	CertInternal bool   `json:"cert_internal"`
}

// XrayLegacyConfig is the optional UUID fallback from a panel/xray.json.
type XrayLegacyConfig struct {
	Enable     bool   `json:"enable"`
	ConfigFile string `json:"config_file"`
}

// XrayConfig configures the in-process Xray motor, dedicated listeners, and optional native core.
type XrayConfig struct {
	Enable             bool             `json:"enable"`
	Path               string           `json:"path"`
	WSPath             string           `json:"ws_path"`
	SplitHTTPPath      string           `json:"splithttp_path"`
	HTTPUpgradePath    string           `json:"httpupgrade_path"`
	SplitHTTPConfig    string           `json:"splithttp_config"`
	Protocols          []string         `json:"protocols"`
	Transports         []string         `json:"transports"`
	GRPCService        string           `json:"grpc_service"`
	H3                 bool             `json:"h3"`
	H3Config           string           `json:"h3_config"`
	UDPListen          string           `json:"udp_listen"`
	TCPFinalMaskListen string           `json:"tcp_finalmask_listen"`
	TCPFinalMaskConfig string           `json:"tcp_finalmask_config"`
	KCPListen          string           `json:"kcp_listen"`
	KCPTLS             bool             `json:"kcp_tls"`
	KCPCertFile        string           `json:"kcp_cert_file"`
	KCPKeyFile         string           `json:"kcp_key_file"`
	KCPConfig          string           `json:"kcp_config"`
	HysteriaListen     string           `json:"hysteria_listen"`
	HysteriaConfig     string           `json:"hysteria_config"`
	UDPFinalMaskConfig string           `json:"udp_finalmask_config"`
	SS2022Listen       string           `json:"ss2022_listen"`
	SS2022Method       string           `json:"ss2022_method"`
	SS2022MasterKey    string           `json:"ss2022_master_key"`
	MASQUEListen       string           `json:"masque_listen"`
	MASQUESubnet       string           `json:"masque_subnet"`
	MASQUEPath         string           `json:"masque_path"`
	WireGuardConfig    string           `json:"wireguard_config"`
	XDriveConfig       string           `json:"xdrive_config"`
	NativeConfig       string           `json:"native_config"`
	SyncPasswd         bool             `json:"sync_passwd"`
	TrafficUsageFile   string           `json:"traffic_usage_file"`
	TLS                XrayTLSConfig    `json:"tls"`
	Legacy             XrayLegacyConfig `json:"legacy"`
}

func defaultXrayConfig(legacyPath string) XrayConfig {
	legacyPath = strings.TrimSpace(legacyPath)
	if legacyPath == "" {
		if detected, ok := DetectXrayLegacyConfig(); ok {
			legacyPath = detected
		} else {
			legacyPath = DefaultXrayLegacyConfig
		}
	}
	return XrayConfig{
		Enable:           true,
		Path:             DefaultXrayPath,
		Protocols:        append([]string(nil), DefaultXrayProtocols...),
		Transports:       append([]string(nil), DefaultXrayTransports...),
		GRPCService:      DefaultXrayGRPCService,
		H3:               true,
		SS2022Method:     DefaultXraySS2022Method,
		MASQUESubnet:     DefaultXrayMASQUESubnet,
		MASQUEPath:       DefaultXrayMASQUEPath,
		TrafficUsageFile: DefaultXrayTrafficUsageFile,
		TLS: XrayTLSConfig{
			InheritPort:  true,
			CertInternal: true,
		},
		Legacy: XrayLegacyConfig{
			Enable:     true,
			ConfigFile: legacyPath,
		},
	}
}

// RequiresSyncPasswd reports whether any configured dedicated listener requires sync_passwd=true.
func (x XrayConfig) RequiresSyncPasswd() bool {
	return strings.TrimSpace(x.SS2022Listen) != "" ||
		strings.TrimSpace(x.MASQUEListen) != "" ||
		strings.TrimSpace(x.WireGuardConfig) != "" ||
		strings.TrimSpace(x.XDriveConfig) != ""
}

// CanEnableSyncPasswd reports whether sync_passwd=true is valid (native_config or dedicated listener configured).
func (x XrayConfig) CanEnableSyncPasswd() bool {
	return x.RequiresSyncPasswd() || strings.TrimSpace(x.NativeConfig) != ""
}

func normalizeOptionalHTTPPath(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if !strings.HasPrefix(raw, "/") {
		return "/" + raw
	}
	return raw
}

// Normalize fills empty Xray fields and keeps dependent flags consistent.
func (x *XrayConfig) Normalize() {
	if strings.TrimSpace(x.Path) == "" {
		x.Path = DefaultXrayPath
	}
	if !strings.HasPrefix(x.Path, "/") {
		x.Path = "/" + x.Path
	}
	x.WSPath = normalizeOptionalHTTPPath(x.WSPath)
	x.SplitHTTPPath = normalizeOptionalHTTPPath(x.SplitHTTPPath)
	x.HTTPUpgradePath = normalizeOptionalHTTPPath(x.HTTPUpgradePath)
	x.SplitHTTPConfig = strings.TrimSpace(x.SplitHTTPConfig)
	x.H3Config = strings.TrimSpace(x.H3Config)
	x.UDPListen = strings.TrimSpace(x.UDPListen)
	x.TCPFinalMaskListen = strings.TrimSpace(x.TCPFinalMaskListen)
	x.TCPFinalMaskConfig = strings.TrimSpace(x.TCPFinalMaskConfig)
	x.KCPListen = strings.TrimSpace(x.KCPListen)
	x.KCPCertFile = strings.TrimSpace(x.KCPCertFile)
	x.KCPKeyFile = strings.TrimSpace(x.KCPKeyFile)
	x.KCPConfig = strings.TrimSpace(x.KCPConfig)
	x.HysteriaListen = strings.TrimSpace(x.HysteriaListen)
	x.HysteriaConfig = strings.TrimSpace(x.HysteriaConfig)
	x.UDPFinalMaskConfig = strings.TrimSpace(x.UDPFinalMaskConfig)
	x.SS2022Listen = strings.TrimSpace(x.SS2022Listen)
	x.SS2022MasterKey = strings.TrimSpace(x.SS2022MasterKey)
	x.MASQUEListen = strings.TrimSpace(x.MASQUEListen)
	x.WireGuardConfig = strings.TrimSpace(x.WireGuardConfig)
	x.XDriveConfig = strings.TrimSpace(x.XDriveConfig)
	x.NativeConfig = strings.TrimSpace(x.NativeConfig)

	x.Protocols = normalizeXrayProtocols(x.Protocols, DefaultXrayProtocols)
	x.Transports = normalizeXrayTransports(x.Transports, DefaultXrayTransports)

	if strings.TrimSpace(x.GRPCService) == "" {
		x.GRPCService = DefaultXrayGRPCService
	}
	switch strings.ToLower(strings.TrimSpace(x.SS2022Method)) {
	case "2022-blake3-aes-256-gcm", "aes-256", "256":
		x.SS2022Method = "2022-blake3-aes-256-gcm"
	default:
		x.SS2022Method = DefaultXraySS2022Method
	}
	if strings.TrimSpace(x.MASQUESubnet) == "" {
		x.MASQUESubnet = DefaultXrayMASQUESubnet
	}
	if strings.TrimSpace(x.MASQUEPath) == "" {
		x.MASQUEPath = DefaultXrayMASQUEPath
	} else if !strings.HasPrefix(x.MASQUEPath, "/") {
		x.MASQUEPath = "/" + strings.TrimSpace(x.MASQUEPath)
	}
	if strings.TrimSpace(x.TrafficUsageFile) == "" {
		x.TrafficUsageFile = DefaultXrayTrafficUsageFile
	}
	if strings.TrimSpace(x.Legacy.ConfigFile) == "" {
		if detected, ok := DetectXrayLegacyConfig(); ok {
			x.Legacy.ConfigFile = detected
		} else {
			x.Legacy.ConfigFile = DefaultXrayLegacyConfig
		}
	}
	if x.RequiresSyncPasswd() {
		x.SyncPasswd = true
	} else if x.SyncPasswd && !x.CanEnableSyncPasswd() {
		x.SyncPasswd = false
	}
}

// GenerateSS2022MasterKey generates a random Base64 master key of the required size (16B or 32B).
func GenerateSS2022MasterKey(method string) string {
	size := 16
	if strings.Contains(strings.ToLower(method), "256") {
		size = 32
	}
	buf := make([]byte, size)
	_, _ = rand.Read(buf)
	return base64.StdEncoding.EncodeToString(buf)
}

func xrayConfigEqual(a, b XrayConfig) bool {
	return reflect.DeepEqual(a, b)
}

func isLegacyDefaultProtocols(in []string) bool {
	norm := normalizeXrayProtocols(in, nil)
	return reflect.DeepEqual(norm, []string{"vless", "vmess"}) ||
		reflect.DeepEqual(norm, []string{"vless", "vmess", "trojan"})
}

func isLegacyDefaultTransports(in []string) bool {
	norm := normalizeXrayTransports(in, nil)
	return reflect.DeepEqual(norm, []string{"ws", "splithttp"}) ||
		reflect.DeepEqual(norm, []string{"ws", "splithttp", "httpupgrade", "grpc", "tcp"})
}

func normalizeXrayProtocols(in, fallback []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(in))
	for _, raw := range in {
		item := strings.ToLower(strings.TrimSpace(raw))
		switch item {
		case "all":
			return append([]string(nil), DefaultXrayProtocols...)
		case "vless", "vmess", "trojan":
		case "socks", "socks5":
			item = "socks"
		case "http", "http-connect", "httpconnect":
			item = "http"
		case "shadowsocks", "ss":
			item = "shadowsocks"
		default:
			continue
		}
		if !seen[item] {
			seen[item] = true
			out = append(out, item)
		}
	}
	if len(out) == 0 && len(fallback) > 0 {
		return append([]string(nil), fallback...)
	}
	return out
}

func normalizeXrayTransports(in, fallback []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(in))
	for _, raw := range in {
		item := strings.ToLower(strings.TrimSpace(raw))
		switch item {
		case "all":
			return append([]string(nil), DefaultXrayTransports...)
		case "ws", "websocket":
			item = "ws"
		case "splithttp", "xhttp", "split":
			item = "splithttp"
		case "httpupgrade", "upgrade":
			item = "httpupgrade"
		case "grpc", "gun":
			item = "grpc"
		case "tcp", "raw":
			item = "tcp"
		case "mkcp", "kcp":
			item = "mkcp"
		case "hysteria", "hysteria-transport":
			item = "hysteria"
		default:
			continue
		}
		if !seen[item] {
			seen[item] = true
			out = append(out, item)
		}
	}
	if len(out) == 0 && len(fallback) > 0 {
		return append([]string(nil), fallback...)
	}
	return out
}

func normalizeCSVList(in, fallback []string, allowed map[string]bool) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(in))
	for _, raw := range in {
		item := strings.ToLower(strings.TrimSpace(raw))
		if item == "xhttp" {
			item = "splithttp"
		}
		if item == "" || !allowed[item] || seen[item] {
			continue
		}
		seen[item] = true
		out = append(out, item)
	}
	if len(out) == 0 && len(fallback) > 0 {
		return append([]string(nil), fallback...)
	}
	return out
}

// DetectXrayLegacyConfig returns the first existing candidate and true,
// or DefaultXrayLegacyConfig and false when none exist.
func DetectXrayLegacyConfig() (string, bool) {
	return detectXrayLegacyConfig(XrayLegacyCandidates, DefaultXrayLegacyConfig)
}

func detectXrayLegacyConfig(candidates []string, fallback string) (string, bool) {
	for _, p := range candidates {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		st, err := os.Stat(p)
		if err == nil && st.Mode().IsRegular() && st.Size() > 0 {
			return p, true
		}
	}
	if fallback == "" {
		fallback = DefaultXrayLegacyConfig
	}
	return fallback, false
}

// EnsureXrayLegacyStub writes a one-inbound Xray JSON so panels/scripts can
// register UUIDs. Existing non-empty files are left untouched.
func EnsureXrayLegacyStub(path string) error {
	path = strings.TrimSpace(path)
	if path == "" {
		path = DefaultXrayLegacyConfig
	}
	if st, err := os.Stat(path); err == nil && st.Mode().IsRegular() && st.Size() > 0 {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(xrayLegacyStubJSON), 0644)
}

const xrayLegacyStubJSON = `{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "8fc81ef3-0156-4888-a89d-4520c38d7a3a",
            "email": "user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vtxray"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
`

package config

import (
	"os"
	"path/filepath"
	"strings"
)

const (
	DefaultXrayPath         = "/vtxray"
	DefaultXrayLegacyConfig = "/usr/local/etc/xray/config.json"
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

// XrayConfig is the in-process VLESS/VMess motor on path /vtxray.
type XrayConfig struct {
	Enable     bool            `json:"enable"`
	Path       string          `json:"path"`
	Protocols  []string        `json:"protocols"`
	Transports []string        `json:"transports"`
	TLS        XrayTLSConfig   `json:"tls"`
	Legacy     XrayLegacyConfig `json:"legacy"`
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
		Enable:     true,
		Path:       DefaultXrayPath,
		Protocols:  []string{"vless", "vmess"},
		Transports: []string{"ws", "splithttp"},
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

// Normalize fills empty Xray fields. Does not overwrite an explicit path.
func (x *XrayConfig) Normalize() {
	if strings.TrimSpace(x.Path) == "" {
		x.Path = DefaultXrayPath
	}
	if !strings.HasPrefix(x.Path, "/") {
		x.Path = "/" + x.Path
	}
	x.Protocols = normalizeCSVList(x.Protocols, []string{"vless", "vmess"}, map[string]bool{
		"vless": true,
		"vmess": true,
	})
	x.Transports = normalizeCSVList(x.Transports, []string{"ws", "splithttp"}, map[string]bool{
		"ws":        true,
		"splithttp": true,
		"xhttp":     true,
	})
	if strings.TrimSpace(x.Legacy.ConfigFile) == "" {
		if detected, ok := DetectXrayLegacyConfig(); ok {
			x.Legacy.ConfigFile = detected
		} else {
			x.Legacy.ConfigFile = DefaultXrayLegacyConfig
		}
	}
}

func xrayConfigEqual(a, b XrayConfig) bool {
	if a.Enable != b.Enable || a.Path != b.Path || a.TLS != b.TLS || a.Legacy != b.Legacy {
		return false
	}
	if len(a.Protocols) != len(b.Protocols) || len(a.Transports) != len(b.Transports) {
		return false
	}
	for i := range a.Protocols {
		if a.Protocols[i] != b.Protocols[i] {
			return false
		}
	}
	for i := range a.Transports {
		if a.Transports[i] != b.Transports[i] {
			return false
		}
	}
	return true
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
	if len(out) == 0 {
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

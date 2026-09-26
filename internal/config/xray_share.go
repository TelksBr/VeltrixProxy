package config

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

var (
	shareUUIDRe = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
	sharePCSRe  = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// XrayShareParams is the client-side share card. Path comes from xray.path.
// Address is the dial target (VMess "add"), Host the WS/XHTTP Host header and
// SNI the TLS serverName; they may all differ (CDN / fronting setups).
type XrayShareParams struct {
	UUID       string
	Address    string
	Host       string
	SNI        string
	Port       int
	Path       string
	Remark     string
	TLS        bool
	PCS        string // pinned peer cert SHA-256 (hex), TLS only
	Protocols  []string
	Transports []string
}

// XrayShareLink is one importable URI (v2rayN / Nekobox / Xray).
type XrayShareLink struct {
	Protocol  string
	Transport string
	Label     string
	URI       string
}

// DefaultXraySharePort picks the first :ssl listen port, else the first port, else 443.
func DefaultXraySharePort(ports PortList) int {
	return DefaultXraySharePortFor(ports, true)
}

// DefaultXraySharePortFor prefers :ssl when tls, and a plain port when direct.
func DefaultXraySharePortFor(ports PortList, tls bool) int {
	ssl, plain := 0, 0
	for _, raw := range ports {
		entry, err := ParsePortEntry(raw)
		if err != nil {
			continue
		}
		if entry.SSL && ssl == 0 {
			ssl = entry.Port
		}
		if !entry.SSL && plain == 0 {
			plain = entry.Port
		}
	}
	if tls {
		if ssl > 0 {
			return ssl
		}
		if plain > 0 {
			return plain
		}
		return 443
	}
	if plain > 0 {
		return plain
	}
	if ssl > 0 {
		return ssl
	}
	return 80
}

// XrayPortConfigured reports whether port is listed in the proxy listen ports.
func XrayPortConfigured(ports PortList, port int) bool {
	if port <= 0 {
		return false
	}
	for _, raw := range ports {
		entry, err := ParsePortEntry(raw)
		if err != nil {
			continue
		}
		if entry.Port == port {
			return true
		}
	}
	return false
}

// FormatPortList joins configured ports for display ("80, 443:ssl").
func FormatPortList(ports PortList) string {
	if len(ports) == 0 {
		return "-"
	}
	out := make([]string, 0, len(ports))
	for _, raw := range ports {
		raw = strings.TrimSpace(raw)
		if raw != "" {
			out = append(out, raw)
		}
	}
	if len(out) == 0 {
		return "-"
	}
	return strings.Join(out, ", ")
}

func (x XrayConfig) AllowsProtocol(name string) bool {
	name = strings.ToLower(strings.TrimSpace(name))
	for _, item := range x.Protocols {
		if item == name {
			return true
		}
	}
	return false
}

func (x XrayConfig) AllowsTransport(name string) bool {
	name = strings.ToLower(strings.TrimSpace(name))
	if name == "xhttp" {
		name = "splithttp"
	}
	for _, item := range x.Transports {
		if item == name {
			return true
		}
	}
	return false
}

// BuildXrayShareLinks builds VLESS/VMess URIs for the enabled proto×transport pairs.
func BuildXrayShareLinks(p XrayShareParams) ([]XrayShareLink, error) {
	uuid := strings.ToLower(strings.TrimSpace(p.UUID))
	if uuid == "" {
		uuid = DefaultXrayShareUUID
	}
	if !shareUUIDRe.MatchString(uuid) {
		return nil, fmt.Errorf("uuid inválido")
	}
	addr := strings.TrimSpace(p.Address)
	if addr == "" {
		return nil, fmt.Errorf("proxy host vazio")
	}
	if p.Port <= 0 || p.Port > 65535 {
		return nil, fmt.Errorf("porta inválida")
	}
	path := strings.TrimSpace(p.Path)
	if path == "" {
		path = DefaultXrayPath
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	sni := ""
	pcs := ""
	hostHeader := strings.TrimSpace(p.Host)
	if hostHeader == "" && p.TLS {
		hostHeader = strings.TrimSpace(p.SNI)
	}
	if hostHeader == "" {
		hostHeader = addr
	}
	if p.TLS {
		sni = strings.TrimSpace(p.SNI)
		if sni == "" {
			sni = hostHeader
		}
		if sni == "" || net.ParseIP(strings.Trim(sni, "[]")) != nil {
			return nil, fmt.Errorf("sni obrigatório no modo tls (domínio, não IP)")
		}
		pcs = strings.ToLower(strings.ReplaceAll(strings.TrimSpace(p.PCS), ":", ""))
		if pcs != "" && !sharePCSRe.MatchString(pcs) {
			return nil, fmt.Errorf("pcs inválido")
		}
	}

	protos := normalizeCSVList(p.Protocols, nil, map[string]bool{"vless": true, "vmess": true})
	transports := normalizeCSVList(p.Transports, nil, map[string]bool{
		"ws": true, "splithttp": true, "xhttp": true,
	})
	if len(protos) == 0 || len(transports) == 0 {
		return nil, fmt.Errorf("nenhum protocolo ou transporte habilitado")
	}

	remark := strings.TrimSpace(p.Remark)
	out := make([]XrayShareLink, 0, len(protos)*len(transports))
	for _, proto := range protos {
		for _, tr := range transports {
			wire := shareWireTransport(tr)
			label := shareLabel(proto, wire, p.TLS)
			var uri string
			var err error
			switch proto {
			case "vless":
				uri, err = buildVLESSShare(uuid, addr, p.Port, path, hostHeader, sni, pcs, remark, wire, p.TLS)
			case "vmess":
				uri, err = buildVMessShare(uuid, addr, p.Port, path, hostHeader, sni, pcs, remark, wire, p.TLS)
			}
			if err != nil {
				return nil, err
			}
			out = append(out, XrayShareLink{
				Protocol:  proto,
				Transport: wire,
				Label:     label,
				URI:       uri,
			})
		}
	}
	return out, nil
}

func shareWireTransport(name string) string {
	if name == "splithttp" || name == "xhttp" {
		return "xhttp"
	}
	return "ws"
}

// ShareTransportPrompt maps config names to the client labels (xhttp, not SplitHTTP).
func ShareTransportPrompt(transports []string) string {
	out := make([]string, 0, len(transports))
	seen := map[string]bool{}
	for _, raw := range transports {
		name := shareWireTransport(strings.ToLower(strings.TrimSpace(raw)))
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		out = append(out, name)
	}
	if len(out) == 0 {
		return "ws,xhttp"
	}
	return strings.Join(out, ",")
}

func shareLabel(proto, transport string, tls bool) string {
	sec := "direct"
	if tls {
		sec = "TLS"
	}
	return strings.ToUpper(proto) + " + " + transport + " + " + sec
}

func shareDialHost(addr string, port int) string {
	if ip := net.ParseIP(addr); ip != nil && ip.To4() == nil {
		return net.JoinHostPort(addr, strconv.Itoa(port))
	}
	if strings.Contains(addr, ":") && !strings.HasPrefix(addr, "[") {
		return net.JoinHostPort(addr, strconv.Itoa(port))
	}
	return addr + ":" + strconv.Itoa(port)
}

func buildVLESSShare(uuid, addr string, port int, path, host, sni, pcs, remark, transport string, tls bool) (string, error) {
	q := url.Values{}
	q.Set("encryption", "none")
	q.Set("type", transport)
	q.Set("path", path)
	if host != "" {
		q.Set("host", host)
	}
	if tls {
		q.Set("security", "tls")
		if sni != "" {
			q.Set("sni", sni)
		}
		q.Set("fp", "chrome")
		if pcs != "" {
			q.Set("pcs", pcs)
		}
		if transport == "xhttp" {
			q.Set("alpn", "h2,http/1.1")
			q.Set("mode", "auto")
		} else {
			q.Set("alpn", "http/1.1")
		}
	} else {
		q.Set("security", "none")
		if transport == "xhttp" {
			q.Set("mode", "auto")
		}
	}
	u := url.URL{
		Scheme:   "vless",
		User:     url.User(uuid),
		Host:     shareDialHost(addr, port),
		RawQuery: q.Encode(),
		Fragment: remark,
	}
	return u.String(), nil
}

func buildVMessShare(uuid, addr string, port int, path, host, sni, pcs, remark, transport string, tls bool) (string, error) {
	card := map[string]string{
		"v":    "2",
		"ps":   remark,
		"add":  addr,
		"port": strconv.Itoa(port),
		"id":   uuid,
		"aid":  "0",
		"scy":  "auto",
		"net":  transport,
		"type": "none",
		"host": host,
		"path": path,
	}
	if transport == "xhttp" {
		card["net"] = "xhttp"
		card["mode"] = "auto"
	}
	if tls {
		card["tls"] = "tls"
		if sni != "" {
			card["sni"] = sni
		}
		card["fp"] = "chrome"
		if pcs != "" {
			card["pcs"] = pcs
		}
		if transport == "xhttp" {
			card["alpn"] = "h2,http/1.1"
		}
	}
	raw, err := json.Marshal(card)
	if err != nil {
		return "", err
	}
	return "vmess://" + base64.StdEncoding.EncodeToString(raw), nil
}

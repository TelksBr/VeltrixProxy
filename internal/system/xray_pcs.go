package system

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// XrayPCSAPIURL returns {"pcs": "<sha256 hex>"} or {"error": "..."} for ?domain=.
var XrayPCSAPIURL = "https://xray.nulled.pp.ua/api/fingerprint"

var (
	pcsHexRe      = regexp.MustCompile(`^[0-9a-f]{64}$`)
	pcsHTTPClient = &http.Client{Timeout: 20 * time.Second}
)

type xrayPCSResponse struct {
	Domain      string `json:"domain"`
	Fingerprint string `json:"fingerprint"`
	PCS         string `json:"pcs"`
	ValidTo     string `json:"validTo"`
	Error       string `json:"error"`
}

// XrayPCSResult is the pinned cert SHA-256 (pcs) of a TLS domain.
type XrayPCSResult struct {
	Domain  string
	PCS     string
	ValidTo string
}

// XrayPCSDomain returns the first candidate that is a domain (not an IP).
// Callers pass SNI first: the client pins the certificate served for its SNI.
func XrayPCSDomain(candidates ...string) string {
	for _, raw := range candidates {
		host := stripHostPort(raw)
		if host != "" && net.ParseIP(host) == nil {
			return host
		}
	}
	return ""
}

func stripHostPort(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if h, _, err := net.SplitHostPort(raw); err == nil {
		raw = h
	}
	return strings.Trim(raw, "[]")
}

// FetchXrayPCS queries the fingerprint API for the certificate served by domain.
func FetchXrayPCS(ctx context.Context, domain string) (XrayPCSResult, error) {
	domain = stripHostPort(domain)
	if domain == "" {
		return XrayPCSResult{}, fmt.Errorf("domínio vazio")
	}

	reqURL := XrayPCSAPIURL + "?domain=" + url.QueryEscape(domain)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return XrayPCSResult{}, err
	}
	req.Header.Set("Accept", "*/*")
	req.Header.Set("Accept-Language", "pt,pt-BR;q=0.9,en;q=0.8")
	req.Header.Set("Referer", "https://xray.nulled.pp.ua/")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36")

	resp, err := pcsHTTPClient.Do(req)
	if err != nil {
		return XrayPCSResult{}, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
	if err != nil {
		return XrayPCSResult{}, err
	}

	var parsed xrayPCSResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return XrayPCSResult{}, fmt.Errorf("resposta inválida da API (HTTP %d)", resp.StatusCode)
	}
	if parsed.Error != "" {
		return XrayPCSResult{}, fmt.Errorf("%s", parsed.Error)
	}
	if resp.StatusCode != http.StatusOK {
		return XrayPCSResult{}, fmt.Errorf("API retornou HTTP %d", resp.StatusCode)
	}

	pcs := strings.ToLower(strings.TrimSpace(parsed.PCS))
	if pcs == "" {
		pcs = strings.ToLower(strings.TrimSpace(parsed.Fingerprint))
	}
	pcs = strings.ReplaceAll(pcs, ":", "")
	if !pcsHexRe.MatchString(pcs) {
		return XrayPCSResult{}, fmt.Errorf("pcs inválido retornado pela API")
	}
	return XrayPCSResult{Domain: domain, PCS: pcs, ValidTo: parsed.ValidTo}, nil
}

package system

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

var (
	CurrentMenuVersion = "3.0.0"
)

const (
	ProxyRepo       = "TelksBr/VeltrixProxy"
	UDPGWRepo       = "TelksBr/VeltrixUPGW"
	UpdateCacheFile = "/tmp/.vt_update_check.json"
	UpdateCacheTTL  = 1 * time.Hour
)

// ComponentStatus detalha o status de versão de um componente
type ComponentStatus struct {
	Name             string `json:"name"`
	InstalledVersion string `json:"installed_version"`
	RemoteVersion    string `json:"remote_version"`
	HasUpdate        bool   `json:"has_update"`
}

// UpdateCheckResult agrupa o status de atualização de todo o sistema
type UpdateCheckResult struct {
	Proxy        ComponentStatus `json:"proxy"`
	UDPGW        ComponentStatus `json:"udpgw"`
	Menu         ComponentStatus `json:"menu"`
	HasAnyUpdate bool            `json:"has_any_update"`
	LastChecked  time.Time       `json:"last_checked"`
}

var (
	updateMu     sync.RWMutex
	cachedResult *UpdateCheckResult
	httpClient   = &http.Client{
		Timeout: 4 * time.Second,
	}
)

// CleanVersion normaliza uma string de versão (remove prefixos como 'v', 'go-v', espaços)
func CleanVersion(v string) string {
	v = strings.TrimSpace(v)
	v = strings.TrimPrefix(v, "go-")
	v = strings.TrimPrefix(v, "v")
	return v
}

// CompareVersions compara duas versões semânticas.
// Retorna 1 se v1 > v2, -1 se v1 < v2, e 0 se forem iguais.
func CompareVersions(v1, v2 string) int {
	c1 := CleanVersion(v1)
	c2 := CleanVersion(v2)
	if c1 == c2 {
		return 0
	}
	if c1 == "" || c1 == "desconhecida" {
		return -1
	}
	if c2 == "" || c2 == "desconhecida" {
		return 1
	}

	parts1 := strings.Split(c1, ".")
	parts2 := strings.Split(c2, ".")

	maxLen := len(parts1)
	if len(parts2) > maxLen {
		maxLen = len(parts2)
	}

	for i := 0; i < maxLen; i++ {
		var n1, n2 int
		if i < len(parts1) {
			numStr := strings.Split(parts1[i], "-")[0]
			n1, _ = strconv.Atoi(numStr)
		}
		if i < len(parts2) {
			numStr := strings.Split(parts2[i], "-")[0]
			n2, _ = strconv.Atoi(numStr)
		}

		if n1 > n2 {
			return 1
		}
		if n1 < n2 {
			return -1
		}
	}

	return 0
}

// IsNewerVersion verifica se remoteVersion é mais recente que installedVersion
func IsNewerVersion(remote, installed string) bool {
	return CompareVersions(remote, installed) > 0
}

// GetInstalledProxyVersion retorna a versão instalada do proxy-server
func GetInstalledProxyVersion() string {
	if data, err := os.ReadFile("/etc/proxy-version"); err == nil {
		v := strings.TrimSpace(string(data))
		if v != "" {
			return CleanVersion(v)
		}
	}
	if data, err := os.ReadFile("/etc/proxyvt-version"); err == nil {
		v := strings.TrimSpace(string(data))
		if v != "" {
			return CleanVersion(v)
		}
	}
	if out, err := exec.Command("/usr/local/bin/proxy-server", "--version").Output(); err == nil {
		fields := strings.Fields(string(out))
		if len(fields) > 0 {
			return CleanVersion(fields[len(fields)-1])
		}
	}
	return "desconhecida"
}

// GetInstalledUDPGWVersion retorna a versão instalada do udpgw
func GetInstalledUDPGWVersion() string {
	if data, err := os.ReadFile("/etc/udpgw-version"); err == nil {
		v := strings.TrimSpace(string(data))
		if v != "" {
			return CleanVersion(v)
		}
	}
	return "desconhecida"
}

// GetInstalledMenuVersion retorna a versão atual do menu CLI
func GetInstalledMenuVersion() string {
	return CurrentMenuVersion
}

// FetchRemoteProxyVersion busca a última tag estável de release do proxy
func FetchRemoteProxyVersion() (string, error) {
	return fetchLatestGitHubRelease(ProxyRepo)
}

// FetchRemoteUDPGWVersion busca a última tag de release do UDPGW
func FetchRemoteUDPGWVersion() (string, error) {
	return fetchLatestGitHubRelease(UDPGWRepo)
}

// FetchRemoteMenuVersion busca a versão do menu no GitHub
func FetchRemoteMenuVersion() (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()

	// Tier 1: Download direto de menu-version.txt da release menu-latest (sem limites de rate limit da API)
	txtURL := fmt.Sprintf("https://github.com/%s/releases/download/menu-latest/menu-version.txt", ProxyRepo)
	txtReq, err := http.NewRequestWithContext(ctx, "GET", txtURL, nil)
	if err == nil {
		txtReq.Header.Set("User-Agent", "VeltrixProxy-VT/"+CurrentMenuVersion)
		resp, err := httpClient.Do(txtReq)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 64))
			ver := CleanVersion(string(body))
			if ver != "" {
				return ver, nil
			}
		}
	}

	// Tier 2: Release tag API (extrai do título da release ex: 'VT CLI Manager v3.0.4')
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/releases/tags/menu-latest", ProxyRepo)
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err == nil {
		req.Header.Set("User-Agent", "VeltrixProxy-VT/"+CurrentMenuVersion)
		req.Header.Set("Accept", "application/vnd.github+json")
		resp, err := httpClient.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			var data struct {
				Name        string `json:"name"`
				PublishedAt string `json:"published_at"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&data); err == nil {
				re := regexp.MustCompile(`v?([0-9]+\.[0-9]+\.[0-9]+)`)
				if m := re.FindStringSubmatch(data.Name); len(m) > 1 {
					return CleanVersion(m[1]), nil
				}
			}
		}
	}

	// Tier 3: Fallback direto via raw.githubusercontent.com (sem rate limit de API)
	rawURL := fmt.Sprintf("https://raw.githubusercontent.com/%s/main/internal/system/updater.go", ProxyRepo)
	rawReq, err := http.NewRequestWithContext(ctx, "GET", rawURL, nil)
	if err == nil {
		rawReq.Header.Set("User-Agent", "VeltrixProxy-VT/"+CurrentMenuVersion)
		resp, err := httpClient.Do(rawReq)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 8192))
			re := regexp.MustCompile(`CurrentMenuVersion\s*=\s*"([^"]+)"`)
			if m := re.FindStringSubmatch(string(body)); len(m) > 1 {
				return CleanVersion(m[1]), nil
			}
		}
	}

	return CurrentMenuVersion, nil
}

// fetchLatestGitHubRelease realiza busca com 3 camadas de fallback (API, 302 Redirect e Atom)
func fetchLatestGitHubRelease(repo string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()

	// Tier 1: API oficial do GitHub
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", repo)
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err == nil {
		req.Header.Set("User-Agent", "VeltrixProxy-VT/"+CurrentMenuVersion)
		req.Header.Set("Accept", "application/vnd.github+json")
		resp, err := httpClient.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			var data struct {
				TagName string `json:"tag_name"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && data.TagName != "" {
				return CleanVersion(data.TagName), nil
			}
		}
	}

	// Tier 2: Redirecionamento 302 de releases/latest
	noRedirectClient := &http.Client{
		Timeout: 4 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	webURL := fmt.Sprintf("https://github.com/%s/releases/latest", repo)
	webReq, err := http.NewRequestWithContext(ctx, "HEAD", webURL, nil)
	if err == nil {
		webReq.Header.Set("User-Agent", "Mozilla/5.0")
		if webResp, err := noRedirectClient.Do(webReq); err == nil {
			defer webResp.Body.Close()
			loc := webResp.Header.Get("Location")
			if loc != "" {
				parts := strings.Split(loc, "/tag/")
				if len(parts) == 2 {
					return CleanVersion(parts[1]), nil
				}
			}
		}
	}

	// Tier 3: Feed Atom
	atomURL := fmt.Sprintf("https://github.com/%s/releases.atom", repo)
	atomReq, err := http.NewRequestWithContext(ctx, "GET", atomURL, nil)
	if err == nil {
		atomReq.Header.Set("User-Agent", "Mozilla/5.0")
		if atomResp, err := httpClient.Do(atomReq); err == nil && atomResp.StatusCode == http.StatusOK {
			defer atomResp.Body.Close()
			body, _ := io.ReadAll(atomResp.Body)
			re := regexp.MustCompile(`/releases/tag/v?([0-9.]+)`)
			matches := re.FindStringSubmatch(string(body))
			if len(matches) > 1 {
				return CleanVersion(matches[1]), nil
			}
		}
	}

	return "", fmt.Errorf("não foi possível obter release de %s", repo)
}

// loadCachedResult carrega o resultado salvo em disco se ainda for válido
func loadCachedResult() *UpdateCheckResult {
	data, err := os.ReadFile(UpdateCacheFile)
	if err != nil {
		return nil
	}
	var res UpdateCheckResult
	if err := json.Unmarshal(data, &res); err != nil {
		return nil
	}
	if time.Since(res.LastChecked) < UpdateCacheTTL {
		return &res
	}
	return nil
}

// saveCachedResult salva o resultado da verificação em disco
func saveCachedResult(res *UpdateCheckResult) {
	_ = os.MkdirAll(filepath.Dir(UpdateCacheFile), 0755)
	if data, err := json.MarshalIndent(res, "", "  "); err == nil {
		_ = os.WriteFile(UpdateCacheFile, data, 0644)
	}
}

// CheckUpdates verifica atualizações para todos os componentes
func CheckUpdates(force bool) *UpdateCheckResult {
	updateMu.Lock()
	defer updateMu.Unlock()

	if !force {
		if cachedResult != nil && time.Since(cachedResult.LastChecked) < UpdateCacheTTL {
			return cachedResult
		}
		if disk := loadCachedResult(); disk != nil {
			cachedResult = disk
			return cachedResult
		}
	}

	installedProxy := GetInstalledProxyVersion()
	installedUDPGW := GetInstalledUDPGWVersion()
	installedMenu := GetInstalledMenuVersion()

	remoteProxy, _ := FetchRemoteProxyVersion()
	remoteUDPGW, _ := FetchRemoteUDPGWVersion()
	remoteMenu, _ := FetchRemoteMenuVersion()

	proxyUpdate := false
	if remoteProxy != "" && IsNewerVersion(remoteProxy, installedProxy) {
		proxyUpdate = true
	}

	udpgwUpdate := false
	if remoteUDPGW != "" && IsNewerVersion(remoteUDPGW, installedUDPGW) {
		udpgwUpdate = true
	}

	menuUpdate := false
	if remoteMenu != "" && IsNewerVersion(remoteMenu, installedMenu) {
		menuUpdate = true
	}

	res := &UpdateCheckResult{
		Proxy: ComponentStatus{
			Name:             "Proxy Server",
			InstalledVersion: installedProxy,
			RemoteVersion:    remoteProxy,
			HasUpdate:        proxyUpdate,
		},
		UDPGW: ComponentStatus{
			Name:             "UDP Gateway",
			InstalledVersion: installedUDPGW,
			RemoteVersion:    remoteUDPGW,
			HasUpdate:        udpgwUpdate,
		},
		Menu: ComponentStatus{
			Name:             "Menu CLI (vt)",
			InstalledVersion: installedMenu,
			RemoteVersion:    remoteMenu,
			HasUpdate:        menuUpdate,
		},
		HasAnyUpdate: proxyUpdate || udpgwUpdate || menuUpdate,
		LastChecked:  time.Now(),
	}

	saveCachedResult(res)
	cachedResult = res
	return res
}

// CheckInBackground dispara a checagem em segundo plano se o cache estiver expirado
func CheckInBackground() {
	updateMu.RLock()
	hasCache := (cachedResult != nil && time.Since(cachedResult.LastChecked) < UpdateCacheTTL)
	updateMu.RUnlock()

	if hasCache {
		return
	}
	if disk := loadCachedResult(); disk != nil {
		updateMu.Lock()
		cachedResult = disk
		updateMu.Unlock()
		return
	}

	go func() {
		_ = CheckUpdates(false)
	}()
}

// HasPendingUpdates retorna true se houver alguma atualização pendente
func HasPendingUpdates() bool {
	updateMu.RLock()
	if cachedResult != nil {
		res := cachedResult.HasAnyUpdate
		updateMu.RUnlock()
		return res
	}
	updateMu.RUnlock()

	if disk := loadCachedResult(); disk != nil {
		updateMu.Lock()
		cachedResult = disk
		updateMu.Unlock()
		return disk.HasAnyUpdate
	}

	return false
}

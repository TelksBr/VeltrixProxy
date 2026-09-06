package config

import (
	"os"
	"path/filepath"
	"strings"
)

var tokenPaths = []string{
	"/etc/vtproxy/proxy.token",
	"/etc/proxy/token",
}

func init() {
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		tokenPaths = append(tokenPaths, filepath.Join(home, ".proxy_token"))
	}
}

// LoadToken procura o token nos caminhos padrão conhecidos
func LoadToken() string {
	if envToken := os.Getenv("PROXY_TOKEN"); envToken != "" {
		return strings.TrimSpace(envToken)
	}

	for _, p := range tokenPaths {
		if data, err := os.ReadFile(p); err == nil {
			t := strings.TrimSpace(string(data))
			if t != "" {
				return t
			}
		}
	}
	return ""
}

// SaveToken salva o token nos arquivos de persistência padrão
func SaveToken(token string) error {
	token = strings.TrimSpace(token)
	primaryPath := "/etc/vtproxy/proxy.token"
	dir := filepath.Dir(primaryPath)
	_ = os.MkdirAll(dir, 0755)

	if err := os.WriteFile(primaryPath, []byte(token+"\n"), 0644); err != nil {
		// Fallback para home dir
		if home, errH := os.UserHomeDir(); errH == nil && home != "" {
			hPath := filepath.Join(home, ".proxy_token")
			return os.WriteFile(hPath, []byte(token+"\n"), 0644)
		}
		return err
	}

	// Sincroniza também no /etc/proxy/token por compatibilidade legado
	_ = os.MkdirAll("/etc/proxy", 0755)
	_ = os.WriteFile("/etc/proxy/token", []byte(token+"\n"), 0644)

	return nil
}

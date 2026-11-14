package proxy

import (
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

var defaultExecutables = []string{
	"/usr/local/bin/proxy-server",
	"/usr/local/bin/proxy",
}

// ResolveExecutable encontra o caminho do binário do proxy
func ResolveExecutable() string {
	if envBin := os.Getenv("PROXY_EXECUTABLE"); envBin != "" {
		if _, err := os.Stat(envBin); err == nil {
			return envBin
		}
	}
	for _, p := range defaultExecutables {
		if fi, err := os.Stat(p); err == nil && fi.Mode()&0111 != 0 {
			return p
		}
	}
	return defaultExecutables[0]
}

// GetOnlineUsersTotal retorna a contagem total de conexões ativas
func GetOnlineUsersTotal() int {
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--onlines-total")
	output, err := cmd.Output()
	if err != nil {
		return 0
	}
	count, _ := strconv.Atoi(strings.TrimSpace(string(output)))
	return count
}

// GetOnlineUsersDetails retorna a lista de conexões formatada para visualização
func GetOnlineUsersDetails() string {
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--onlines")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Nenhum usuário conectado ou proxy offline."
	}
	return strings.TrimSpace(string(output))
}

// KillUser desconecta imediatamente todas as sessões de um usuário específico
func KillUser(user string) error {
	user = strings.TrimSpace(user)
	if user == "" {
		return fmt.Errorf("usuário inválido")
	}
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--kill-user", user)
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Fallback para pkill do sistema operacional
		_ = exec.Command("pkill", "-u", user).Run()
		return fmt.Errorf("proxy kill falhou (%s), tentativa de pkill executada: %w", string(output), err)
	}
	return nil
}

// KillExpired executa a varredura e desconexão de todos os usuários expirados
func KillExpired() error {
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--kill-expired")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("falha ao desconectar expirados: %s (%w)", string(output), err)
	}
	return nil
}

// ValidateToken valida o token junto ao servidor do proxy sem iniciar os túneis
func ValidateToken(token string) bool {
	token = strings.TrimSpace(token)
	if token == "" {
		return false
	}
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--token", token, "--validate")
	return cmd.Run() == nil
}

// ReloadPasswd avisa o proxy em execução para recarregar o /etc/passwd imediatamente
func ReloadPasswd() error {
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--reload-passwd")
	if _, err := cmd.CombinedOutput(); err == nil {
		return nil
	}
	// Fallback para socket unix direto se o binário legado não tiver a flag
	conn, dialErr := net.DialTimeout("unix", "/tmp/proxyvt-tracker.sock", 1*time.Second)
	if dialErr == nil {
		defer conn.Close()
		_, _ = io.WriteString(conn, "RELOAD_PASSWD\n")
		return nil
	}
	return nil // ignora erro se proxy não estiver em execução
}

// GetUserSessionCount retorna o número de conexões ativas de um usuário
func GetUserSessionCount(user string) int {
	user = strings.TrimSpace(user)
	if user == "" {
		return 0
	}
	bin := ResolveExecutable()
	cmd := exec.Command(bin, "--onlines-user", user)
	output, err := cmd.Output()
	if err != nil {
		return 0
	}
	count, _ := strconv.Atoi(strings.TrimSpace(string(output)))
	return count
}

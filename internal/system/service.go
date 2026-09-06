package system

import (
	"fmt"
	"os/exec"
	"strings"
)

const (
	ProxyServiceName = "vtproxy"
	UDPGWServiceName = "udpgw"
)

// IsServiceActive verifica se a unit systemd está ativa
func IsServiceActive(serviceName string) bool {
	cmd := exec.Command("systemctl", "is-active", "--quiet", serviceName)
	return cmd.Run() == nil
}

// StartService inicia o serviço systemd
func StartService(serviceName string) error {
	cmd := exec.Command("systemctl", "start", serviceName)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("falha ao iniciar %s: %s (%w)", serviceName, strings.TrimSpace(string(output)), err)
	}
	return nil
}

// StopService para o serviço systemd
func StopService(serviceName string) error {
	cmd := exec.Command("systemctl", "stop", serviceName)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("falha ao parar %s: %s (%w)", serviceName, strings.TrimSpace(string(output)), err)
	}
	return nil
}

// RestartService reinicia o serviço systemd
func RestartService(serviceName string) error {
	cmd := exec.Command("systemctl", "restart", serviceName)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("falha ao reiniciar %s: %s (%w)", serviceName, strings.TrimSpace(string(output)), err)
	}
	return nil
}

// EnableService habilita a inicialização automática no boot
func EnableService(serviceName string) error {
	cmd := exec.Command("systemctl", "enable", serviceName)
	_ = cmd.Run()
	return nil
}

// DaemonReload executa systemctl daemon-reload
func DaemonReload() error {
	cmd := exec.Command("systemctl", "daemon-reload")
	return cmd.Run()
}

// GetServiceLogs retorna as últimas N linhas do journalctl do serviço
func GetServiceLogs(serviceName string, lines int) (string, error) {
	if lines <= 0 {
		lines = 50
	}
	cmd := exec.Command("journalctl", "-u", serviceName, "-n", fmt.Sprintf("%d", lines), "--no-pager")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("falha ao ler logs de %s: %w", serviceName, err)
	}
	return string(output), nil
}

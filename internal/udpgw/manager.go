package udpgw

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/system"
)

const (
	ConfigFile  = "/etc/udpgw/config.conf"
	DefaultPort = 7400
)

// GetConfiguredPort lê a porta configurada no /etc/udpgw/config.conf
func GetConfiguredPort() int {
	f, err := os.Open(ConfigFile)
	if err != nil {
		return DefaultPort
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "PORT=") {
			val := strings.TrimPrefix(line, "PORT=")
			if port, err := strconv.Atoi(strings.Trim(val, "\"")); err == nil && port > 0 {
				return port
			}
		}
	}
	return DefaultPort
}

// SetPort salva a porta no arquivo de configuração do UDPGW
func SetPort(port int) error {
	if port <= 0 || port > 65535 {
		return fmt.Errorf("porta inválida: %d", port)
	}

	_ = os.MkdirAll(filepath.Dir(ConfigFile), 0755)
	content := fmt.Sprintf("# UDPGW Configuration\nPORT=%d\nLISTEN=0.0.0.0:%d\n", port, port)
	if err := os.WriteFile(ConfigFile, []byte(content), 0644); err != nil {
		return err
	}

	// Atualiza o service systemd se existir
	if system.IsServiceActive(system.UDPGWServiceName) {
		return system.RestartService(system.UDPGWServiceName)
	}
	return nil
}

// IsActive verifica se o UDPGW está rodando
func IsActive() bool {
	return system.IsServiceActive(system.UDPGWServiceName)
}

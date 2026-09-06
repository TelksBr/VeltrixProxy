package system

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
)

// StreamServiceJournalLogs acompanha os logs do serviço systemd em tempo real (journalctl -f)
func StreamServiceJournalLogs(serviceName string, lines int) error {
	if lines <= 0 {
		lines = 50
	}

	if _, err := exec.LookPath("journalctl"); err != nil {
		return fmt.Errorf("comando 'journalctl' não encontrado neste sistema")
	}

	cmd := exec.Command("journalctl", "-u", serviceName, "-n", fmt.Sprintf("%d", lines), "-f", "--no-pager")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Intercepta SIGINT (Ctrl+C) para não matar o processo do menu interativo
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(sigChan)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("falha ao iniciar journalctl: %w", err)
	}

	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case <-sigChan:
		if cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGINT)
		}
		<-done
		return nil
	case err := <-done:
		return err
	}
}

// StreamFileTail acompanha um arquivo de log em tempo real (tail -f)
func StreamFileTail(filePath string, lines int) error {
	if lines <= 0 {
		lines = 50
	}

	if _, err := os.Stat(filePath); err != nil {
		return fmt.Errorf("arquivo de log não encontrado: %s", filePath)
	}

	if _, err := exec.LookPath("tail"); err != nil {
		return fmt.Errorf("comando 'tail' não encontrado neste sistema")
	}

	cmd := exec.Command("tail", "-n", fmt.Sprintf("%d", lines), "-f", filePath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(sigChan)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("falha ao iniciar tail: %w", err)
	}

	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case <-sigChan:
		if cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGINT)
		}
		<-done
		return nil
	case err := <-done:
		return err
	}
}

// ReadFileTail lê as últimas N linhas de um arquivo de log
func ReadFileTail(filePath string, lines int) (string, error) {
	if lines <= 0 {
		lines = 60
	}

	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	// Tentativa via utilitário do sistema se disponível
	if _, err := exec.LookPath("tail"); err == nil {
		cmd := exec.Command("tail", "-n", fmt.Sprintf("%d", lines), filePath)
		out, err := cmd.CombinedOutput()
		if err == nil {
			return string(out), nil
		}
	}

	// Fallback em Go puro (compatível com qualquer OS)
	scanner := bufio.NewScanner(file)
	var buffer []string
	for scanner.Scan() {
		buffer = append(buffer, scanner.Text())
		if len(buffer) > lines*2 {
			buffer = buffer[len(buffer)-lines:]
		}
	}
	if err := scanner.Err(); err != nil && len(buffer) == 0 {
		return "", err
	}

	if len(buffer) > lines {
		buffer = buffer[len(buffer)-lines:]
	}

	return strings.Join(buffer, "\n"), nil
}

// ClearLogFile trunca o arquivo de log para 0 bytes
func ClearLogFile(filePath string) error {
	f, err := os.OpenFile(filePath, os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	return f.Close()
}

// GetLogFileInfo retorna informações sobre a existência e tamanho do arquivo de log
func GetLogFileInfo(filePath string) (exists bool, sizeBytes int64, err error) {
	fi, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, 0, nil
		}
		return false, 0, err
	}
	return true, fi.Size(), nil
}

// FormatBytes formata bytes em representação humana legível (ex: 12.5 KB)
func FormatBytes(b int64) string {
	const unit = 1024
	if b < unit {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := int64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(b)/float64(div), "KMGTPE"[exp])
}

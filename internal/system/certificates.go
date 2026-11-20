package system

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

type CertificateStatus struct {
	Domain      string    `json:"domain"`
	Email       string    `json:"email"`
	Staging     bool      `json:"staging"`
	NotBefore   time.Time `json:"not_before"`
	NotAfter    time.Time `json:"not_after"`
	Fingerprint string    `json:"fingerprint"`
	LastError   string    `json:"last_error"`
	NextAttempt time.Time `json:"next_attempt"`
}

type CertificateResult struct {
	Certificate CertificateStatus `json:"certificate"`
	Changed     bool              `json:"changed"`
	Domain      string            `json:"domain"`
	HTTP01Ready bool              `json:"http01_ready"`
	Error       string            `json:"error"`
}

func CertificateCommand(ctx context.Context, configPath, action, domain, email string, staging, acceptTerms bool) (CertificateResult, error) {
	args := []string{"--config", configPath, "--ssl-action", action}
	if domain != "" {
		args = append(args, "--ssl-domain", domain)
	}
	if email != "" {
		args = append(args, "--ssl-email", email)
	}
	if staging {
		args = append(args, "--ssl-staging")
	}
	if acceptTerms {
		args = append(args, "--ssl-accept-terms")
	}
	cmd := exec.CommandContext(ctx, "/usr/local/bin/proxy-server", args...)
	var out, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &stderr
	err := cmd.Run()
	return decodeCertificateResult(out.Bytes(), stderr.String(), action, err)
}

func decodeCertificateResult(data []byte, stderr, action string, commandErr error) (CertificateResult, error) {
	var result CertificateResult
	lines := bytes.Split(bytes.TrimSpace(data), []byte{'\n'})
	decoded := false
	for i := len(lines) - 1; i >= 0; i-- {
		if json.Unmarshal(lines[i], &result) == nil {
			decoded = true
			break
		}
	}
	if !decoded {
		return result, fmt.Errorf("resposta SSL inválida; atualize o proxy: %s (%v)", strings.TrimSpace(stderr), commandErr)
	}
	if result.Error != "" {
		return result, fmt.Errorf("%s", result.Error)
	}
	if commandErr != nil {
		return result, fmt.Errorf("comando SSL falhou: %w", commandErr)
	}
	if action == "status" {
		if err := json.Unmarshal(lines[len(lines)-1], &result.Certificate); err != nil {
			return result, err
		}
	}
	if (action == "issue" || action == "renew" || action == "status") && result.Certificate.Domain == "" {
		return result, fmt.Errorf("proxy não retornou um certificado; atualize o binário")
	}
	if action == "check" && !result.HTTP01Ready {
		return result, fmt.Errorf("porta 80 não confirmou o desafio HTTP-01")
	}
	return result, nil
}

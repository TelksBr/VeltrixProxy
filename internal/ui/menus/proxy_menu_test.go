package menus

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGetLatestProxyBannerSingle(t *testing.T) {
	tmpDir := t.TempDir()
	logFile := filepath.Join(tmpDir, "proxy.log")

	sampleBanner := `
       __   __       _   _         v2.3.27
 \ \ / /__| |_ _ __(_)_| |_
  \ V / -_)  _| '_ \ \ \ /   RAM: 14.92 MB
   \_/\___|\__|_|  |_/_/_\_\  CPU: 0.58%
                              PID: 29212
                              CON: 00

Criador: Telks (@telks13)
Tempo on: 00:02:13
Network: ↓ 0 B   ↑ 0 B
Rodando em: 443 (SSL), 80 (HTTP)`

	if err := os.WriteFile(logFile, []byte(sampleBanner), 0644); err != nil {
		t.Fatalf("Erro ao criar arquivo temporario: %v", err)
	}

	result := getLatestProxyBanner(logFile)
	if !strings.Contains(result, "v2.3.27") {
		t.Errorf("Esperava v2.3.27 no resultado, obteve: %q", result)
	}
	if !strings.Contains(result, "Criador: Telks (@telks13)") {
		t.Errorf("Esperava Criador no resultado, obteve: %q", result)
	}
}

func TestGetLatestProxyBannerMultipleAppended(t *testing.T) {
	tmpDir := t.TempDir()
	logFile := filepath.Join(tmpDir, "proxy.log")

	var sb strings.Builder
	// Simula 5 iterações antigas
	for i := 1; i <= 5; i++ {
		sb.WriteString("       __   __       _   _         v2.3.27\n")
		sb.WriteString(" \\ \\ / /__| |_ _ __(_)_| |_\n")
		sb.WriteString("  \\ V / -_)  _| '_ \\ \\ \\ /   RAM: 10.00 MB\n")
		sb.WriteString("   \\_/\\___|\\__|_|  |_/_/_\\_\\  CPU: 0.10%\n")
		sb.WriteString("                              PID: 1000\n")
		sb.WriteString("                              CON: 0\n\n")
		sb.WriteString("Criador: Telks (@telks13)\n")
		sb.WriteString("Tempo on: 00:00:10\n")
		sb.WriteString("Network: ↓ 0 B   ↑ 0 B\n")
		sb.WriteString("Rodando em: 80 (HTTP)\n\n")
	}

	// Banner mais recente (deve ser o retornado)
	sb.WriteString("       __   __       _   _         v2.3.27\n")
	sb.WriteString(" \\ \\ / /__| |_ _ __(_)_| |_\n")
	sb.WriteString("  \\ V / -_)  _| '_ \\ \\ \\ /   RAM: 99.99 MB\n")
	sb.WriteString("   \\_/\\___|\\__|_|  |_/_/_\\_\\  CPU: 9.99%\n")
	sb.WriteString("                              PID: 9999\n")
	sb.WriteString("                              CON: 42\n\n")
	sb.WriteString("Criador: Telks (@telks13)\n")
	sb.WriteString("Tempo on: 01:23:45\n")
	sb.WriteString("Network: ↓ 50 MB   ↑ 20 MB\n")
	sb.WriteString("Rodando em: 443 (SSL), 80 (HTTP)\n")

	if err := os.WriteFile(logFile, []byte(sb.String()), 0644); err != nil {
		t.Fatalf("Erro ao criar arquivo: %v", err)
	}

	result := getLatestProxyBanner(logFile)
	if !strings.Contains(result, "RAM: 99.99 MB") {
		t.Errorf("Esperava o banner mais recente com RAM: 99.99 MB, obteve: %q", result)
	}
	if !strings.Contains(result, "CON: 42") {
		t.Errorf("Esperava CON: 42, obteve: %q", result)
	}
	// O primeiro banner antigo não deve estar presente no recorte final
	if strings.Contains(result, "RAM: 10.00 MB") {
		t.Errorf("Banner antigo ainda está presente no resultado recortado!")
	}
}

func TestGetLatestProxyBannerNonExistent(t *testing.T) {
	result := getLatestProxyBanner("/arquivo/que/nao/existe.log")
	if result != "" {
		t.Errorf("Esperava string vazia para arquivo inexistente, obteve: %q", result)
	}
}

func TestRenderLiveBannerFrameNotDuplicated(t *testing.T) {
	// Redireciona stdout temporariamente para capturar o render do frame
	oldStdout := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w

	renderLiveBannerFrame("/var/log/proxy/proxy.log", false)

	w.Close()
	os.Stdout = oldStdout

	var buf [4096]byte
	n, _ := r.Read(buf[:])
	output := string(buf[:n])

	if strings.Contains(output, "ONLINE ONLINE") {
		t.Errorf("O status do banner contém 'ONLINE ONLINE' duplicado! Output:\n%s", output)
	}
	if strings.Contains(output, "ONLI...") {
		t.Errorf("A linha de status foi truncada com 'ONLI...'! Output:\n%s", output)
	}
}


package menus

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
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

func TestGetLatestProxyBannerBoxFormat(t *testing.T) {
	tmpDir := t.TempDir()
	logFile := filepath.Join(tmpDir, "proxy.log")

	var sb strings.Builder
	// Banners antigos empilhados
	for i := 0; i < 3; i++ {
		sb.WriteString("┌────────────────────────────────────────┐\n")
		sb.WriteString("│ Versão: v2.3.50          Uptime: 00:00:01 │\n")
		sb.WriteString("│ RAM: 10.00 MB              CPU: 1.00%  │\n")
		sb.WriteString("└────────────────────────────────────────┘\n\n")
	}
	// Banner mais recente
	sb.WriteString("┌────────────────────────────────────────┐\n")
	sb.WriteString("│ Versão: v2.3.53          Uptime: 00:00:38 │\n")
	sb.WriteString("│ RAM: 265.61 MB             CPU: 37.02% │\n")
	sb.WriteString("│ PID: 116837                  CON: 217  │\n")
	sb.WriteString("│ Network: ↓ 11.15 MB  ↑ 112.01 MB       │\n")
	sb.WriteString("└────────────────────────────────────────┘\n")

	if err := os.WriteFile(logFile, []byte(sb.String()), 0644); err != nil {
		t.Fatalf("Erro ao criar arquivo: %v", err)
	}

	result := getLatestProxyBanner(logFile)
	if !strings.Contains(result, "v2.3.53") {
		t.Errorf("Esperava banner v2.3.53, obteve: %q", result)
	}
	if !strings.Contains(result, "265.61 MB") {
		t.Errorf("Esperava RAM do banner recente, obteve: %q", result)
	}
	if strings.Contains(result, "v2.3.50") {
		t.Errorf("Banner antigo ainda presente no recorte: %q", result)
	}
	if strings.Count(result, "┌") != 1 {
		t.Errorf("Esperava exatamente 1 topo de caixa, obteve %d em: %q", strings.Count(result, "┌"), result)
	}
}

func TestSanitizeLiveBannerNeverFullWidth(t *testing.T) {
	// Banner com largura tipicamente maior que um painel tiled
	wide := "┌" + strings.Repeat("─", 70) + "┐"
	out := sanitizeLiveBanner(wide+"\n│ x │\n", 49) // maxCols = term-1
	for _, line := range strings.Split(out, "\n") {
		if line == "" {
			continue
		}
		if theme.VisibleLen(line) > 49 {
			t.Errorf("linha com %d cols > max 49 (causa wrap): %q", theme.VisibleLen(line), line)
		}
	}
}

func TestSanitizeLiveBannerStripsCursorControls(t *testing.T) {
	in := "\033[H\033[2J┌──┐\n│ ok │\n└──┘"
	out := sanitizeLiveBanner(in, 80)
	if strings.Contains(out, "\033[H") || strings.Contains(out, "\033[2J") {
		t.Errorf("controles de cursor não foram removidos: %q", out)
	}
	if !strings.Contains(out, "┌──┐") {
		t.Errorf("conteúdo do banner foi perdido: %q", out)
	}
}

func TestGetLatestProxyBannerCutsAtBoxEnd(t *testing.T) {
	tmpDir := t.TempDir()
	logFile := filepath.Join(tmpDir, "proxy.log")
	content := "┌────┐\n│ A  │\n└────┘\njunk\n┌────┐\n│ B  │\n└────┘\ntrailing\n"
	if err := os.WriteFile(logFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	result := getLatestProxyBanner(logFile)
	if !strings.Contains(result, "│ B  │") {
		t.Fatalf("esperava box B, obteve: %q", result)
	}
	if strings.Contains(result, "trailing") || strings.Contains(result, "│ A  │") {
		t.Fatalf("recorte extravasou: %q", result)
	}
}


package components

import (
	"bytes"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

func captureOutput(f func()) string {
	old := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w

	f()

	w.Close()
	os.Stdout = old

	var buf bytes.Buffer
	io.Copy(&buf, r)
	return buf.String()
}

func TestBoxWidthInvariance(t *testing.T) {
	testWidths := []int{40, 50, 56, 62, 70}

	for _, w := range testWidths {
		output := captureOutput(func() {
			PrintBoxHeader("TEST TITLE", theme.Cyan, w)
			PrintBoxLine("Normal short line", w)
			PrintBoxLine("A very long line that exceeds the box width and should be safely truncated with an ellipsis without breaking borders", w)
			PrintBoxLine(theme.Green+"Colored line with ANSI codes"+theme.Reset, w)
			PrintBoxDivider(w)
			PrintBoxFooter(w)
		})

		lines := strings.Split(strings.TrimSuffix(output, "\n"), "\n")
		for idx, line := range lines {
			visible := theme.VisibleLen(line)
			if visible != w {
				t.Errorf("Width %d, line %d (%q) has visible length %d, want %d", w, idx, theme.StripANSI(line), visible, w)
			}
		}
	}
}

func TestDashboardHeaderWidth(t *testing.T) {
	// Testa tanto o layout de 2 colunas (>= 54) quanto o compacto (< 54)
	testWidths := []int{42, 50, 54, 62, 68}

	for _, w := range testWidths {
		output := captureOutput(func() {
			PrintDashboardHeader(w)
		})

		lines := strings.Split(strings.TrimSuffix(output, "\n"), "\n")
		for idx, line := range lines {
			visible := theme.VisibleLen(line)
			if visible != w {
				t.Errorf("Dashboard width %d, line %d (%q) has visible length %d, want %d", w, idx, theme.StripANSI(line), visible, w)
			}
		}
	}
}

func TestGetBoxWidthResponsiveness(t *testing.T) {
	// Simular COLUMNS estreito (mobile / split)
	os.Setenv("COLUMNS", "45")
	defer os.Unsetenv("COLUMNS")

	w := GetBoxWidth()
	if w > 45 {
		t.Errorf("GetBoxWidth com COLUMNS=45 retornou %d (deveria ser <= 45)", w)
	}

	// Simular COLUMNS normal
	os.Setenv("COLUMNS", "80")
	w80 := GetBoxWidth()
	if w80 <= 0 || w80 > 80 {
		t.Errorf("GetBoxWidth com COLUMNS=80 retornou %d", w80)
	}
}

func TestPrintMenuCredits(t *testing.T) {
	testWidths := []int{40, 45, 50, 56, 62, 70}

	for _, w := range testWidths {
		output := captureOutput(func() {
			PrintMenuCredits(w)
		})

		lines := strings.Split(strings.TrimSuffix(output, "\n"), "\n")
		for idx, line := range lines {
			visible := theme.VisibleLen(line)
			if visible != w {
				t.Errorf("Credits width %d, line %d (%q) has visible length %d, want %d", w, idx, theme.StripANSI(line), visible, w)
			}
		}
	}
}

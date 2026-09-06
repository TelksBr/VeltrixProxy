package system

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestFormatBytes(t *testing.T) {
	tests := []struct {
		input    int64
		expected string
	}{
		{0, "0 B"},
		{500, "500 B"},
		{1024, "1.0 KB"},
		{2048, "2.0 KB"},
		{1048576, "1.0 MB"},
	}

	for _, tc := range tests {
		res := FormatBytes(tc.input)
		if res != tc.expected {
			t.Errorf("FormatBytes(%d) = %q; esperado %q", tc.input, res, tc.expected)
		}
	}
}

func TestReadFileTailAndClear(t *testing.T) {
	tmpDir := t.TempDir()
	logPath := filepath.Join(tmpDir, "test.log")

	// Arquivo inexistente
	exists, size, err := GetLogFileInfo(logPath)
	if err != nil || exists || size != 0 {
		t.Fatalf("Esperado arquivo não existente, obteve exists=%v, size=%d, err=%v", exists, size, err)
	}

	_, err = ReadFileTail(logPath, 10)
	if err == nil {
		t.Fatalf("Esperado erro ao ler arquivo inexistente")
	}

	// Cria arquivo com 5 linhas
	content := "linha 1\nlinha 2\nlinha 3\nlinha 4\nlinha 5\n"
	if err := os.WriteFile(logPath, []byte(content), 0644); err != nil {
		t.Fatalf("Falha ao criar arquivo de log: %v", err)
	}

	exists, size, err = GetLogFileInfo(logPath)
	if err != nil || !exists || size != int64(len(content)) {
		t.Fatalf("Esperado exists=true, size=%d; obteve exists=%v, size=%d, err=%v", len(content), exists, size, err)
	}

	// Lê as últimas 3 linhas
	tail3, err := ReadFileTail(logPath, 3)
	if err != nil {
		t.Fatalf("Erro ao ler tail: %v", err)
	}
	lines := strings.Split(strings.TrimSpace(tail3), "\n")
	if len(lines) != 3 {
		t.Fatalf("Esperado 3 linhas, obteve %d (%q)", len(lines), tail3)
	}
	if lines[2] != "linha 5" {
		t.Fatalf("Esperado última linha 'linha 5', obteve %q", lines[2])
	}

	// Limpar arquivo
	if err := ClearLogFile(logPath); err != nil {
		t.Fatalf("Erro ao limpar arquivo: %v", err)
	}

	exists, size, err = GetLogFileInfo(logPath)
	if err != nil || !exists || size != 0 {
		t.Fatalf("Esperado size=0 após ClearLogFile; obteve %d", size)
	}
}

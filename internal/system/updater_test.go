package system

import (
	"testing"
)

func TestCleanVersion(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"v2.3.26", "2.3.26"},
		{"go-v3.0.0", "3.0.0"},
		{"  v1.0.0  ", "1.0.0"},
		{"3.0.1", "3.0.1"},
	}

	for _, tt := range tests {
		if got := CleanVersion(tt.input); got != tt.want {
			t.Errorf("CleanVersion(%q) = %q; want %q", tt.input, got, tt.want)
		}
	}
}

func TestCompareVersions(t *testing.T) {
	tests := []struct {
		v1   string
		v2   string
		want int
	}{
		{"2.3.26", "2.3.25", 1},
		{"2.3.25", "2.3.26", -1},
		{"v2.3.26", "2.3.26", 0},
		{"3.0.0", "go-v3.0.0", 0},
		{"2.4", "2.3.9", 1},
		{"1.0.0", "1.0.0", 0},
		{"2.0.0", "1.9.9", 1},
		{"1.9.9", "2.0.0", -1},
	}

	for _, tt := range tests {
		got := CompareVersions(tt.v1, tt.v2)
		if got != tt.want {
			t.Errorf("CompareVersions(%q, %q) = %d; want %d", tt.v1, tt.v2, got, tt.want)
		}
	}
}

func TestIsNewerVersion(t *testing.T) {
	if !IsNewerVersion("2.3.26", "2.3.25") {
		t.Errorf("esperava que 2.3.26 fosse mais recente que 2.3.25")
	}
	if IsNewerVersion("2.3.25", "2.3.26") {
		t.Errorf("não esperava que 2.3.25 fosse mais recente que 2.3.26")
	}
	if IsNewerVersion("2.3.26", "2.3.26") {
		t.Errorf("versões iguais não devem ser consideradas mais recentes")
	}
}

package theme

import (
	"testing"
)

func TestVisibleLen(t *testing.T) {
	tests := []struct {
		input string
		want  int
	}{
		{"Hello", 5},
		{Cyan + "Hello" + Reset, 5},
		{Bold + Red + "12345" + Reset, 5},
		{"Olá Mundo", 9},
		{Green + "● ONLINE" + Reset, 8},
	}

	for _, tt := range tests {
		if got := VisibleLen(tt.input); got != tt.want {
			t.Errorf("VisibleLen(%q) = %d; want %d", tt.input, got, tt.want)
		}
	}
}

func TestTruncateANSI(t *testing.T) {
	// Truncar string simples
	if got := TruncateANSI("123456789", 5); VisibleLen(got) != 5 {
		t.Errorf("TruncateANSI(123456789, 5) visibleLen = %d; want 5", VisibleLen(got))
	}

	// Truncar com cor ANSI
	colored := Cyan + "SuperLongOptionTitle" + Reset
	truncated := TruncateANSI(colored, 10)
	if VisibleLen(truncated) != 10 {
		t.Errorf("TruncateANSI(colored, 10) visibleLen = %d; want 10", VisibleLen(truncated))
	}

	// String menor que maxLen não deve mudar
	short := Green + "OK" + Reset
	if got := TruncateANSI(short, 10); got != short {
		t.Errorf("TruncateANSI(short, 10) alterou string desnecessariamente")
	}
}

func TestPadRightANSI(t *testing.T) {
	input := Cyan + "Item" + Reset
	padded := PadRightANSI(input, 10)
	if VisibleLen(padded) != 10 {
		t.Errorf("PadRightANSI visibleLen = %d; want 10", VisibleLen(padded))
	}

	// Se for maior que target, deve truncar
	long := "1234567890ABC"
	truncatedPadded := PadRightANSI(long, 5)
	if VisibleLen(truncatedPadded) != 5 {
		t.Errorf("PadRightANSI em string longa visibleLen = %d; want 5", VisibleLen(truncatedPadded))
	}
}

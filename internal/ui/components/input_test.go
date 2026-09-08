package components

import (
	"strings"
	"testing"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
)

func TestParseConfirmAnswer(t *testing.T) {
	cases := []struct {
		input      string
		defaultYes bool
		want       bool
	}{
		{"", false, false},
		{"", true, true},
		{"s", false, true},
		{"sim", false, true},
		{"si", false, true},
		{"sí", false, true},
		{"y", false, true},
		{"yes", false, true},
		{"n", true, false},
		{"nao", true, false},
		{"não", true, false},
		{"no", true, false},
		{"xyz", true, false},
	}

	for _, tc := range cases {
		got := parseConfirmAnswer(tc.input, tc.defaultYes)
		if got != tc.want {
			t.Errorf("parseConfirmAnswer(%q, %v) = %v, want %v", tc.input, tc.defaultYes, got, tc.want)
		}
	}
}

func TestConfirmHintFollowsLanguage(t *testing.T) {
	t.Cleanup(func() { _ = i18n.SetLanguage(i18n.LangPT) })

	_ = i18n.SetLanguage(i18n.LangEN)
	if confirmHint(false) != "y/N" {
		t.Fatalf("EN no-default hint = %q", confirmHint(false))
	}
	if confirmHint(true) != "Y/n" {
		t.Fatalf("EN yes-default hint = %q", confirmHint(true))
	}

	_ = i18n.SetLanguage(i18n.LangES)
	if confirmHint(false) != "s/N" {
		t.Fatalf("ES no-default hint = %q", confirmHint(false))
	}

	_ = i18n.SetLanguage(i18n.LangPT)
	if confirmHint(false) != "s/N" {
		t.Fatalf("PT no-default hint = %q", confirmHint(false))
	}
}

func TestFormatBool(t *testing.T) {
	if !strings.Contains(FormatBool(true), "true") {
		t.Fatalf("FormatBool(true) deve conter 'true': %q", FormatBool(true))
	}
	if !strings.Contains(FormatBool(false), "false") {
		t.Fatalf("FormatBool(false) deve conter 'false': %q", FormatBool(false))
	}
}

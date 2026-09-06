package theme

import (
	"regexp"
	"strings"
	"unicode/utf8"
)

// Cores ANSI modernas e vibrantes (TrueColor / 24-bit com fallback ANSI padrão)
const (
	Reset     = "\033[0m"
	Bold      = "\033[1m"
	Dim       = "\033[2m"
	Italic    = "\033[3m"
	Underline = "\033[4m"

	// Cores da Paleta Veltrix (Sleek Modern Dark)
	Cyan    = "\033[38;2;0;220;255m"
	Blue    = "\033[38;2;80;150;255m"
	Green   = "\033[38;2;46;213;115m"
	Red     = "\033[38;2;255;71;87m"
	Yellow  = "\033[38;2;255;211;42m"
	Magenta = "\033[38;2;170;100;255m"
	White   = "\033[38;2;240;240;250m"
	Gray    = "\033[38;2;130;135;150m"
	DarkGray= "\033[38;2;60;65;80m"

	// Badges
	BadgeOnline  = Green + "● ONLINE" + Reset
	BadgeOffline = Red + "○ OFFLINE" + Reset
	BadgeActive  = Green + "[ATIVO]" + Reset
	BadgeInactive= Red + "[INATIVO]" + Reset
)

var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)

// StripANSI remove códigos de escape ANSI de uma string
func StripANSI(str string) string {
	return ansiRegex.ReplaceAllString(str, "")
}

// VisibleLen calcula o comprimento visível de uma string sem os códigos ANSI
func VisibleLen(str string) int {
	clean := StripANSI(str)
	return utf8.RuneCountInString(clean)
}

// TruncateANSI trunca uma string preservando sequências ANSI para caber em maxLen visível
func TruncateANSI(str string, maxLen int) string {
	if maxLen <= 0 {
		return ""
	}
	if VisibleLen(str) <= maxLen {
		return str
	}

	target := maxLen
	if target > 1 {
		target-- // reserva 1 coluna para a reticência '…'
	}

	var buf strings.Builder
	visible := 0
	inEscape := false

	for _, r := range str {
		if r == '\x1b' {
			inEscape = true
			buf.WriteRune(r)
			continue
		}
		if inEscape {
			buf.WriteRune(r)
			if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
				inEscape = false
			}
			continue
		}

		if visible < target {
			buf.WriteRune(r)
			visible++
		} else {
			break
		}
	}

	buf.WriteString("…" + Reset)
	return buf.String()
}

// PadRightANSI preenche a string com espaços à direita até atingir targetLen visível
func PadRightANSI(str string, targetLen int) string {
	vLen := VisibleLen(str)
	if vLen >= targetLen {
		return TruncateANSI(str, targetLen)
	}
	return str + strings.Repeat(" ", targetLen-vLen)
}

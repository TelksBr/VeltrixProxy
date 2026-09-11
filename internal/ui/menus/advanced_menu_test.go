package menus

import (
	"strings"
	"testing"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

func TestLimiterMenuOptionNotDuplicated(t *testing.T) {
	languages := []i18n.Language{i18n.LangPT, i18n.LangES, i18n.LangEN}
	width := components.DefaultBoxWidth

	for _, lang := range languages {
		i18n.SetLanguage(lang)

		limLine := advMenuItem("6", i18n.T("adv_opt_limits"), components.FormatBool(true))

		visible := theme.VisibleLen(limLine)
		contentWidth := width - 4
		if visible > contentWidth {
			t.Errorf("Idioma %s: limLine visível (%d) excede contentWidth (%d): %q", lang, visible, contentWidth, limLine)
		}

		clean := theme.StripANSI(limLine)
		// Verifica se a palavra 'Limiter' não aparece mais de 1 vez na linha
		count := strings.Count(clean, "Limiter")
		if count > 1 {
			t.Errorf("Idioma %s: 'Limiter' aparece %d vezes na opção: %q", lang, count, clean)
		}

		// Testa a formatação da linha da caixa garantindo que não há reticências (...)
		boxLine := components.FormatBoxLine(limLine, width)
		if strings.Contains(boxLine, "...") || strings.Contains(boxLine, "…") {
			t.Errorf("Idioma %s: A linha foi truncada com reticências na caixa: %q", lang, boxLine)
		}
	}
}

func TestDNSTTOptionFormatting(t *testing.T) {
	languages := []i18n.Language{i18n.LangPT, i18n.LangES, i18n.LangEN}
	width := components.DefaultBoxWidth

	for _, lang := range languages {
		i18n.SetLanguage(lang)

		line := advMenuItem("8", i18n.T("adv_opt_dnstt"), components.FormatBool(true))

		visible := theme.VisibleLen(line)
		contentWidth := width - 4
		if visible > contentWidth {
			t.Errorf("Idioma %s: opção DNSTT visível (%d) excede contentWidth (%d): %q", lang, visible, contentWidth, line)
		}

		boxLine := components.FormatBoxLine(line, width)
		if strings.Contains(boxLine, "...") || strings.Contains(boxLine, "…") {
			t.Errorf("Idioma %s: A opção DNSTT foi truncada na caixa: %q", lang, boxLine)
		}
	}
}

func TestZtunOptionFormatting(t *testing.T) {
	languages := []i18n.Language{i18n.LangPT, i18n.LangES, i18n.LangEN}
	width := components.DefaultBoxWidth

	for _, lang := range languages {
		i18n.SetLanguage(lang)

		line := advMenuItem("9", i18n.T("adv_opt_ztun"), components.FormatBool(true))

		visible := theme.VisibleLen(line)
		contentWidth := width - 4
		if visible > contentWidth {
			t.Errorf("Idioma %s: opção Ztun visível (%d) excede contentWidth (%d): %q", lang, visible, contentWidth, line)
		}

		boxLine := components.FormatBoxLine(line, width)
		if strings.Contains(boxLine, "...") || strings.Contains(boxLine, "…") {
			t.Errorf("Idioma %s: A opção Ztun foi truncada na caixa: %q", lang, boxLine)
		}
	}
}


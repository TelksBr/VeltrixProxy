package menus

import (
	"fmt"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowLanguageMenu permite alternar o idioma da interface
func ShowLanguageMenu() {
	components.ClearScreen()
	components.PrintBoxHeader("MUDAR IDIOMA / CHANGE LANGUAGE", theme.Cyan, components.DefaultBoxWidth)

	current := i18n.CurrentLanguage()
	ptBadge, enBadge, esBadge := "", "", ""
	switch current {
	case i18n.LangPT:
		ptBadge = " " + theme.Green + "(atual)" + theme.Reset
	case i18n.LangEN:
		enBadge = " " + theme.Green + "(current)" + theme.Reset
	case i18n.LangES:
		esBadge = " " + theme.Green + "(actual)" + theme.Reset
	}

	components.PrintBoxLine(fmt.Sprintf("%s1 • Português (Brasil)%s%s", theme.White, ptBadge, theme.Reset), components.DefaultBoxWidth)
	components.PrintBoxLine(fmt.Sprintf("%s2 • English%s%s", theme.White, enBadge, theme.Reset), components.DefaultBoxWidth)
	components.PrintBoxLine(fmt.Sprintf("%s3 • Español%s%s", theme.White, esBadge, theme.Reset), components.DefaultBoxWidth)

	components.PrintBoxDivider(components.DefaultBoxWidth)
	components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
	components.PrintBoxFooter(components.DefaultBoxWidth)

	choice := components.ReadOption("Opção [0-3]")
	switch choice {
	case "1":
		_ = i18n.SetLanguage(i18n.LangPT)
		components.PrintSuccess("Idioma alterado para Português.")
	case "2":
		_ = i18n.SetLanguage(i18n.LangEN)
		components.PrintSuccess("Language changed to English.")
	case "3":
		_ = i18n.SetLanguage(i18n.LangES)
		components.PrintSuccess("Idioma cambiado a Español.")
	}
}

package menus

import (
	"strings"
	"testing"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
)

func TestIsValidUninstallConfirmation(t *testing.T) {
	validInputs := []string{
		// Português
		"REMOVER",
		"remover",
		"Remover",
		"  REMOVER  ",

		// Inglês
		"REMOVE",
		"remove",
		"Remove",
		"  REMOVE  ",

		// Espanhol
		"ELIMINAR",
		"eliminar",
		"Eliminar",
		"  ELIMINAR  ",
	}

	for _, input := range validInputs {
		if !IsValidUninstallConfirmation(input) {
			t.Errorf("Esperava que %q fosse uma confirmação válida de desinstalação", input)
		}
	}

	invalidInputs := []string{
		"",
		"   ",
		"0",
		"sim",
		"yes",
		"cancelar",
		"sair",
		"DELETE",
		"APAGAR",
		"REMOV",
		"REMOVERRR",
	}

	for _, input := range invalidInputs {
		if IsValidUninstallConfirmation(input) {
			t.Errorf("Esperava que %q NÃO fosse aceito como confirmação de desinstalação", input)
		}
	}
}

func TestUninstallConfirmPromptTranslations(t *testing.T) {
	// Português
	i18n.SetLanguage("pt")
	promptPT := i18n.T("uninstall_confirm_prompt")
	if !strings.Contains(promptPT, "'REMOVER'") {
		t.Errorf("PT: Esperava 'REMOVER' no prompt, obteve: %q", promptPT)
	}

	// Espanhol
	i18n.SetLanguage("es")
	promptES := i18n.T("uninstall_confirm_prompt")
	if !strings.Contains(promptES, "'ELIMINAR'") {
		t.Errorf("ES: Esperava 'ELIMINAR' no prompt, obteve: %q", promptES)
	}

	// Inglês
	i18n.SetLanguage("en")
	promptEN := i18n.T("uninstall_confirm_prompt")
	if !strings.Contains(promptEN, "'REMOVE'") {
		t.Errorf("EN: Esperava 'REMOVE' no prompt, obteve: %q", promptEN)
	}
}

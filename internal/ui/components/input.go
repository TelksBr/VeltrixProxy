package components

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

var reader = bufio.NewReader(os.Stdin)

// Prompt exibe uma pergunta com valor padrão opcional e aguarda o texto digitado
func Prompt(label string, defaultValue string) string {
	if defaultValue != "" {
		fmt.Printf("\n%s%s%s [%s%s%s]: ", theme.Blue, label, theme.Reset, theme.Cyan, defaultValue, theme.Reset)
	} else {
		fmt.Printf("\n%s%s%s: ", theme.Blue, label, theme.Reset)
	}

	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)
	if input == "" {
		return defaultValue
	}
	return input
}

func normalizeConfirmInput(input string) string {
	input = strings.TrimSpace(strings.ToLower(input))
	replacer := strings.NewReplacer(
		"ã", "a", "á", "a", "à", "a",
		"é", "e",
		"í", "i",
		"ó", "o",
		"ú", "u",
		"ñ", "n",
	)
	return replacer.Replace(input)
}

func parseConfirmAnswer(input string, defaultYes bool) bool {
	input = normalizeConfirmInput(input)
	switch input {
	case "":
		return defaultYes
	case "s", "sim", "si", "y", "yes":
		return true
	case "n", "nao", "no":
		return false
	default:
		return false
	}
}

func confirmHint(defaultYes bool) string {
	if defaultYes {
		return i18n.T("confirm_hint_yes")
	}
	return i18n.T("confirm_hint_no")
}

// Confirm solicita confirmação de sim ou não no idioma atual.
// Aceita s/sim/si/y/yes e n/nao/no em qualquer idioma.
func Confirm(question string, defaultYes bool) bool {
	fmt.Printf("\n%s%s%s [%s]: ", theme.Yellow, question, theme.Reset, confirmHint(defaultYes))
	input, _ := reader.ReadString('\n')
	return parseConfirmAnswer(input, defaultYes)
}

// FormatBool colorize true/false para menus de configuração.
func FormatBool(v bool) string {
	if v {
		return theme.Green + "true" + theme.Reset
	}
	return theme.Red + "false" + theme.Reset
}

func boolStateLabel(v bool) string {
	if v {
		return i18n.T("confirm_state_on")
	}
	return i18n.T("confirm_state_off")
}

// ConfirmToggle pergunta "ativar" se estiver off e "desativar" se estiver on.
// Enter ou "não/no" sempre mantém o valor atual.
func ConfirmToggle(enableQuestion, disableQuestion string, current bool) (newValue bool, changed bool) {
	question := enableQuestion
	if current {
		question = disableQuestion
	}

	fmt.Printf("\n%s%s: %s%s (%s)%s\n", theme.White, i18n.T("confirm_state_current"), FormatBool(current), theme.White, boolStateLabel(current), theme.Reset)
	if !Confirm(question, false) {
		return current, false
	}
	return !current, true
}

// ReadOption lê a opção do menu digitada pelo usuário
func ReadOption(promptText string) string {
	if promptText == "" {
		promptText = i18n.T("prompt_select_option")
	}
	fmt.Printf("\n%s%s:%s ", theme.Blue, promptText, theme.Reset)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

// Pause aguarda o usuário pressionar Enter para prosseguir
func Pause() {
	fmt.Printf("\n%s%s%s", theme.DarkGray, i18n.T("prompt_press_enter"), theme.Reset)
	_, _ = reader.ReadString('\n')
}

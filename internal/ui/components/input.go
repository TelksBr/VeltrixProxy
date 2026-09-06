package components

import (
	"bufio"
	"fmt"
	"os"
	"strings"

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

// Confirm solicita confirmação de sim ou não (s/n ou y/n)
func Confirm(question string, defaultYes bool) bool {
	defaultHint := "s/N"
	if defaultYes {
		defaultHint = "S/n"
	}

	fmt.Printf("\n%s%s%s [%s]: ", theme.Yellow, question, theme.Reset, defaultHint)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(strings.ToLower(input))

	if input == "" {
		return defaultYes
	}
	return input == "s" || input == "sim" || input == "y" || input == "yes"
}

// ReadOption lê a opção do menu digitada pelo usuário
func ReadOption(promptText string) string {
	if promptText == "" {
		promptText = "Selecione a opção desejada"
	}
	fmt.Printf("\n%s%s:%s ", theme.Blue, promptText, theme.Reset)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

// Pause aguarda o usuário pressionar Enter para prosseguir
func Pause() {
	fmt.Printf("\n%sPressione [Enter] para continuar...%s", theme.DarkGray, theme.Reset)
	_, _ = reader.ReadString('\n')
}

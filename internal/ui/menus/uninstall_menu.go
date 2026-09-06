package menus

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowUninstallMenu exibe a tela de confirmação e execução da desinstalação completa
func ShowUninstallMenu() {
	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("uninstall_title"), theme.Red, w)

	components.PrintBoxLine(fmt.Sprintf("%s⚠️  %s%s", theme.Yellow, i18n.T("uninstall_warning"), theme.Reset), w)
	components.PrintBoxDivider(w)

	components.PrintBoxLine(fmt.Sprintf("%s• %s%s", theme.White, i18n.T("uninstall_item_services"), theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%s• %s%s", theme.White, i18n.T("uninstall_item_configs"), theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%s• %s%s", theme.White, i18n.T("uninstall_item_kernel"), theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%s• %s%s", theme.White, i18n.T("uninstall_item_ssh"), theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%s• %s%s", theme.White, i18n.T("uninstall_item_binaries"), theme.Reset), w)

	components.PrintBoxDivider(w)
	components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Cyan, i18n.T("uninstall_cancel"), theme.Reset), w)
	components.PrintBoxFooter(w)

	fmt.Printf("\n%s%s%s\n", theme.Red, i18n.T("uninstall_confirm_prompt"), theme.Reset)
	label := i18n.T("uninstall_confirm_label")
	if label == "" {
		label = "Confirmação"
	}
	confirmInput := components.Prompt(label, "")

	if !IsValidUninstallConfirmation(confirmInput) {
		components.PrintInfo(i18n.T("uninstall_aborted"))
		components.Pause()
		return
	}

	components.ClearScreen()
	fmt.Printf("\n%s%s%s\n\n", theme.Red, i18n.T("uninstall_running"), theme.Reset)

	steps := system.GetUninstallSteps()
	for i, step := range steps {
		fmt.Printf("%s[%d/%d]%s %s... ", theme.Cyan, i+1, len(steps), theme.Reset, step.Description)
		if err := step.Action(); err != nil {
			fmt.Printf("%s[AVISO: %v]%s\n", theme.Yellow, err, theme.Reset)
		} else {
			fmt.Printf("%s[OK]%s\n", theme.Green, theme.Reset)
		}
		time.Sleep(200 * time.Millisecond)
	}

	fmt.Printf("\n%s✔ %s%s\n\n", theme.Green, i18n.T("uninstall_success"), theme.Reset)
	fmt.Printf("%sObrigado por utilizar o VeltrixProxy!%s\n\n", theme.Cyan, theme.Reset)
	os.Exit(0)
}

// IsValidUninstallConfirmation verifica se a entrada do usuário corresponde a uma das 3 palavras válidas:
// REMOVER (Português), REMOVE (Inglês) ou ELIMINAR (Espanhol), de forma insensível a maiúsculas/minúsculas.
func IsValidUninstallConfirmation(input string) bool {
	normalized := strings.ToUpper(strings.TrimSpace(input))
	switch normalized {
	case "REMOVER", "REMOVE", "ELIMINAR":
		return true
	default:
		return false
	}
}


package menus

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowMainMenu executa o loop principal do menu VT
func ShowMainMenu(cfgMgr *config.Manager) {
	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintDashboardHeader(w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • %s%s", theme.White, i18n.T("menu_opt_proxy"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s%s", theme.White, i18n.T("menu_opt_udpgw"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s%s", theme.White, i18n.T("menu_opt_tokens"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s%s", theme.White, i18n.T("menu_opt_optimization"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s%s", theme.White, i18n.T("menu_opt_connected_users"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s%s", theme.White, i18n.T("menu_opt_update"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 • %s%s", theme.White, i18n.T("menu_opt_change_language"), theme.Reset), w)

		components.PrintBoxDivider(w)
		exitLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("menu_opt_exit"), theme.Reset)
		components.PrintBoxLine(exitLine, w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption(i18n.T("prompt_select_option") + " [0-7]")
		switch choice {
		case "1":
			ShowProxyMenu(cfgMgr)
		case "2":
			ShowUDPGWMenu()
		case "3":
			ShowTokensMenu(cfgMgr)
		case "4":
			ShowOptimizeMenu()
		case "5":
			ShowOnlinesMenu()
		case "6":
			updateSystem()
		case "7":
			ShowLanguageMenu()
		case "0":
			components.ClearScreen()
			fmt.Printf("%sObrigado por usar o Veltrix Proxy!%s\n", theme.Cyan, theme.Reset)
			os.Exit(0)
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func updateSystem() {
	components.ClearScreen()
	fmt.Printf("\n%sBuscando e aplicando atualizações do Veltrix Proxy...%s\n\n", theme.Cyan, theme.Reset)

	updateCmd := "curl -fsSL https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh | bash -s -- --update --yes"
	cmd := exec.Command("bash", "-c", updateCmd)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		components.PrintError(fmt.Sprintf("Falha ao atualizar: %v", err))
	} else {
		components.PrintSuccess("Atualização concluída com sucesso!")
	}
	components.Pause()
}

package menus

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowUpdateMenu exibe a tela de detalhes de atualização e status de versões
func ShowUpdateMenu() {
	forceCheck := false

	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("update_title"), theme.Cyan, w)

		res := system.CheckUpdates(forceCheck)
		forceCheck = false

		// Proxy Server
		proxyBadge := theme.Green + "[" + i18n.T("update_badge_current") + "]" + theme.Reset
		var proxyLine string
		if res.Proxy.HasUpdate && res.Proxy.RemoteVersion != "" {
			proxyBadge = theme.Yellow + "[" + i18n.T("update_badge_available") + "]" + theme.Reset
			proxyLine = fmt.Sprintf("%s• Proxy Server: %s%s → %s%s %s",
				theme.White, theme.Gray, res.Proxy.InstalledVersion, theme.Green, res.Proxy.RemoteVersion, proxyBadge,
			)
		} else {
			proxyLine = fmt.Sprintf("%s• Proxy Server: %sv%s %s",
				theme.White, theme.Cyan, res.Proxy.InstalledVersion, proxyBadge,
			)
		}
		components.PrintBoxLine(proxyLine, w)

		// UDPGW
		udpgwBadge := theme.Green + "[" + i18n.T("update_badge_current") + "]" + theme.Reset
		var udpgwLine string
		if res.UDPGW.HasUpdate && res.UDPGW.RemoteVersion != "" {
			udpgwBadge = theme.Yellow + "[" + i18n.T("update_badge_available") + "]" + theme.Reset
			udpgwLine = fmt.Sprintf("%s• UDP Gateway:  %s%s → %s%s %s",
				theme.White, theme.Gray, res.UDPGW.InstalledVersion, theme.Green, res.UDPGW.RemoteVersion, udpgwBadge,
			)
		} else {
			udpgwLine = fmt.Sprintf("%s• UDP Gateway:  %sv%s %s",
				theme.White, theme.Cyan, res.UDPGW.InstalledVersion, udpgwBadge,
			)
		}
		components.PrintBoxLine(udpgwLine, w)

		// Menu VT
		menuBadge := theme.Green + "[" + i18n.T("update_badge_current") + "]" + theme.Reset
		var menuLine string
		if res.Menu.HasUpdate && res.Menu.RemoteVersion != "" {
			menuBadge = theme.Yellow + "[" + i18n.T("update_badge_available") + "]" + theme.Reset
			menuLine = fmt.Sprintf("%s• Menu CLI (vt):%s%s → %s%s %s",
				theme.White, theme.Gray, res.Menu.InstalledVersion, theme.Green, res.Menu.RemoteVersion, menuBadge,
			)
		} else {
			menuLine = fmt.Sprintf("%s• Menu CLI (vt):%sv%s %s",
				theme.White, theme.Cyan, res.Menu.InstalledVersion, menuBadge,
			)
		}
		components.PrintBoxLine(menuLine, w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%sℹ %s%s", theme.Gray, i18n.T("update_preserve_notice"), theme.Reset), w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • %s%s", theme.White, i18n.T("update_opt_apply"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s%s", theme.White, i18n.T("update_opt_check_again"), theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption(i18n.T("prompt_select_option") + " [0-2]")
		switch choice {
		case "1":
			runSystemUpdate()
			return
		case "2":
			components.PrintInfo("Consultando últimas versões disponíveis no GitHub...")
			forceCheck = true
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func runSystemUpdate() {
	components.ClearScreen()
	fmt.Printf("\n%s%s%s\n\n", theme.Cyan, i18n.T("update_running"), theme.Reset)

	updateCmd := "curl -fsSL https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh | bash -s -- --update --yes"
	cmd := exec.Command("bash", "-c", updateCmd)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		components.PrintError(fmt.Sprintf("%s: %v", i18n.T("operation_failed"), err))
		components.Pause()
	} else {
		// Limpa cache de update após atualização
		_ = os.Remove(system.UpdateCacheFile)
		components.PrintSuccess(i18n.T("update_success"))
		components.PrintInfo("Reiniciando menu atualizado...")
		time.Sleep(1500 * time.Millisecond)

		vtPath := "/usr/local/bin/vt"
		if _, err := os.Stat(vtPath); err != nil {
			if lp, err := exec.LookPath("vt"); err == nil {
				vtPath = lp
			} else if exe, err := os.Executable(); err == nil {
				vtPath = exe
			}
		}

		// Em sistemas Linux/Unix, substitui o processo atual pelo novo binário do menu
		_ = syscall.Exec(vtPath, []string{"vt"}, os.Environ())

		// Fallback com terminais devidamente conectados caso syscall.Exec não seja suportado (ex: Windows)
		fallbackCmd := exec.Command(vtPath)
		fallbackCmd.Stdin = os.Stdin
		fallbackCmd.Stdout = os.Stdout
		fallbackCmd.Stderr = os.Stderr
		_ = fallbackCmd.Run()
		os.Exit(0)
	}
}

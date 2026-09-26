package menus

import (
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowMainMenu executa o loop principal do menu VT
func ShowMainMenu(cfgMgr *config.Manager) {
	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintDashboardHeader(w)

		xrayOn, dnsttOn, udpgwOn, limitsOn := false, false, false, false
		if cfg, err := cfgMgr.Get(); err == nil && cfg != nil {
			xrayOn, dnsttOn = cfg.Xray.Enable, cfg.DNSTT.Enable
			udpgwOn, limitsOn = cfg.UDPGW.Internal, cfg.Limits.Enable
		}

		updateBadge := ""
		if system.HasPendingUpdates() {
			updateBadge = " " + theme.Yellow + "[" + i18n.T("update_badge_available") + "]"
		}

		menuLines := 0
		line := func(s string) {
			components.PrintBoxLine(s, w)
			menuLines++
		}
		divider := func() {
			components.PrintBoxDivider(w)
			menuLines++
		}

		line(mainMenuItem("1", i18n.T("menu_opt_proxy"), ""))
		line(mainMenuItem("2", i18n.T("menu_opt_xray"), mainMenuStatusBadge(xrayOn)))
		line(mainMenuItem("3", i18n.T("menu_opt_dnstt"), mainMenuStatusBadge(dnsttOn)))
		line(mainMenuItem("4", i18n.T("menu_opt_udpgw"), mainMenuStatusBadge(udpgwOn)))
		divider()
		line(mainMenuItem("5", i18n.T("menu_opt_users"), mainMenuStatusBadge(limitsOn)))
		line(mainMenuItem("6", i18n.T("menu_opt_tokens"), ""))
		divider()
		line(mainMenuItem("7", i18n.T("menu_opt_settings"), ""))
		line(fmt.Sprintf("%s8 • %s%s%s", theme.White, i18n.T("menu_opt_update"), updateBadge, theme.Reset))
		line(mainMenuItem("9", i18n.T("menu_opt_change_language"), ""))
		line(fmt.Sprintf("%sD • %s%s", theme.Red, i18n.T("menu_opt_uninstall"), theme.Reset))
		divider()
		line(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("menu_opt_exit"), theme.Reset))
		components.PrintMenuCredits(w)
		metricsOffset := components.MainMenuMetricsOffset(menuLines)

		// Atualizador dinâmico de métricas (CPU, RAM, Online, Status) sem piscar a tela
		stopLiveUpdater := make(chan struct{})
		var wg sync.WaitGroup
		wg.Add(1)
		go func() {
			defer wg.Done()
			ticker := time.NewTicker(2 * time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-stopLiveUpdater:
					return
				case <-ticker.C:
					components.UpdateDashboardMetrics(w, metricsOffset)
				}
			}
		}()

		choice := strings.ToLower(components.ReadOption(i18n.T("prompt_select_option") + " [0-9/D]"))
		close(stopLiveUpdater)
		wg.Wait()
		switch choice {
		case "1":
			ShowProxyMenu(cfgMgr)
		case "2":
			withRestartPrompt(cfgMgr, func() { ShowXrayMenu(cfgMgr) })
		case "3":
			withRestartPrompt(cfgMgr, func() { ShowDNSTTMenu(cfgMgr) })
		case "4":
			withRestartPrompt(cfgMgr, func() { ShowUDPGWMenu(cfgMgr) })
		case "5":
			withRestartPrompt(cfgMgr, func() { ShowUsersMenu(cfgMgr) })
		case "6":
			withRestartPrompt(cfgMgr, func() { ShowTokensMenu(cfgMgr) })
		case "7":
			withRestartPrompt(cfgMgr, func() { ShowSettingsMenu(cfgMgr) })
		case "8":
			ShowUpdateMenu()
		case "9":
			ShowLanguageMenu()
		case "d":
			ShowUninstallMenu()
		case "0":
			components.ClearScreen()
			fmt.Printf("%s%s%s\n", theme.Cyan, i18n.T("exit_message"), theme.Reset)
			os.Exit(0)
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func mainMenuItem(key, label, badge string) string {
	if badge == "" {
		return fmt.Sprintf("%s%s • %s%s", theme.White, key, label, theme.Reset)
	}
	return fmt.Sprintf("%s%s • %s %s%s", theme.White, key, label, badge, theme.Reset)
}

func mainMenuStatusBadge(on bool) string {
	if on {
		return theme.Green + "[" + i18n.T("status_active") + "]"
	}
	return theme.DarkGray + "[" + i18n.T("status_inactive") + "]"
}

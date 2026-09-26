package menus

import (
	"fmt"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/proxy"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowUsersMenu joins live connections, disconnect actions and the Limiter.
func ShowUsersMenu(cfgMgr *config.Manager) {
	for {
		limitsOn := false
		if cfg, err := cfgMgr.Get(); err == nil && cfg != nil {
			limitsOn = cfg.Limits.Enable
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("onlines_menu_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%d%s",
			theme.Gray, i18n.T("users_active_now"), theme.Reset, theme.Cyan, proxy.GetOnlineUsersTotal(), theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("users_opt_list"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("users_opt_kill"), ""), w)
		components.PrintBoxLine(menuItem("3", i18n.T("users_opt_kill_expired"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("4", i18n.T("adv_opt_limits"), featureBadge(limitsOn)), w)
		printMenuBack(w)

		switch readMenuOption("0-4") {
		case "1":
			components.ClearScreen()
			fmt.Printf("\n%s--- %s ---%s\n\n", theme.Cyan, i18n.T("users_list_title"), theme.Reset)
			fmt.Println(proxy.GetOnlineUsersDetails())
			components.Pause()
		case "2":
			target := strings.TrimSpace(components.Prompt(i18n.T("users_prompt_kill"), ""))
			if target != "" {
				if err := proxy.KillUser(target); err == nil {
					components.PrintSuccess(i18n.T("users_kill_done", target))
				} else {
					components.PrintWarning(i18n.T("users_kill_result", err))
				}
			}
			components.Pause()
		case "3":
			if components.Confirm(i18n.T("users_confirm_kill_expired"), true) {
				if err := proxy.KillExpired(); err == nil {
					components.PrintSuccess(i18n.T("users_kill_expired_done"))
				} else {
					components.PrintError(i18n.T("users_kill_expired_failed", err))
				}
			}
			components.Pause()
		case "4":
			ShowLimitsMenu(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

package menus

import (
	"fmt"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowLimitsMenu exibe o submenu de limites e expiração do usuário
func ShowLimitsMenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("limits_menu_title"), theme.Cyan, w)

		if !cfg.SSH.Internal {
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Yellow, i18n.T("limits_requires_ssh"), theme.Reset), w)
			components.PrintBoxDivider(w)
		}

		components.PrintBoxLine(menuItem("1", i18n.T("limits_opt_enable"), featureBadge(cfg.Limits.Enable)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("limits_opt_default_limit"), valueBadge(cfg.Limits.DefaultUserLimit)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("limits_opt_expire_check"), valueBadge(cfg.Limits.ExpireCheckInterval)), w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("limits_reaper_hint"), theme.Reset), w)
		components.PrintBoxLine(menuItem("4", i18n.T("limits_opt_passwd_file"), valueBadge(cfg.Limits.PasswdFile)), w)
		printMenuBack(w)

		switch readMenuOption("0-4") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Limits.Enable, func(v bool) { cfg.Limits.Enable = v },
				i18n.T("toggle_limits_on"), i18n.T("toggle_limits_off"), "limits.enable")
		case "2":
			if val, ok := promptInt(i18n.T("limits_opt_default_limit"), cfg.Limits.DefaultUserLimit, 0); ok {
				cfg.Limits.DefaultUserLimit = val
				saveField(cfgMgr, cfg, "limits.default_user_limit")
			}
			components.Pause()
		case "3":
			resp := strings.TrimSpace(components.Prompt(i18n.T("limits_expire_prompt"), cfg.Limits.ExpireCheckInterval))
			if resp != "" {
				cfg.Limits.ExpireCheckInterval = resp
				saveField(cfgMgr, cfg, "limits.expire_check_interval")
			}
			components.Pause()
		case "4":
			resp := strings.TrimSpace(components.Prompt(i18n.T("limits_opt_passwd_file"), cfg.Limits.PasswdFile))
			if resp != "" {
				cfg.Limits.PasswdFile = resp
				saveField(cfgMgr, cfg, "limits.passwd_file")
			}
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

package menus

import (
	"fmt"
	"strconv"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowLimitsMenu exibe o submenu de limites e expiração do usuário
func ShowLimitsMenu(cfgMgr *config.Manager) {
	for {
		cfg, err := cfgMgr.Get()
		if err != nil {
			components.PrintError(fmt.Sprintf("Erro ao carregar configuração: %v", err))
			components.Pause()
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("limits_menu_title"), theme.Cyan, w)

		if !cfg.SSH.Internal {
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Yellow, i18n.T("limits_requires_ssh"), theme.Reset), w)
			components.PrintBoxDivider(w)
		}

		line1 := fmt.Sprintf("%s1 • %s: %s", theme.White, i18n.T("limits_opt_enable"), components.FormatBool(cfg.Limits.Enable))
		line2 := fmt.Sprintf("%s2 • %s: %s%d%s (0=ilimitado)", theme.White, i18n.T("limits_opt_default_limit"), theme.Cyan, cfg.Limits.DefaultUserLimit, theme.White)
		line3 := fmt.Sprintf("%s3 • %s: %s%s%s (0=desativado, ex: 1m, 5m)", theme.White, i18n.T("limits_opt_expire_check"), theme.Cyan, cfg.Limits.ExpireCheckInterval, theme.White)
		line4 := fmt.Sprintf("%s4 • %s: %s%s%s", theme.White, i18n.T("limits_opt_passwd_file"), theme.Cyan, cfg.Limits.PasswdFile, theme.Reset)
		line5 := fmt.Sprintf("%s5 • %s: %s", theme.White, i18n.T("limits_opt_kill_expired"), components.FormatBool(cfg.Limits.KillExpired))

		components.PrintBoxLine(line1, w)
		components.PrintBoxLine(line2, w)
		components.PrintBoxLine(line3, w)
		components.PrintBoxLine(line4, w)
		components.PrintBoxLine(line5, w)

		components.PrintBoxDivider(w)
		backLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset)
		components.PrintBoxLine(backLine, w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-5]")
		switch choice {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Limits.Enable, func(v bool) { cfg.Limits.Enable = v },
				i18n.T("toggle_limits_on"),
				i18n.T("toggle_limits_off"),
				"limits.enable")

		case "2":
			currentVal := strconv.Itoa(cfg.Limits.DefaultUserLimit)
			resp := components.Prompt("Limite padrão de conexões simultâneas (0=ilimitado)", currentVal)
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.Limits.DefaultUserLimit = val
				if err := cfgMgr.Save(cfg); err == nil {
					components.PrintSuccess(fmt.Sprintf("default_user_limit atualizado para %d.", val))
				}
			} else {
				components.PrintError("Valor numérico inválido.")
			}
			components.Pause()

		case "3":
			resp := components.Prompt("Intervalo de checagem e desconexão de expirados (ex: 1m, 5m, 0 para desativar)", cfg.Limits.ExpireCheckInterval)
			if resp != "" {
				cfg.Limits.ExpireCheckInterval = resp
				if err := cfgMgr.Save(cfg); err == nil {
					components.PrintSuccess(fmt.Sprintf("expire_check_interval atualizado para '%s'.", resp))
				}
			}
			components.Pause()

		case "4":
			resp := components.Prompt("Caminho do arquivo passwd", cfg.Limits.PasswdFile)
			if resp != "" {
				cfg.Limits.PasswdFile = resp
				if err := cfgMgr.Save(cfg); err == nil {
					components.PrintSuccess(fmt.Sprintf("passwd_file atualizado para '%s'.", resp))
				}
			}
			components.Pause()

		case "5":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Limits.KillExpired, func(v bool) { cfg.Limits.KillExpired = v },
				i18n.T("toggle_kill_expired_on"),
				i18n.T("toggle_kill_expired_off"),
				"limits.kill_expired")

		case "0":
			return

		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

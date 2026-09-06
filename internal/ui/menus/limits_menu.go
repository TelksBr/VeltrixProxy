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

		// Validação estrita: Limiter só opera se SSH Nativo estiver habilitado
		if !cfg.SSH.Internal {
			components.PrintError("O módulo de limites (Limiter) requer o SSH Nativo Go (ssh.internal: true) para ser configurado.")
			components.Pause()
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("limits_menu_title"), theme.Cyan, w)

		enBadge := theme.Red + "false" + theme.Reset
		if cfg.Limits.Enable {
			enBadge = theme.Green + "true" + theme.Reset
		}

		line1 := fmt.Sprintf("%s1 • %s: %s", theme.White, i18n.T("limits_opt_enable"), enBadge)
		line2 := fmt.Sprintf("%s2 • %s: %s%d%s (0=ilimitado)", theme.White, i18n.T("limits_opt_default_limit"), theme.Cyan, cfg.Limits.DefaultUserLimit, theme.White)
		line3 := fmt.Sprintf("%s3 • %s: %s%s%s (0=desativado, ex: 1m, 5m)", theme.White, i18n.T("limits_opt_expire_check"), theme.Cyan, cfg.Limits.ExpireCheckInterval, theme.White)
		line4 := fmt.Sprintf("%s4 • %s: %s%s%s", theme.White, i18n.T("limits_opt_passwd_file"), theme.Cyan, cfg.Limits.PasswdFile, theme.Reset)

		components.PrintBoxLine(line1, w)
		components.PrintBoxLine(line2, w)
		components.PrintBoxLine(line3, w)
		components.PrintBoxLine(line4, w)

		components.PrintBoxDivider(w)
		backLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset)
		components.PrintBoxLine(backLine, w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-4]")
		switch choice {
		case "1":
			newValue := components.Confirm("Habilitar controle de limites e expiração (Limiter)?", cfg.Limits.Enable)
			cfg.Limits.Enable = newValue
			if err := cfgMgr.Save(cfg); err == nil {
				components.PrintSuccess("Configuração limits.enable atualizada com sucesso.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao salvar: %v", err))
			}
			components.Pause()

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

		case "0":
			return

		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

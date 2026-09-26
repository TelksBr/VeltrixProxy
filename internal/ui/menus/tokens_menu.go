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

// ShowTokensMenu exibe o menu de gerenciamento do token de licença
func ShowTokensMenu(cfgMgr *config.Manager) {
	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("tokens_menu_title"), theme.Cyan, w)

		currentToken := config.LoadToken()
		maskedToken := i18n.T("tokens_none")
		if len(currentToken) > 8 {
			maskedToken = currentToken[:4] + "..." + currentToken[len(currentToken)-4:]
		} else if currentToken != "" {
			maskedToken = currentToken
		}

		components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s", theme.Gray, i18n.T("tokens_current"), theme.Reset, valueBadge(maskedToken)), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("tokens_opt_set"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("tokens_opt_validate"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-2") {
		case "1":
			newToken := strings.TrimSpace(components.Prompt(i18n.T("tokens_prompt_new"), ""))
			if newToken != "" {
				if err := config.SaveToken(newToken); err != nil {
					components.PrintError(i18n.T("tokens_save_failed", err))
				} else {
					if cfg, err := cfgMgr.Get(); err == nil && cfg != nil {
						cfg.Token = newToken
						_ = cfgMgr.Save(cfg)
					}
					components.PrintSuccess(i18n.T("tokens_saved"))
				}
			}
			components.Pause()
		case "2":
			if currentToken == "" {
				components.PrintWarning(i18n.T("tokens_not_set"))
			} else if proxy.ValidateToken(currentToken) {
				components.PrintSuccess(i18n.T("tokens_valid"))
			} else {
				components.PrintError(i18n.T("tokens_invalid"))
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

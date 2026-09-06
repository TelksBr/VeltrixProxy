package menus

import (
	"fmt"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/proxy"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowTokensMenu exibe o menu de gerenciamento do token de licença
func ShowTokensMenu(cfgMgr *config.Manager) {
	for {
		components.ClearScreen()
		components.PrintDashboardHeader(components.DefaultBoxWidth)

		currentToken := config.LoadToken()
		maskedToken := "nenhum"
		if len(currentToken) > 8 {
			maskedToken = currentToken[:4] + "..." + currentToken[len(currentToken)-4:]
		} else if currentToken != "" {
			maskedToken = currentToken
		}

		infoLine := fmt.Sprintf("%sToken Atual:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, maskedToken, theme.Reset)
		components.PrintBoxLine(infoLine, components.DefaultBoxWidth)
		components.PrintBoxDivider(components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Inserir / Alterar token de acesso%s", theme.White, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Validar token atual com a API%s", theme.White, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Voltar ao menu principal%s", theme.Red, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Selecione a opção [0-2]")
		switch choice {
		case "1":
			newToken := components.Prompt("Digite seu novo token de acesso", "")
			if newToken != "" {
				if err := config.SaveToken(newToken); err == nil {
					cfg, _ := cfgMgr.Get()
					cfg.Token = newToken
					_ = cfgMgr.Save(cfg)
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess("Token atualizado e serviço proxy reiniciado.")
				} else {
					components.PrintError(fmt.Sprintf("Falha ao salvar token: %v", err))
				}
			}
			components.Pause()

		case "2":
			if currentToken == "" {
				components.PrintWarning("Nenhum token configurado no momento.")
			} else {
				if proxy.ValidateToken(currentToken) {
					components.PrintSuccess("Token validado com sucesso pela API!")
				} else {
					components.PrintError("Token inválido ou expirado.")
				}
			}
			components.Pause()

		case "0":
			return
		}
	}
}

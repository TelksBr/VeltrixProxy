package menus

import (
	"fmt"

	"github.com/TelksBr/VeltrixProxy/internal/proxy"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowOnlinesMenu exibe o menu de monitoramento e desconexão de usuários
func ShowOnlinesMenu() {
	for {
		components.ClearScreen()
		components.PrintDashboardHeader(components.DefaultBoxWidth)

		total := proxy.GetOnlineUsersTotal()
		infoLine := fmt.Sprintf("%sConexões ativas no momento:%s %s%d conexões%s",
			theme.Gray, theme.Reset, theme.Cyan, total, theme.Reset,
		)
		components.PrintBoxLine(infoLine, components.DefaultBoxWidth)
		components.PrintBoxDivider(components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Listar conexões ativas detalhadas%s", theme.White, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Desconectar usuário específico (--kill-user)%s", theme.White, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Desconectar todos os usuários expirados (--kill-expired)%s", theme.White, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Voltar ao menu principal%s", theme.Red, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Selecione a opção [0-3]")
		switch choice {
		case "1":
			components.ClearScreen()
			details := proxy.GetOnlineUsersDetails()
			fmt.Printf("\n%s--- CONEXÕES ATIVAS NO PROXY ---%s\n\n", theme.Cyan, theme.Reset)
			fmt.Println(details)
			components.Pause()

		case "2":
			targetUser := components.Prompt("Digite o nome do usuário para desconectar", "")
			if targetUser != "" {
				if err := proxy.KillUser(targetUser); err == nil {
					components.PrintSuccess(fmt.Sprintf("Comando de desconexão executado para '%s'.", targetUser))
				} else {
					components.PrintWarning(fmt.Sprintf("Resultado: %v", err))
				}
			}
			components.Pause()

		case "3":
			if components.Confirm("Deseja derrubar a conexão de todos os usuários expirados?", true) {
				if err := proxy.KillExpired(); err == nil {
					components.PrintSuccess("Varredura e desconexão de usuários expirados concluída.")
				} else {
					components.PrintError(fmt.Sprintf("Falha ao executar: %v", err))
				}
			}
			components.Pause()

		case "0":
			return
		}
	}
}

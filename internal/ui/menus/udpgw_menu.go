package menus

import (
	"fmt"
	"strconv"

	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/udpgw"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowUDPGWMenu exibe o menu de gerenciamento do BadVPN / UDPGW
func ShowUDPGWMenu() {
	for {
		components.ClearScreen()
		components.PrintDashboardHeader(components.DefaultBoxWidth)

		currentPort := udpgw.GetConfiguredPort()
		isActive := udpgw.IsActive()

		statusBadge := theme.BadgeOffline
		if isActive {
			statusBadge = theme.BadgeOnline
		}

		infoLine := fmt.Sprintf("%sBadVPN / UDPGW:%s %s %s│ Porta:%s %s%d%s",
			theme.Gray, theme.Reset, statusBadge,
			theme.DarkGray, theme.Reset, theme.Cyan, currentPort, theme.Reset,
		)
		components.PrintBoxLine(infoLine, components.DefaultBoxWidth)
		components.PrintBoxDivider(components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Iniciar serviço UDPGW%s", theme.White, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Pausar / Parar serviço UDPGW%s", theme.White, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Reiniciar serviço UDPGW%s", theme.White, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Alterar porta de escuta do UDPGW%s", theme.White, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Voltar ao menu principal%s", theme.Red, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Selecione a opção [0-4]")
		switch choice {
		case "1":
			if err := system.StartService(system.UDPGWServiceName); err == nil {
				components.PrintSuccess("Serviço UDPGW iniciado com sucesso.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao iniciar: %v", err))
			}
			components.Pause()

		case "2":
			if err := system.StopService(system.UDPGWServiceName); err == nil {
				components.PrintSuccess("Serviço UDPGW pausado com sucesso.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao parar: %v", err))
			}
			components.Pause()

		case "3":
			if err := system.RestartService(system.UDPGWServiceName); err == nil {
				components.PrintSuccess("Serviço UDPGW reiniciado com sucesso.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao reiniciar: %v", err))
			}
			components.Pause()

		case "4":
			resp := components.Prompt("Nova porta para o UDPGW (ex: 7400, 7300)", strconv.Itoa(currentPort))
			if val, err := strconv.Atoi(resp); err == nil && val > 0 && val <= 65535 {
				if err := udpgw.SetPort(val); err == nil {
					components.PrintSuccess(fmt.Sprintf("Porta do UDPGW atualizada para %d.", val))
				} else {
					components.PrintError(fmt.Sprintf("Falha ao salvar porta: %v", err))
				}
			} else {
				components.PrintError("Porta inválida.")
			}
			components.Pause()

		case "0":
			return
		}
	}
}

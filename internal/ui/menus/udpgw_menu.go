package menus

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/udpgw"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowUDPGWMenu exibe o menu de gerenciamento do BadVPN / UDPGW com suporte a multi-portas
func ShowUDPGWMenu() {
	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("udpgw_menu_title"), theme.Cyan, w)

		ports := udpgw.ListConfiguredPorts()
		isAnyActive := udpgw.IsActive()

		statusBadge := theme.BadgeOffline
		if isAnyActive {
			statusBadge = theme.BadgeOnline
		}

		// Resumo das portas
		var portsStr string
		if len(ports) == 0 {
			portsStr = "nenhuma"
		} else {
			var formatted []string
			for _, p := range ports {
				if udpgw.IsPortActive(p) {
					formatted = append(formatted, fmt.Sprintf("%s%d [ON]%s", theme.Green, p, theme.Reset))
				} else {
					formatted = append(formatted, fmt.Sprintf("%s%d [OFF]%s", theme.Red, p, theme.Reset))
				}
			}
			portsStr = strings.Join(formatted, ", ")
		}

		infoLine := fmt.Sprintf("%sBadVPN / UDPGW:%s %s %s│ Portas:%s %s",
			theme.Gray, theme.Reset, statusBadge,
			theme.DarkGray, theme.Reset, portsStr,
		)
		components.PrintBoxLine(infoLine, w)
		components.PrintBoxDivider(w)

		// Gestão de Portas
		components.PrintBoxLine(fmt.Sprintf("%s1 • %s%s", theme.White, i18n.T("udpgw_opt_open"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s%s", theme.White, i18n.T("udpgw_opt_remove"), theme.Reset), w)
		components.PrintBoxDivider(w)

		// Controle de Serviços
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s%s", theme.White, i18n.T("udpgw_opt_start"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s%s", theme.White, i18n.T("udpgw_opt_stop"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s%s", theme.White, i18n.T("udpgw_opt_restart"), theme.Reset), w)
		components.PrintBoxDivider(w)

		// Configurações Avançadas e Logs
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s%s", theme.White, i18n.T("udpgw_opt_adv"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 • %s%s", theme.White, i18n.T("udpgw_opt_logs"), theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("proxy_opt_back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Selecione a opção [0-7]")
		switch choice {
		case "1":
			handleCreatePort(ports)
		case "2":
			handleRemovePort(ports)
		case "3":
			handleStartPort(ports)
		case "4":
			handleStopPort(ports)
		case "5":
			handleRestartPort(ports)
		case "6":
			handleAdvancedOptions(ports)
		case "7":
			handleViewLogs(ports)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func handleCreatePort(existingPorts []int) {
	defaultPort := udpgw.DefaultPort
	if len(existingPorts) > 0 {
		defaultPort = existingPorts[len(existingPorts)-1] + 100
		if defaultPort > 65535 {
			defaultPort = 7300
		}
	}

	resp := components.Prompt("Porta TCP do gateway (-listen)", strconv.Itoa(defaultPort))
	port, err := strconv.Atoi(resp)
	if err != nil || port <= 0 || port > 65535 {
		components.PrintError("Porta inválida. Deve estar entre 1 e 65535.")
		components.Pause()
		return
	}

	for _, p := range existingPorts {
		if p == port {
			components.PrintWarning(fmt.Sprintf("A porta %d já está configurada.", port))
			components.Pause()
			return
		}
	}

	inUse, procInfo := system.IsPortInUseByOther("tcp", port)
	if inUse {
		components.PrintWarning(fmt.Sprintf("Atenção: A porta TCP %d já está em uso por '%s'.", port, procInfo))
		components.PrintInfo("Criar o gateway UDPGW em uma porta ocupada fará o serviço systemd falhar ao iniciar.")
		if !components.Confirm("Deseja criar a porta mesmo assim?", false) {
			return
		}
	}

	components.PrintInfo(fmt.Sprintf("Configurando e iniciando porta UDPGW %d...", port))
	if err := udpgw.CreatePort(port); err != nil {
		components.PrintError(fmt.Sprintf("Falha ao criar serviço da porta %d: %v", port, err))
	} else {
		components.PrintSuccess(fmt.Sprintf("Porta UDPGW %d criada e iniciada com sucesso.", port))
	}
	components.Pause()
}

func handleRemovePort(ports []int) {
	if len(ports) == 0 {
		components.PrintWarning("Nenhuma porta UDPGW configurada para remover.")
		components.Pause()
		return
	}

	port, _, cancelled := selectPortInteractive(ports, "Remover porta UDPGW", false)
	if cancelled {
		return
	}

	if !components.Confirm(fmt.Sprintf("Deseja realmente remover a porta %d (parar serviço e apagar configs)?", port), false) {
		return
	}

	if err := udpgw.DeletePort(port); err != nil {
		components.PrintError(fmt.Sprintf("Erro ao remover porta %d: %v", port, err))
	} else {
		components.PrintSuccess(fmt.Sprintf("Porta %d removida com sucesso.", port))
	}
	components.Pause()
}

func handleStartPort(ports []int) {
	if len(ports) == 0 {
		components.PrintWarning("Nenhuma porta configurada. Crie uma porta primeiro na opção 1.")
		components.Pause()
		return
	}

	port, isAll, cancelled := selectPortInteractive(ports, "Iniciar serviço UDPGW", true)
	if cancelled {
		return
	}

	startPortChecked := func(p int) {
		if !udpgw.IsPortActive(p) {
			inUse, procInfo := system.IsPortInUseByOther("tcp", p)
			if inUse {
				components.PrintWarning(fmt.Sprintf("Atenção: A porta TCP %d já está em uso por '%s'.", p, procInfo))
				if !components.Confirm(fmt.Sprintf("Deseja tentar iniciar a porta UDPGW %d mesmo assim?", p), false) {
					return
				}
			}
		}
		if err := udpgw.StartPort(p); err != nil {
			components.PrintError(fmt.Sprintf("Porta %d: falha ao iniciar: %v", p, err))
		} else {
			components.PrintSuccess(fmt.Sprintf("Porta %d: iniciada com sucesso.", p))
		}
	}

	if isAll {
		for _, p := range ports {
			startPortChecked(p)
		}
	} else {
		startPortChecked(port)
	}
	components.Pause()
}

func handleStopPort(ports []int) {
	if len(ports) == 0 {
		components.PrintWarning("Nenhuma porta configurada.")
		components.Pause()
		return
	}

	port, isAll, cancelled := selectPortInteractive(ports, "Pausar / parar serviço UDPGW", true)
	if cancelled {
		return
	}

	if isAll {
		for _, p := range ports {
			if err := udpgw.StopPort(p); err != nil {
				components.PrintError(fmt.Sprintf("Porta %d: falha ao parar: %v", p, err))
			} else {
				components.PrintSuccess(fmt.Sprintf("Porta %d: pausada com sucesso.", p))
			}
		}
	} else {
		if err := udpgw.StopPort(port); err != nil {
			components.PrintError(fmt.Sprintf("Falha ao parar porta %d: %v", port, err))
		} else {
			components.PrintSuccess(fmt.Sprintf("Porta %d pausada com sucesso.", port))
		}
	}
	components.Pause()
}

func handleRestartPort(ports []int) {
	if len(ports) == 0 {
		components.PrintWarning("Nenhuma porta configurada.")
		components.Pause()
		return
	}

	port, isAll, cancelled := selectPortInteractive(ports, "Reiniciar serviço UDPGW", true)
	if cancelled {
		return
	}

	if isAll {
		for _, p := range ports {
			if err := udpgw.RestartPort(p); err != nil {
				components.PrintError(fmt.Sprintf("Porta %d: falha ao reiniciar: %v", p, err))
			} else {
				components.PrintSuccess(fmt.Sprintf("Porta %d: reiniciada com sucesso.", p))
			}
		}
	} else {
		if err := udpgw.RestartPort(port); err != nil {
			components.PrintError(fmt.Sprintf("Falha ao reiniciar porta %d: %v", port, err))
		} else {
			components.PrintSuccess(fmt.Sprintf("Porta %d reiniciada com sucesso.", port))
		}
	}
	components.Pause()
}

func handleViewLogs(ports []int) {
	if len(ports) == 0 {
		components.PrintWarning("Nenhuma porta configurada.")
		components.Pause()
		return
	}

	port, _, cancelled := selectPortInteractive(ports, "Visualizar logs da porta", false)
	if cancelled {
		return
	}

	svcName := udpgw.GetServiceName(port)
	components.ClearScreen()
	fmt.Printf("%s=== Logs do serviço %s (últimas 50 linhas) ===%s\n\n", theme.Cyan, svcName, theme.Reset)

	logs, err := system.GetServiceLogs(svcName, 50)
	if err != nil {
		components.PrintError(fmt.Sprintf("Erro ao ler logs: %v", err))
	} else if strings.TrimSpace(logs) == "" {
		fmt.Printf("%sNenhum registro encontrado para %s.%s\n", theme.Gray, svcName, theme.Reset)
	} else {
		fmt.Println(logs)
	}
	components.Pause()
}

func handleAdvancedOptions(ports []int) {
	if len(ports) == 0 {
		components.PrintWarning("Nenhuma porta configurada. Crie uma porta primeiro.")
		components.Pause()
		return
	}

	port, _, cancelled := selectPortInteractive(ports, "Opções avançadas da porta", false)
	if cancelled {
		return
	}

	showUDPGWAdvancedMenu(port)
}

func showUDPGWAdvancedMenu(port int) {
	cfg, err := udpgw.LoadPortConfig(port)
	if err != nil {
		components.PrintError(fmt.Sprintf("Erro ao carregar configurações da porta %d: %v", port, err))
		components.Pause()
		return
	}

	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(fmt.Sprintf("UDPGW AVANÇADO - PORTA %d", port), theme.Cyan, w)

		metricsDisplay := cfg.MetricsListen
		if metricsDisplay == "" {
			metricsDisplay = "[Desativado (Padrão)]"
		}

		debugDisplay := "Desativado"
		if cfg.Debug {
			debugDisplay = "Ativado (-debug)"
		}

		components.PrintBoxLine(fmt.Sprintf("%s• Listen:  %s%s", theme.White, theme.Cyan, cfg.Listen), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Métricas:%s%s", theme.White, theme.Cyan, metricsDisplay), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Debug:   %s%s", theme.White, theme.Cyan, debugDisplay), w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Rede (Listen: %s, UDP Bind)%s", theme.White, cfg.Listen, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Métricas Prometheus (-metrics-listen)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Performance (Max frame, Write channel, Buffers UDP)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Limites de clientes (Conexões, Map entries, Clientes)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • Timeouts e manutenção (TTL, Reap, Idle, Auto-restart)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 • Alternar modo debug (-debug)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 • Visualizar comando ExecStart gerado%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s8 • Salvar e aplicar alterações no systemd%s", theme.Green, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Voltar sem salvar%s", theme.Red, theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Selecione a opção [0-8]")
		switch choice {
		case "1":
			// Rede
			newListen := components.Prompt("Listen interface/porta (-listen)", cfg.Listen)
			if strings.TrimSpace(newListen) != "" {
				cfg.Listen = strings.TrimSpace(newListen)
			}
			newBind := components.Prompt("UDP bind IP (-udp-bind, vazio=padrão)", cfg.UDPBind)
			cfg.UDPBind = strings.TrimSpace(newBind)
			components.PrintSuccess("Configurações de rede atualizadas na memória.")
			components.Pause()

		case "2":
			// Métricas Prometheus
			components.ClearScreen()
			fmt.Printf("\n%s=== Configuração de Métricas Prometheus (-metrics-listen) ===%s\n", theme.Cyan, theme.Reset)
			fmt.Printf("%sNota: Em produção, métricas são desativadas por padrão para economizar recursos e portas.%s\n\n", theme.Gray, theme.Reset)

			currentVal := cfg.MetricsListen
			if currentVal == "" {
				fmt.Printf("Status atual: %sDesativado%s\n\n", theme.Yellow, theme.Reset)
			} else {
				fmt.Printf("Status atual: %sAtivado (%s)%s\n\n", theme.Green, currentVal, theme.Reset)
			}

			fmt.Println("1 • Desativar métricas (padrão de produção)")
			fmt.Println("2 • Ativar / alterar endereço de métricas (ex: 127.0.0.1:9091)")
			fmt.Println("0 • Voltar")
			opt := components.ReadOption("Selecione [0-2]")
			if opt == "1" {
				cfg.MetricsListen = ""
				components.PrintSuccess("Métricas do Prometheus desativadas (-metrics-listen removido).")
			} else if opt == "2" {
				def := currentVal
				if def == "" {
					def = "127.0.0.1:9091"
				}
				addr := components.Prompt("Endereço para escuta de métricas (IP:Porta)", def)
				cfg.MetricsListen = strings.TrimSpace(addr)
				components.PrintSuccess(fmt.Sprintf("Métricas configuradas para: %s", cfg.MetricsListen))
			}
			components.Pause()

		case "3":
			// Performance
			cfg.MaxFrame = strings.TrimSpace(components.Prompt("Max frame bytes (-max-frame, vazio=padrão)", cfg.MaxFrame))
			cfg.WriteChan = strings.TrimSpace(components.Prompt("Write channel (-write-chan, vazio=padrão)", cfg.WriteChan))
			cfg.UDPRbuf = strings.TrimSpace(components.Prompt("UDP read buffer (-udp-rbuf, vazio=padrão)", cfg.UDPRbuf))
			cfg.UDPWbuf = strings.TrimSpace(components.Prompt("UDP write buffer (-udp-wbuf, vazio=padrão)", cfg.UDPWbuf))
			components.PrintSuccess("Configurações de performance atualizadas.")
			components.Pause()

		case "4":
			// Limites
			cfg.MaxClientConns = strings.TrimSpace(components.Prompt("Max client conns (-max-client-conns, vazio=padrão)", cfg.MaxClientConns))
			cfg.MaxMapEntries = strings.TrimSpace(components.Prompt("Max map entries (-max-map-entries, vazio=padrão)", cfg.MaxMapEntries))
			cfg.MaxClients = strings.TrimSpace(components.Prompt("Max clients (-max-clients, vazio=padrão)", cfg.MaxClients))
			components.PrintSuccess("Limites de clientes atualizados.")
			components.Pause()

		case "5":
			// Timeouts
			cfg.MapTTL = strings.TrimSpace(components.Prompt("Map TTL (-map-ttl, ex: 90s, vazio=padrão)", cfg.MapTTL))
			cfg.ReapEvery = strings.TrimSpace(components.Prompt("Reap every (-reap-every, ex: 10s, vazio=padrão)", cfg.ReapEvery))
			cfg.IdleTimeout = strings.TrimSpace(components.Prompt("Idle timeout (-idle-timeout, ex: 2m, vazio=padrão)", cfg.IdleTimeout))
			cfg.AutoRestartInterval = strings.TrimSpace(components.Prompt("Auto-restart interval (-auto-restart-interval, vazio=padrão)", cfg.AutoRestartInterval))
			cfg.AutoRestartGrace = strings.TrimSpace(components.Prompt("Auto-restart grace (-auto-restart-grace, vazio=padrão)", cfg.AutoRestartGrace))
			components.PrintSuccess("Timeouts atualizados.")
			components.Pause()

		case "6":
			newVal, changed := components.ConfirmToggle(
				i18n.T("toggle_udpgw_debug_on"),
				i18n.T("toggle_udpgw_debug_off"),
				cfg.Debug,
			)
			if !changed {
				components.PrintInfo(i18n.T("confirm_no_change", "debug", cfg.Debug))
			} else {
				cfg.Debug = newVal
				if cfg.Debug {
					components.PrintSuccess("Modo debug ativado (-debug será incluído).")
				} else {
					components.PrintSuccess("Modo debug desativado.")
				}
			}
			components.Pause()

		case "7":
			// Visualizar ExecStart
			execCmd := udpgw.BuildExecStart(cfg)
			components.ClearScreen()
			fmt.Printf("\n%s=== Comando ExecStart Calculado ===%s\n\n", theme.Cyan, theme.Reset)
			fmt.Printf("%s%s%s\n\n", theme.White, execCmd, theme.Reset)
			components.Pause()

		case "8":
			// Salvar e aplicar
			components.PrintInfo(fmt.Sprintf("Salvando configuração e atualizando unit udpgw-%d.service...", port))
			if err := udpgw.SaveAndApply(cfg); err != nil {
				components.PrintError(fmt.Sprintf("Erro ao aplicar configurações: %v", err))
			} else {
				components.PrintSuccess("Configuração salva e aplicada com sucesso no systemd!")
			}
			components.Pause()
			return

		case "0":
			return
		}
	}
}

// selectPortInteractive exibe seleção interativa de portas
func selectPortInteractive(ports []int, title string, allowAll bool) (int, bool, bool) {
	if len(ports) == 0 {
		return 0, false, true
	}
	if len(ports) == 1 && !allowAll {
		return ports[0], false, false
	}

	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(title, theme.Cyan, w)

		for i, p := range ports {
			statusStr := fmt.Sprintf("%s[OFF]%s", theme.Red, theme.Reset)
			if udpgw.IsPortActive(p) {
				statusStr = fmt.Sprintf("%s[ON]%s", theme.Green, theme.Reset)
			}
			line := fmt.Sprintf("%s%d • Porta %d %s", theme.White, i+1, p, statusStr)
			components.PrintBoxLine(line, w)
		}

		if allowAll {
			components.PrintBoxDivider(w)
			components.PrintBoxLine(fmt.Sprintf("%sA • Aplicar em todas as portas%s", theme.Yellow, theme.Reset), w)
		}

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Cancelar / Voltar%s", theme.Red, theme.Reset), w)
		components.PrintBoxFooter(w)

		prompt := fmt.Sprintf("Selecione a porta [1-%d", len(ports))
		if allowAll {
			prompt += ", A"
		}
		prompt += ", 0]"

		choice := strings.TrimSpace(components.ReadOption(prompt))
		if choice == "0" || choice == "" {
			return 0, false, true
		}
		if allowAll && strings.EqualFold(choice, "A") {
			return 0, true, false
		}

		idx, err := strconv.Atoi(choice)
		if err == nil && idx >= 1 && idx <= len(ports) {
			return ports[idx-1], false, false
		}

		components.PrintError(i18n.T("invalid_option"))
		components.Pause()
	}
}

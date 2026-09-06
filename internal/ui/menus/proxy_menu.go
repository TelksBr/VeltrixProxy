package menus

import (
	"fmt"
	"strings"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowProxyMenu exibe o menu de gerenciamento do ProxyVT
func ShowProxyMenu(cfgMgr *config.Manager) {
	for {
		cfg, err := cfgMgr.Get()
		if err != nil {
			components.PrintError(fmt.Sprintf("Erro ao carregar configuração: %v", err))
			components.Pause()
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("proxy_menu_title"), theme.Cyan, w)

		isProxyActive := system.IsServiceActive(system.ProxyServiceName)
		proxyBadge := theme.BadgeOffline
		if isProxyActive {
			proxyBadge = theme.BadgeOnline
		}

		// Resumo de Portas
		var activePortsStr string
		if len(cfg.Ports) > 0 {
			activePortsStr = strings.Join(cfg.Ports, ", ")
		} else {
			activePortsStr = "nenhuma"
		}

		statusLine := fmt.Sprintf("%sStatus:%s %s %s│ Portas Ativas:%s %s%s%s",
			theme.Gray, theme.Reset, proxyBadge,
			theme.DarkGray, theme.Reset, theme.Cyan, activePortsStr, theme.Reset,
		)
		components.PrintBoxLine(statusLine, w)
		components.PrintBoxDivider(w)

		// Gestão de Portas
		components.PrintBoxLine(fmt.Sprintf("%s1 • %s%s", theme.White, i18n.T("proxy_opt_add"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s%s", theme.White, i18n.T("proxy_opt_remove"), theme.Reset), w)

		components.PrintBoxDivider(w)

		// Controle do Serviço
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s%s", theme.White, i18n.T("proxy_opt_start"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s%s", theme.White, i18n.T("proxy_opt_stop"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s%s", theme.White, i18n.T("proxy_opt_restart"), theme.Reset), w)

		components.PrintBoxDivider(w)

		// Configurações & Diagnóstico
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s%s", theme.White, i18n.T("proxy_opt_adv"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 • %s%s", theme.White, i18n.T("proxy_opt_http"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s8 • %s%s", theme.White, i18n.T("proxy_opt_details"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s9 • %s%s", theme.White, i18n.T("proxy_opt_journal_logs"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%sL • %s%s", theme.White, i18n.T("proxy_opt_file_logs"), theme.Reset), w)

		components.PrintBoxDivider(w)
		backLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("proxy_opt_back"), theme.Reset)
		components.PrintBoxLine(backLine, w)
		components.PrintBoxFooter(w)

		choice := strings.ToLower(components.ReadOption(i18n.T("prompt_select_option") + " [0-9/L]"))
		switch choice {
		case "1":
			portInput := components.Prompt("Digite a porta para adicionar (ex: 80 ou 443:ssl)", "")
			if portInput != "" {
				if err := cfgMgr.AddPort(portInput); err == nil {
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess(fmt.Sprintf("Porta %s adicionada e proxy reiniciado.", portInput))
				} else {
					components.PrintError(fmt.Sprintf("Erro ao adicionar porta: %v", err))
				}
				components.Pause()
			}

		case "2":
			removePortInteractive(cfgMgr)

		case "3":
			if system.IsServiceActive(system.ProxyServiceName) {
				components.PrintInfo("O serviço do proxy já está em execução (ONLINE).")
			} else {
				if err := system.StartService(system.ProxyServiceName); err == nil {
					components.PrintSuccess("Serviço proxy iniciado com sucesso (ONLINE).")
				} else {
					components.PrintError(fmt.Sprintf("Falha ao iniciar serviço: %v", err))
				}
			}
			components.Pause()

		case "4":
			if !system.IsServiceActive(system.ProxyServiceName) {
				components.PrintInfo("O serviço do proxy já está parado (OFFLINE).")
			} else {
				if err := system.StopService(system.ProxyServiceName); err == nil {
					components.PrintSuccess("Serviço proxy parado com sucesso (OFFLINE).")
				} else {
					components.PrintError(fmt.Sprintf("Falha ao parar serviço: %v", err))
				}
			}
			components.Pause()

		case "5":
			if err := system.RestartService(system.ProxyServiceName); err == nil {
				components.PrintSuccess("Serviço proxy reiniciado com sucesso!")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao reiniciar: %v", err))
			}
			components.Pause()

		case "6":
			ShowAdvancedMenu(cfgMgr)

		case "7":
			currentResp := cfg.Response
			newResp := components.Prompt("Nova resposta HTTP global", currentResp)
			if newResp != "" && newResp != currentResp {
				cfg.Response = newResp
				if err := cfgMgr.Save(cfg); err == nil {
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess(fmt.Sprintf("Resposta HTTP atualizada para '%s'.", newResp))
				}
				components.Pause()
			}

		case "8":
			showPortDetails(cfgMgr)

		case "9":
			handleRealtimeJournalLogs()

		case "l":
			showProxyLogFileMenu(cfgMgr)

		case "0":
			return

		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func removePortInteractive(cfgMgr *config.Manager) {
	cfg, err := cfgMgr.Get()
	if err != nil || len(cfg.Ports) == 0 {
		components.PrintInfo("Nenhuma porta configurada no momento.")
		components.Pause()
		return
	}

	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader("REMOVER PORTA DO PROXY", theme.Cyan, w)

	for i, p := range cfg.Ports {
		mode := "HTTP"
		if strings.HasSuffix(p, ":ssl") {
			mode = "HTTPS/SSL"
		}
		components.PrintBoxLine(fmt.Sprintf("%s%d • Porta %s%s %s(%s)%s", theme.White, i+1, theme.Cyan, p, theme.DarkGray, mode, theme.Reset), w)
	}

	components.PrintBoxDivider(w)
	components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
	components.PrintBoxFooter(w)

	choice := components.Prompt(fmt.Sprintf("Digite o número da porta para remover [1-%d] ou '0' para cancelar", len(cfg.Ports)), "")
	if choice == "" || choice == "0" {
		return
	}

	var targetPort string
	var idx int
	if _, err := fmt.Sscanf(choice, "%d", &idx); err == nil && idx > 0 && idx <= len(cfg.Ports) {
		targetPort = cfg.Ports[idx-1]
	} else {
		targetPort = choice
	}

	if err := cfgMgr.RemovePort(targetPort); err == nil {
		_ = system.RestartService(system.ProxyServiceName)
		components.PrintSuccess(fmt.Sprintf("Porta %s removida e proxy reiniciado.", targetPort))
	} else {
		components.PrintError(fmt.Sprintf("Erro ao remover porta: %v", err))
	}
	components.Pause()
}

func showPortDetails(cfgMgr *config.Manager) {
	cfg, _ := cfgMgr.Get()
	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader("DETALHES E STATUS DAS PORTAS", theme.Cyan, w)

	if len(cfg.Ports) == 0 {
		components.PrintBoxLine(fmt.Sprintf("%sNenhuma porta configurada.%s", theme.DarkGray, theme.Reset), w)
	} else {
		for _, p := range cfg.Ports {
			mode := "HTTP Normal"
			if strings.HasSuffix(p, ":ssl") {
				mode = "HTTPS / TLS (SSL)"
			}
			components.PrintBoxLine(fmt.Sprintf("Porta %s%s%s: %s | Status: %s", theme.Cyan, p, theme.Reset, mode, theme.BadgeOnline), w)
		}
	}

	components.PrintBoxDivider(w)
	components.PrintBoxLine(fmt.Sprintf("Resposta HTTP: %s%s%s", theme.Cyan, cfg.Response, theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("Buffer Size: %s%d bytes%s", theme.Cyan, cfg.BufferSize, theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("SSH Nativo: %s%v%s", theme.Cyan, cfg.SSH.Internal, theme.Reset), w)
	if cfg.SSH.Internal {
		limBadge := theme.Red + "false" + theme.Reset
		if cfg.Limits.Enable {
			limBadge = theme.Green + "true" + theme.Reset
		}
		components.PrintBoxLine(fmt.Sprintf("Limiter: %s", limBadge), w)
	}
	components.PrintBoxLine(fmt.Sprintf("BTUN Nativo: %s%v%s", theme.Cyan, cfg.BTUN.Enable, theme.Reset), w)

	components.PrintBoxFooter(w)
	components.Pause()
}

func handleRealtimeJournalLogs() {
	components.ClearScreen()
	fmt.Printf("%s--- LOGS DO SERVIÇO EM TEMPO REAL (%s via Journalctl) ---%s\n", theme.Cyan, system.ProxyServiceName, theme.Reset)
	fmt.Printf("%sPressione [Ctrl+C] a qualquer momento para pausar e retornar ao menu.%s\n\n", theme.Yellow, theme.Reset)

	if err := system.StreamServiceJournalLogs(system.ProxyServiceName, 50); err != nil {
		components.PrintError(fmt.Sprintf("Falha ao acompanhar logs: %v", err))
		// Fallback para exibição estática caso journalctl em stream não funcione
		if logs, errStatic := system.GetServiceLogs(system.ProxyServiceName, 50); errStatic == nil && strings.TrimSpace(logs) != "" {
			fmt.Printf("\n%s--- ÚLTIMAS LINHAS DO JOURNALCTL ---%s\n%s\n", theme.Cyan, theme.Reset, logs)
		}
		components.Pause()
	} else {
		fmt.Printf("\n%sℹ Acompanhamento de logs encerrado.%s\n", theme.Cyan, theme.Reset)
		time.Sleep(1 * time.Second)
	}
}

func showProxyLogFileMenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		logPath := cfg.LogFile
		if logPath == "" {
			logPath = "/var/log/proxy/proxy.log"
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("MÉTRICAS & REGISTROS (LOG_FILE)", theme.Cyan, w)

		exists, sizeBytes, _ := system.GetLogFileInfo(logPath)
		statusStr := theme.Green + "Ativo" + theme.Reset
		sizeStr := system.FormatBytes(sizeBytes)
		if !exists {
			statusStr = theme.Yellow + "Não criado ainda" + theme.Reset
			sizeStr = "0 B"
		}

		components.PrintBoxLine(fmt.Sprintf("%s• Arquivo: %s%s%s", theme.White, theme.Cyan, logPath, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Tamanho: %s%s │ Status: %s", theme.White, theme.Cyan, sizeStr, statusStr), w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Visualizar últimas 60 linhas de métricas%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Acompanhar métricas em tempo real (tail -f)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Limpar / zerar arquivo de log%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Alterar caminho do arquivo (log_file)%s", theme.White, theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption(i18n.T("prompt_select_option") + " [0-4]")
		switch choice {
		case "1":
			components.ClearScreen()
			if !exists {
				components.PrintWarning(fmt.Sprintf("O arquivo '%s' ainda não foi gerado pelo proxy.", logPath))
				components.PrintInfo("Ele será criado automaticamente assim que o serviço registrar conexões e métricas.")
			} else {
				content, err := system.ReadFileTail(logPath, 60)
				if err != nil {
					components.PrintError(fmt.Sprintf("Erro ao ler arquivo: %v", err))
				} else if strings.TrimSpace(content) == "" {
					components.PrintInfo(fmt.Sprintf("O arquivo '%s' está vazio no momento.", logPath))
				} else {
					fmt.Printf("%s--- ÚLTIMAS LINHAS DE %s ---%s\n\n", theme.Cyan, logPath, theme.Reset)
					fmt.Println(content)
				}
			}
			components.Pause()

		case "2":
			components.ClearScreen()
			if !exists {
				components.PrintWarning(fmt.Sprintf("O arquivo '%s' ainda não existe para acompanhamento.", logPath))
				components.Pause()
			} else {
				fmt.Printf("%s--- ACOMPANHAMENTO AO VIVO (%s) ---%s\n", theme.Cyan, logPath, theme.Reset)
				fmt.Printf("%sPressione [Ctrl+C] a qualquer momento para pausar e retornar ao menu.%s\n\n", theme.Yellow, theme.Reset)
				if err := system.StreamFileTail(logPath, 50); err != nil {
					components.PrintError(fmt.Sprintf("Erro ao acompanhar arquivo: %v", err))
					components.Pause()
				} else {
					fmt.Printf("\n%sℹ Acompanhamento finalizado.%s\n", theme.Cyan, theme.Reset)
					time.Sleep(1 * time.Second)
				}
			}

		case "3":
			if !exists {
				components.PrintInfo("O arquivo de log não existe no momento.")
			} else {
				if components.Confirm("Deseja realmente limpar/zerar o arquivo de log?", false) {
					if err := system.ClearLogFile(logPath); err == nil {
						components.PrintSuccess("Arquivo de log limpo com sucesso!")
					} else {
						components.PrintError(fmt.Sprintf("Erro ao limpar arquivo: %v", err))
					}
				}
			}
			components.Pause()

		case "4":
			newPath := components.Prompt("Novo caminho para log_file", logPath)
			if newPath != "" && newPath != logPath {
				cfg.LogFile = newPath
				if err := cfgMgr.Save(cfg); err == nil {
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess(fmt.Sprintf("Caminho do log_file atualizado para '%s' e proxy reiniciado.", newPath))
				} else {
					components.PrintError(fmt.Sprintf("Erro ao salvar configuração: %v", err))
				}
				components.Pause()
			}

		case "0", "":
			return
		}
	}
}


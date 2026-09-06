package menus

import (
	"fmt"
	"os"
	"strings"
	"time"

	"golang.org/x/term"

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
				entry, errParse := config.ParsePortEntry(portInput)
				if errParse != nil {
					components.PrintError(fmt.Sprintf("Porta inválida: %v", errParse))
					components.Pause()
					break
				}

				avail, procInfo := system.CheckTCPPortAvailable(entry.Port)
				if !avail {
					components.PrintWarning(fmt.Sprintf("Atenção: A porta TCP %d já está em uso por '%s'.", entry.Port, procInfo))
					components.PrintInfo("Adicionar uma porta ocupada pode impedir o serviço proxy de iniciar.")
					if !components.Confirm("Deseja adicionar a porta mesmo assim?", false) {
						break
					}
				}

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
				conflicts := system.CheckConfiguredPortsConflict(cfg.Ports, cfg.SSH.InternalPort, cfg.DNSTT.Enable, cfg.DNSTT.UDP)
				if len(conflicts) > 0 {
					components.PrintWarning("Atenção: Conflito de portas detectado antes da inicialização:")
					for _, c := range conflicts {
						fmt.Printf("  • %s\n", c)
					}
					fmt.Println()
					if !components.Confirm("Deseja tentar iniciar o serviço proxy mesmo com portas ocupadas?", false) {
						components.Pause()
						break
					}
				}

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
			if !system.IsServiceActive(system.ProxyServiceName) {
				conflicts := system.CheckConfiguredPortsConflict(cfg.Ports, cfg.SSH.InternalPort, cfg.DNSTT.Enable, cfg.DNSTT.UDP)
				if len(conflicts) > 0 {
					components.PrintWarning("Atenção: Conflito de portas detectado antes da inicialização:")
					for _, c := range conflicts {
						fmt.Printf("  • %s\n", c)
					}
					fmt.Println()
					if !components.Confirm("Deseja tentar reiniciar o serviço proxy mesmo com portas ocupadas?", false) {
						components.Pause()
						break
					}
				}
			}
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
			showLiveProxyMetricsBanner(cfgMgr)

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

// showLiveProxyMetricsBanner exibe diretamente o banner do log_file com atualização dinâmica em tempo real
func showLiveProxyMetricsBanner(cfgMgr *config.Manager) {
	cfg, _ := cfgMgr.Get()
	logPath := cfg.LogFile
	if logPath == "" {
		logPath = "/var/log/proxy/proxy.log"
	}

	fd := int(os.Stdin.Fd())
	isTTY := term.IsTerminal(fd)

	var oldState *term.State
	if isTTY {
		var err error
		oldState, err = term.MakeRaw(fd)
		if err == nil {
			defer func() {
				_ = term.Restore(fd, oldState)
				fmt.Print("\033[?25h") // Garante restauração da visibilidade do cursor
			}()
		}
	}

	exitChan := make(chan struct{})

	// Goroutine que escuta qualquer tecla de saída imediata
	go func() {
		var b [1]byte
		for {
			n, err := os.Stdin.Read(b[:])
			if err != nil || n == 0 {
				break
			}
			ch := b[0]
			// Enter (\r, \n), Q/q, Ctrl+C (3), Esc (27), Espaço
			if ch == '\r' || ch == '\n' || ch == 'q' || ch == 'Q' || ch == 3 || ch == 27 || ch == ' ' {
				break
			}
		}
		close(exitChan)
	}()

	components.ClearScreen()
	renderLiveBannerFrame(logPath, isTTY)

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-exitChan:
			components.ClearScreen()
			return
		case <-ticker.C:
			renderLiveBannerFrame(logPath, isTTY)
		}
	}
}

func renderLiveBannerFrame(logPath string, isTTY bool) {
	w := components.GetBoxWidth()
	isProxyActive := system.IsServiceActive(system.ProxyServiceName)

	statusBadge := theme.BadgeOnline
	if !isProxyActive {
		statusBadge = theme.BadgeOffline
	}

	var buf strings.Builder
	buf.WriteString("\033[H\033[?25l") // Cursor Home e oculta o cursor durante render

	buf.WriteString(components.FormatBoxHeader("VELTRIX PROXY • MÉTRICAS EM TEMPO REAL", theme.Cyan, w))
	buf.WriteString("\n")

	infoLine := fmt.Sprintf("Arquivo: %s%s%s │ Status: %s", theme.Cyan, logPath, theme.Reset, statusBadge)
	buf.WriteString(components.FormatBoxLine(infoLine, w))
	buf.WriteString("\n")

	exitLine := fmt.Sprintf("Pressione %s[Enter]%s ou %s[Q]%s para retornar ao menu", theme.Yellow, theme.Reset, theme.Yellow, theme.Reset)
	buf.WriteString(components.FormatBoxLine(exitLine, w))
	buf.WriteString("\n")

	buf.WriteString(components.FormatBoxFooter(w))
	buf.WriteString("\n\n")

	banner := getLatestProxyBanner(logPath)
	if banner == "" {
		if !isProxyActive {
			buf.WriteString(fmt.Sprintf("%sℹ O serviço do proxy está OFFLINE. Inicie o proxy para ativar as métricas ao vivo.%s\n", theme.Yellow, theme.Reset))
		} else {
			buf.WriteString(fmt.Sprintf("%sℹ Aguardando o proxy registrar as primeiras métricas em '%s'...%s\n", theme.Cyan, logPath, theme.Reset))
		}
	} else {
		buf.WriteString(banner)
		buf.WriteString("\n")
	}

	// Limpa quaisquer linhas remanescentes abaixo do conteúdo renderizado
	buf.WriteString("\033[J")

	out := buf.String()
	if isTTY {
		// Em modo Raw do terminal, quebras de linha precisam ser CRLF (\r\n) para evitar efeito escada
		out = strings.ReplaceAll(out, "\r\n", "\n")
		out = strings.ReplaceAll(out, "\n", "\r\n")
	}

	_, _ = os.Stdout.WriteString(out)
}

func getLatestProxyBanner(logPath string) string {
	data, err := os.ReadFile(logPath)
	if err != nil || len(data) == 0 {
		return ""
	}

	raw := string(data)
	lines := strings.Split(raw, "\n")

	// Se o arquivo contiver múltiplos banners acumulados (modo append)
	if len(lines) > 25 {
		lastBannerIdx := -1
		for i := len(lines) - 1; i >= 0; i-- {
			line := lines[i]
			if strings.Contains(line, "v2.") || strings.Contains(line, "\\ \\ /") || strings.Contains(line, "RAM:") {
				lastBannerIdx = i
				if lastBannerIdx > 0 && strings.TrimSpace(lines[lastBannerIdx-1]) != "" {
					lastBannerIdx--
				}
				break
			}
		}
		if lastBannerIdx >= 0 {
			lines = lines[lastBannerIdx:]
		} else {
			lines = lines[len(lines)-18:]
		}
	}

	return strings.TrimRight(strings.Join(lines, "\n"), "\r\n ")
}


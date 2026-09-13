package menus

import (
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	"golang.org/x/term"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// cursorControlANSI remove escapes de cursor/tela que quebram o redraw ao vivo.
var cursorControlANSI = regexp.MustCompile(`\x1b\[[0-9;]*[HJKfABCDsu]|\x1b\[[?0-9;]*[hl]|\x1b\[2J|\x1b\[3J`)

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
		if cfg.DNSTT.Enable {
			dnsttPort := cfg.DNSTT.UDP
			if dnsttPort == "" {
				dnsttPort = ":53"
			}
			activePortsStr += fmt.Sprintf(" │ DNSTT: %s%s%s", theme.Green, dnsttPort, theme.Reset)
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

		dnsttBadge := theme.Red + "[INATIVO]" + theme.Reset
		if cfg.DNSTT.Enable {
			dnsttBadge = theme.Green + "[ATIVO]" + theme.Reset
		}
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s (%s)%s", theme.White, i18n.T("adv_opt_dnstt"), dnsttBadge, theme.Reset), w)

		components.PrintBoxDivider(w)

		// Controle do Serviço
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s%s", theme.White, i18n.T("proxy_opt_start"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s%s", theme.White, i18n.T("proxy_opt_stop"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s%s", theme.White, i18n.T("proxy_opt_restart"), theme.Reset), w)

		components.PrintBoxDivider(w)

		// Configurações & Diagnóstico
		components.PrintBoxLine(fmt.Sprintf("%s7 • %s%s", theme.White, i18n.T("proxy_opt_adv"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s8 • %s%s", theme.White, i18n.T("proxy_opt_http"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s9 • %s%s", theme.White, i18n.T("proxy_opt_details"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%sJ • %s%s", theme.White, i18n.T("proxy_opt_journal_logs"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%sL • %s%s", theme.White, i18n.T("proxy_opt_file_logs"), theme.Reset), w)

		components.PrintBoxDivider(w)
		backLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("proxy_opt_back"), theme.Reset)
		components.PrintBoxLine(backLine, w)
		components.PrintBoxFooter(w)

		choice := strings.ToLower(components.ReadOption(i18n.T("prompt_select_option") + " [0-9/J/L]"))
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

				inUse, procInfo := system.IsPortInUseByOther("tcp", entry.Port)
				if inUse {
					components.PrintWarning(fmt.Sprintf("Atenção: A porta TCP %d já está em uso por '%s'.", entry.Port, procInfo))
					components.PrintInfo("Adicionar uma porta ocupada por outro serviço pode impedir o serviço proxy de iniciar.")
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

		case "3", "d":
			ShowDNSTTMenu(cfgMgr)

		case "4":
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

		case "5":
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

		case "6":
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

		case "7":
			ShowAdvancedMenu(cfgMgr)

		case "8":
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

		case "9":
			showPortDetails(cfgMgr)

		case "j", "10":
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
	dnsttStatus := theme.Red + "false" + theme.Reset
	if cfg.DNSTT.Enable {
		dnsttPort := cfg.DNSTT.UDP
		if dnsttPort == "" {
			dnsttPort = ":53"
		}
		dnsttStatus = theme.Green + "true" + theme.Reset + fmt.Sprintf(" (%s)", dnsttPort)
	}
	components.PrintBoxLine(fmt.Sprintf("DNSTT Nativo: %s", dnsttStatus), w)
	ztunStatus := theme.Red + "false" + theme.Reset
	if cfg.Ztun.Enable {
		ztunStatus = theme.Green + "true" + theme.Reset
		if strings.TrimSpace(cfg.Ztun.Upstream) != "" {
			ztunStatus += fmt.Sprintf(" (passthrough %s)", cfg.Ztun.Upstream)
		}
	} else if strings.TrimSpace(cfg.Ztun.Upstream) != "" {
		ztunStatus = theme.Yellow + "passthrough" + theme.Reset + fmt.Sprintf(" (%s)", cfg.Ztun.Upstream)
	}
	components.PrintBoxLine(fmt.Sprintf("Ztun Binary: %s", ztunStatus), w)

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
			}()
		}
	}

	// Buffer alternativo + sem autowrap: evita bordas no scrollback e wrap fantasma em painéis estreitos.
	_, _ = os.Stdout.WriteString("\033[?1049h\033[?7l\033[?25l")
	defer func() {
		_, _ = os.Stdout.WriteString("\033[?25h\033[?7h\033[?1049l")
	}()

	exitChan := make(chan struct{})

	go func() {
		var b [1]byte
		for {
			n, err := os.Stdin.Read(b[:])
			if err != nil || n == 0 {
				break
			}
			ch := b[0]
			if ch == '\r' || ch == '\n' || ch == 'q' || ch == 'Q' || ch == 3 || ch == 27 || ch == ' ' {
				break
			}
		}
		close(exitChan)
	}()

	renderLiveBannerFrame(logPath, isTTY)

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-exitChan:
			return
		case <-ticker.C:
			renderLiveBannerFrame(logPath, isTTY)
		}
	}
}

func renderLiveBannerFrame(logPath string, isTTY bool) {
	termW, termH := liveTerminalSize()
	maxCols := termW - 1
	if maxCols < 20 {
		maxCols = termW
	}
	if maxCols < 16 {
		maxCols = 16
	}

	isProxyActive := system.IsServiceActive(system.ProxyServiceName)
	statusBadge := theme.BadgeOnline
	if !isProxyActive {
		statusBadge = theme.BadgeOffline
	}

	title := "VELTRIX PROXY • MÉTRICAS EM TEMPO REAL"
	if maxCols < 42 {
		title = "MÉTRICAS AO VIVO"
	} else if maxCols < 56 {
		title = "VELTRIX • MÉTRICAS AO VIVO"
	}

	lines := make([]string, 0, 24)
	lines = append(lines, theme.Bold+theme.Cyan+title+theme.Reset)
	lines = append(lines, fmt.Sprintf("Arquivo: %s%s%s  Status: %s", theme.Cyan, logPath, theme.Reset, statusBadge))
	lines = append(lines, fmt.Sprintf("Pressione %s[Enter]%s ou %s[Q]%s para retornar", theme.Yellow, theme.Reset, theme.Yellow, theme.Reset))
	lines = append(lines, "")

	banner := getLatestProxyBanner(logPath)
	if banner == "" {
		if !isProxyActive {
			lines = append(lines, theme.Yellow+"ℹ Proxy OFFLINE — inicie o serviço."+theme.Reset)
		} else {
			lines = append(lines, fmt.Sprintf("%sℹ Aguardando métricas em '%s'...%s", theme.Cyan, logPath, theme.Reset))
		}
	} else {
		for _, bl := range strings.Split(sanitizeLiveBanner(banner, maxCols), "\n") {
			lines = append(lines, bl)
		}
	}

	// Limita à altura do terminal para não rolar o buffer alternativo
	maxRows := termH - 1
	if maxRows < 8 {
		maxRows = 8
	}
	if len(lines) > maxRows {
		lines = lines[:maxRows]
	}

	writeLiveFrame(lines, maxCols, isTTY)
}

func liveTerminalSize() (cols, rows int) {
	cols = components.GetTerminalWidth()
	rows = 24
	fd := int(os.Stdout.Fd())
	if term.IsTerminal(fd) {
		if w, h, err := term.GetSize(fd); err == nil {
			if w > 0 {
				cols = w
			}
			if h > 0 {
				rows = h
			}
		}
	}
	if cols <= 0 {
		cols = 80
	}
	if rows <= 0 {
		rows = 24
	}
	return cols, rows
}

// writeLiveFrame redesenha o viewport inteiro linha a linha (clear + 2K por linha).
func writeLiveFrame(lines []string, maxCols int, isTTY bool) {
	var buf strings.Builder
	// Home + limpa viewport + limpa scrollback do buffer alternativo
	buf.WriteString("\033[H\033[2J\033[3J")

	nl := "\n"
	if isTTY {
		nl = "\r\n"
	}

	for _, line := range lines {
		line = cursorControlANSI.ReplaceAllString(line, "")
		line = strings.ReplaceAll(line, "\r", "")
		line = strings.ReplaceAll(line, "\n", " ")
		if theme.VisibleLen(line) > maxCols {
			line = theme.TruncateANSI(line, maxCols)
		}
		// Apaga o restante da linha (evita restos se o conteúdo encolher)
		buf.WriteString("\033[2K")
		buf.WriteString(line)
		buf.WriteString(nl)
	}
	buf.WriteString("\033[J")

	_, _ = os.Stdout.WriteString(buf.String())
}

// sanitizeLiveBanner remove sequências ANSI de cursor/clear e evita wrap que gera linhas fantasmas.
func sanitizeLiveBanner(banner string, maxCols int) string {
	banner = cursorControlANSI.ReplaceAllString(banner, "")
	banner = strings.ReplaceAll(banner, "\r", "")

	if maxCols < 1 {
		maxCols = 1
	}

	lines := strings.Split(banner, "\n")
	for i, line := range lines {
		if theme.VisibleLen(line) > maxCols {
			lines[i] = theme.TruncateANSI(line, maxCols)
		}
	}
	return strings.Join(lines, "\n")
}

func getLatestProxyBanner(logPath string) string {
	data, err := os.ReadFile(logPath)
	if err != nil || len(data) == 0 {
		return ""
	}

	raw := cursorControlANSI.ReplaceAllString(string(data), "")
	raw = strings.ReplaceAll(raw, "\r", "")
	lines := strings.Split(raw, "\n")

	// Formato atual: último bloco completo ┌ ... └
	lastBoxTop := -1
	for i := len(lines) - 1; i >= 0; i-- {
		if strings.Contains(lines[i], "┌") {
			lastBoxTop = i
			break
		}
	}
	if lastBoxTop >= 0 {
		end := len(lines)
		for j := lastBoxTop; j < len(lines); j++ {
			if strings.Contains(lines[j], "└") {
				end = j + 1
				break
			}
		}
		return strings.TrimRight(strings.Join(lines[lastBoxTop:end], "\n"), "\n ")
	}

	// Fallback legado (ASCII art / marcadores Versão/ZTUN-X)
	if len(lines) > 25 {
		lastBannerIdx := -1
		for i := len(lines) - 1; i >= 0; i-- {
			line := lines[i]
			if strings.Contains(line, "v2.") || strings.Contains(line, "Versão:") ||
				strings.Contains(line, "\\ \\ /") || strings.Contains(line, "RAM:") ||
				strings.Contains(line, "ZTUN-X") {
				lastBannerIdx = i
				for lastBannerIdx > 0 {
					prev := strings.TrimSpace(lines[lastBannerIdx-1])
					if prev == "" {
						break
					}
					if strings.Contains(prev, "┌") {
						lastBannerIdx--
						break
					}
					lastBannerIdx--
					if i-lastBannerIdx > 20 {
						break
					}
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

	return strings.TrimRight(strings.Join(lines, "\n"), "\n ")
}


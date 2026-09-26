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
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("proxy_menu_title"), theme.Cyan, w)

		activePortsStr := i18n.T("proxy_none")
		if len(cfg.Ports) > 0 {
			activePortsStr = strings.Join(cfg.Ports, ", ")
		}
		statusLine := fmt.Sprintf("%s%s:%s %s %s│ %s:%s %s%s%s",
			theme.Gray, i18n.T("proxy_status"), theme.Reset, serviceBadge(system.IsServiceActive(system.ProxyServiceName)),
			theme.DarkGray, i18n.T("proxy_ports"), theme.Reset, theme.Cyan, activePortsStr, theme.Reset,
		)
		components.PrintBoxLine(statusLine, w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(menuItem("1", i18n.T("proxy_opt_add"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("proxy_opt_remove"), ""), w)
		components.PrintBoxLine(menuItem("3", i18n.T("proxy_opt_details"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("4", i18n.T("proxy_opt_start"), ""), w)
		components.PrintBoxLine(menuItem("5", i18n.T("proxy_opt_stop"), ""), w)
		components.PrintBoxLine(menuItem("6", i18n.T("proxy_opt_restart"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("7", i18n.T("proxy_opt_journal_logs"), ""), w)
		components.PrintBoxLine(menuItem("8", i18n.T("proxy_opt_file_logs"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-8") {
		case "1":
			addPortInteractive(cfgMgr)
		case "2":
			removePortInteractive(cfgMgr)
		case "3":
			showPortDetails(cfgMgr)
		case "4":
			if system.IsServiceActive(system.ProxyServiceName) {
				components.PrintInfo(i18n.T("proxy_already_running"))
			} else if confirmPortConflicts(cfg, "proxy_confirm_start_conflict") {
				if err := system.StartService(system.ProxyServiceName); err == nil {
					components.PrintSuccess(i18n.T("proxy_started"))
				} else {
					components.PrintError(i18n.T("proxy_start_failed", err))
				}
			}
			components.Pause()
		case "5":
			if !system.IsServiceActive(system.ProxyServiceName) {
				components.PrintInfo(i18n.T("proxy_already_stopped"))
			} else if err := system.StopService(system.ProxyServiceName); err == nil {
				components.PrintSuccess(i18n.T("proxy_stopped"))
			} else {
				components.PrintError(i18n.T("proxy_stop_failed", err))
			}
			components.Pause()
		case "6":
			if system.IsServiceActive(system.ProxyServiceName) || confirmPortConflicts(cfg, "proxy_confirm_restart_conflict") {
				if err := system.RestartService(system.ProxyServiceName); err == nil {
					components.PrintSuccess(i18n.T("proxy_restarted"))
				} else {
					components.PrintError(i18n.T("proxy_restart_failed", err))
				}
			}
			components.Pause()
		case "7", "j":
			handleRealtimeJournalLogs()
		case "8", "l":
			showLiveProxyMetricsBanner(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

// confirmPortConflicts lists busy ports before (re)starting and asks to go on.
func confirmPortConflicts(cfg *config.Config, confirmKey string) bool {
	conflicts := system.CheckConfiguredPortsConflict(cfg.Ports, cfg.SSH.InternalPort, cfg.DNSTT.Enable, cfg.DNSTT.UDP)
	if len(conflicts) == 0 {
		return true
	}
	components.PrintWarning(i18n.T("proxy_conflicts"))
	for _, c := range conflicts {
		fmt.Printf("  • %s\n", c)
	}
	return components.Confirm(i18n.T(confirmKey), false)
}

func addPortInteractive(cfgMgr *config.Manager) {
	portInput := strings.TrimSpace(components.Prompt(i18n.T("proxy_prompt_add_port"), ""))
	if portInput == "" {
		return
	}
	entry, err := config.ParsePortEntry(portInput)
	if err != nil {
		components.PrintError(i18n.T("proxy_invalid_port", err))
		components.Pause()
		return
	}
	if inUse, procInfo := system.IsPortInUseByOther("tcp", entry.Port); inUse {
		components.PrintWarning(i18n.T("port_in_use_tcp", entry.Port, procInfo))
		components.PrintInfo(i18n.T("proxy_port_busy_hint"))
		if !components.Confirm(i18n.T("confirm_apply_anyway"), false) {
			return
		}
	}
	if err := cfgMgr.AddPort(portInput); err != nil {
		components.PrintError(i18n.T("proxy_port_add_failed", err))
	} else {
		_ = system.RestartService(system.ProxyServiceName)
		components.PrintSuccess(i18n.T("proxy_port_added", portInput))
	}
	components.Pause()
}

func removePortInteractive(cfgMgr *config.Manager) {
	cfg, err := cfgMgr.Get()
	if err != nil || len(cfg.Ports) == 0 {
		components.PrintInfo(i18n.T("proxy_no_ports"))
		components.Pause()
		return
	}

	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("proxy_remove_title"), theme.Cyan, w)

	for i, p := range cfg.Ports {
		mode := "HTTP"
		if strings.HasSuffix(p, ":ssl") {
			mode = "HTTPS/SSL"
		}
		components.PrintBoxLine(fmt.Sprintf("%s%d • %s %s%s %s(%s)%s", theme.White, i+1, i18n.T("proxy_port_label"), theme.Cyan, p, theme.DarkGray, mode, theme.Reset), w)
	}
	printMenuBack(w)

	choice := components.Prompt(i18n.T("proxy_remove_prompt", len(cfg.Ports)), "")
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
		components.PrintSuccess(i18n.T("proxy_port_removed", targetPort))
	} else {
		components.PrintError(i18n.T("proxy_port_remove_failed", err))
	}
	components.Pause()
}

func showPortDetails(cfgMgr *config.Manager) {
	cfg, _ := cfgMgr.Get()
	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("proxy_details_title"), theme.Cyan, w)

	if len(cfg.Ports) == 0 {
		components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.DarkGray, i18n.T("proxy_no_ports"), theme.Reset), w)
	} else {
		for _, p := range cfg.Ports {
			mode := "HTTP"
			if strings.HasSuffix(p, ":ssl") {
				mode = "HTTPS / TLS (SSL)"
			}
			components.PrintBoxLine(fmt.Sprintf("%s %s%s%s: %s", i18n.T("proxy_port_label"), theme.Cyan, p, theme.Reset, mode), w)
		}
	}

	detail := func(label, value string) {
		components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s", theme.Gray, label, theme.Reset, value), w)
	}
	withExtra := func(on bool, extra string) string {
		if on && extra != "" {
			return featureBadge(true) + " " + valueBadge(extra)
		}
		return featureBadge(on)
	}

	components.PrintBoxDivider(w)
	detail(i18n.T("details_http_response"), valueBadge(cfg.Response))
	detail("Buffer", valueBadge(fmt.Sprintf("%d bytes", cfg.BufferSize)))
	detail(i18n.T("details_ssh_native"), featureBadge(cfg.SSH.Internal))
	if cfg.SSH.Internal {
		detail("Limiter", featureBadge(cfg.Limits.Enable))
	}
	detail("BTUN", featureBadge(cfg.BTUN.Enable))
	dnsttPort := cfg.DNSTT.UDP
	if dnsttPort == "" {
		dnsttPort = ":53"
	}
	detail("DNSTT", withExtra(cfg.DNSTT.Enable, dnsttPort))
	ztunStatus := withExtra(cfg.Ztun.Enable, strings.TrimSpace(cfg.Ztun.Upstream))
	if !cfg.Ztun.Enable && strings.TrimSpace(cfg.Ztun.Upstream) != "" {
		ztunStatus = theme.Yellow + "passthrough" + theme.Reset + " " + valueBadge(cfg.Ztun.Upstream)
	}
	detail("Ztun", ztunStatus)
	detail("HCR", withExtra(cfg.HCR.Enable, cfg.HCR.Transport))
	xrayExtra := cfg.Xray.Path
	if cfg.Xray.Legacy.Enable {
		xrayExtra += " +legacy"
	}
	detail("Xray", withExtra(cfg.Xray.Enable, xrayExtra))

	components.PrintBoxFooter(w)
	components.Pause()
}

func handleRealtimeJournalLogs() {
	components.ClearScreen()
	fmt.Printf("%s--- %s ---%s\n", theme.Cyan, i18n.T("journal_title", system.ProxyServiceName), theme.Reset)
	fmt.Printf("%s%s%s\n\n", theme.Yellow, i18n.T("journal_hint"), theme.Reset)

	if err := system.StreamServiceJournalLogs(system.ProxyServiceName, 50); err != nil {
		components.PrintError(i18n.T("journal_failed", err))
		// Fallback para exibição estática caso journalctl em stream não funcione
		if logs, errStatic := system.GetServiceLogs(system.ProxyServiceName, 50); errStatic == nil && strings.TrimSpace(logs) != "" {
			fmt.Printf("\n%s--- %s ---%s\n%s\n", theme.Cyan, i18n.T("journal_last_lines"), theme.Reset, logs)
		}
		components.Pause()
	} else {
		fmt.Printf("\n%sℹ %s%s\n", theme.Cyan, i18n.T("journal_ended"), theme.Reset)
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

	// Caixa do chrome alinhada ao banner do proxy (62) e limitada ao terminal.
	boxW := components.DefaultBoxWidth
	if boxW > maxCols {
		boxW = maxCols
	}
	if boxW < 16 {
		boxW = maxCols
	}

	isProxyActive := system.IsServiceActive(system.ProxyServiceName)
	statusBadge := theme.BadgeOnline
	if !isProxyActive {
		statusBadge = theme.BadgeOffline
	}

	title := i18n.T("live_title_long")
	if boxW < 42 {
		title = i18n.T("live_title_short")
	} else if boxW < 56 {
		title = i18n.T("live_title_mid")
	}

	lines := make([]string, 0, 28)
	for _, hl := range strings.Split(components.FormatBoxHeader(title, theme.Cyan, boxW), "\n") {
		if hl != "" {
			lines = append(lines, hl)
		}
	}

	fileStatus := fmt.Sprintf("%s: %s%s%s", i18n.T("live_file"), theme.Cyan, logPath, theme.Reset)
	statusPart := fmt.Sprintf("%s: %s", i18n.T("proxy_status"), statusBadge)
	if theme.VisibleLen(fileStatus)+2+theme.VisibleLen(statusPart) <= boxW-4 {
		lines = append(lines, components.FormatBoxLine(fileStatus+"  "+statusPart, boxW))
	} else {
		lines = append(lines, components.FormatBoxLine(fileStatus, boxW))
		lines = append(lines, components.FormatBoxLine(statusPart, boxW))
	}

	hint := i18n.T("live_hint", theme.Yellow+"[Enter]"+theme.Reset, theme.Yellow+"[Q]"+theme.Reset)
	lines = append(lines, components.FormatBoxCenterLine(hint, boxW))
	lines = append(lines, components.FormatBoxFooter(boxW))
	lines = append(lines, "")

	banner := getLatestProxyBanner(logPath)
	if banner == "" {
		if !isProxyActive {
			lines = append(lines, theme.Yellow+"ℹ "+i18n.T("live_offline")+theme.Reset)
		} else {
			lines = append(lines, fmt.Sprintf("%sℹ %s%s", theme.Cyan, i18n.T("live_waiting", logPath), theme.Reset))
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
				strings.Contains(line, "ZTUN-X") || strings.Contains(line, "HCR") ||
				strings.Contains(line, "DNSTT") {
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

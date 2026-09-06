package components

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"golang.org/x/term"

	"github.com/TelksBr/VeltrixProxy/internal/proxy"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/udpgw"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

const (
	DefaultBoxWidth = 62
	MinBoxWidth     = 36
	MaxBoxWidth     = 74
)

// ClearScreen limpa o terminal de forma confiável em qualquer sistema operacional e emulador (Linux, WSL, Windows, SSH)
func ClearScreen() {
	if runtime.GOOS == "windows" {
		cmd := exec.Command("cmd", "/c", "cls")
		cmd.Stdout = os.Stdout
		_ = cmd.Run()
	} else {
		cmd := exec.Command("clear")
		cmd.Stdout = os.Stdout
		_ = cmd.Run()
	}
	// Envia também sequência ANSI completa com limpeza de scrollback
	// \033[H: Cursor Home (linha 1, coluna 1)
	// \033[2J: Limpa todo o viewport da tela
	// \033[3J: Limpa todo o buffer de rolagem (scrollback) no Windows Terminal, ConPTY e xterm
	fmt.Print("\033[H\033[2J\033[3J")
}

// GetTerminalWidth detecta dinamicamente a largura em colunas do terminal
func GetTerminalWidth() int {
	fd := int(os.Stdout.Fd())
	if term.IsTerminal(fd) {
		if w, _, err := term.GetSize(fd); err == nil && w > 0 {
			return w
		}
	}
	inFd := int(os.Stdin.Fd())
	if term.IsTerminal(inFd) {
		if w, _, err := term.GetSize(inFd); err == nil && w > 0 {
			return w
		}
	}
	if colsStr := os.Getenv("COLUMNS"); colsStr != "" {
		if cols, err := strconv.Atoi(colsStr); err == nil && cols > 0 {
			return cols
		}
	}
	return DefaultBoxWidth
}

// GetBoxWidth calcula a largura ideal e responsiva para a caixa do menu
func GetBoxWidth() int {
	tw := GetTerminalWidth()
	if tw <= 0 {
		return DefaultBoxWidth
	}
	// Em telas estreitas (ex: mobile, split terminal, janelas reduzidas),
	// ajusta a caixa para caber na tela sem estourar margens
	if tw <= 66 {
		w := tw - 2
		if w < MinBoxWidth {
			w = MinBoxWidth
		}
		return w
	}
	// Em telas médias/padrão (67 a 78 colunas)
	if tw < 78 {
		return tw - 4
	}
	// Em telas amplas (>= 78 colunas), mantém uma largura harmônica e confortável
	return DefaultBoxWidth
}

// PrintBoxHeader desenha o topo da caixa com o título centralizado
func PrintBoxHeader(title string, color string, width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}
	if color == "" {
		color = theme.Cyan
	}

	borderCol := theme.DarkGray
	topBorder := strings.Repeat("─", width-2)
	fmt.Printf("%s┌%s┐%s\n", borderCol, topBorder, theme.Reset)

	contentWidth := width - 2
	titleLen := theme.VisibleLen(title)
	if titleLen > contentWidth {
		title = theme.TruncateANSI(title, contentWidth)
		titleLen = theme.VisibleLen(title)
	}

	leftPad := (contentWidth - titleLen) / 2
	if leftPad < 0 {
		leftPad = 0
	}
	rightPad := contentWidth - titleLen - leftPad
	if rightPad < 0 {
		rightPad = 0
	}

	fmt.Printf("%s│%s%s%s%s%s%s│%s\n",
		borderCol,
		strings.Repeat(" ", leftPad),
		theme.Bold+color, title, theme.Reset,
		strings.Repeat(" ", rightPad),
		borderCol, theme.Reset,
	)
	PrintBoxDivider(width)
}

// PrintBoxDivider desenha a linha divisória intermediária ├──────┤
func PrintBoxDivider(width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}
	borderCol := theme.DarkGray
	divider := strings.Repeat("─", width-2)
	fmt.Printf("%s├%s┤%s\n", borderCol, divider, theme.Reset)
}

// FormatBoxLine formata uma linha de conteúdo alinhada com as bordas da caixa
func FormatBoxLine(content string, width int) string {
	if width <= 0 {
		width = GetBoxWidth()
	}
	borderCol := theme.DarkGray
	contentWidth := width - 4
	if contentWidth < 4 {
		contentWidth = 4
	}

	vLen := theme.VisibleLen(content)
	if vLen > contentWidth {
		content = theme.TruncateANSI(content, contentWidth)
		vLen = theme.VisibleLen(content)
	}

	pad := contentWidth - vLen
	if pad < 0 {
		pad = 0
	}

	return fmt.Sprintf("%s│%s %s%s %s│%s",
		borderCol, theme.Reset,
		content,
		strings.Repeat(" ", pad),
		borderCol, theme.Reset,
	)
}

// PrintBoxLine imprime uma linha de conteúdo alinhada com as bordas da caixa
func PrintBoxLine(content string, width int) {
	fmt.Println(FormatBoxLine(content, width))
}

// PrintBoxFooter fecha a caixa └──────┘
func PrintBoxFooter(width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}
	borderCol := theme.DarkGray
	bottomBorder := strings.Repeat("─", width-2)
	fmt.Printf("%s└%s┘%s\n", borderCol, bottomBorder, theme.Reset)
}

// PrintBoxCenterLine imprime uma linha de conteúdo centralizada dentro da caixa
func PrintBoxCenterLine(content string, width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}
	contentWidth := width - 4
	if contentWidth < 4 {
		contentWidth = 4
	}

	vLen := theme.VisibleLen(content)
	if vLen > contentWidth {
		content = theme.TruncateANSI(content, contentWidth)
		vLen = theme.VisibleLen(content)
	}

	leftPad := (contentWidth - vLen) / 2
	if leftPad < 0 {
		leftPad = 0
	}
	rightPad := contentWidth - vLen - leftPad
	if rightPad < 0 {
		rightPad = 0
	}

	borderCol := theme.DarkGray
	fmt.Printf("%s│%s %s%s%s %s│%s\n",
		borderCol, theme.Reset,
		strings.Repeat(" ", leftPad),
		content,
		strings.Repeat(" ", rightPad),
		borderCol, theme.Reset,
	)
}

// PrintMenuCredits imprime a linha de rodapé com créditos e contatos oficiais
func PrintMenuCredits(width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}
	PrintBoxDivider(width)

	contentWidth := width - 4
	var line string
	if contentWidth < 46 {
		line = fmt.Sprintf("%s@telks13 %s│ %s@VeltrixPanelGroup%s",
			theme.Cyan, theme.DarkGray, theme.Cyan, theme.Reset)
	} else {
		line = fmt.Sprintf("%sDev: %s@telks13 %s│ %sTelegram: %s@VeltrixPanelGroup%s",
			theme.DarkGray, theme.Cyan, theme.DarkGray, theme.DarkGray, theme.Cyan, theme.Reset)
	}
	PrintBoxCenterLine(line, width)
	PrintBoxFooter(width)
}

func formatTwoCols(left string, right string, contentWidth int) string {
	sep := " │ "
	sepLen := 3
	avail := contentWidth - sepLen
	if avail < 8 {
		return theme.PadRightANSI(left, contentWidth)
	}

	leftCol := avail / 2
	rightCol := avail - leftCol

	return theme.PadRightANSI(left, leftCol) + theme.DarkGray + sep + theme.Reset + theme.PadRightANSI(right, rightCol)
}

// PrintDashboardHeader exibe as informações de sistema e status da VPS
func PrintDashboardHeader(width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}

	cpuUsage := system.GetCPUUsage()
	ram := system.GetRAMInfo()
	ip := system.GetPublicIP()
	osName := system.GetOSShortName()
	isProxyActive := system.IsServiceActive(system.ProxyServiceName)
	onlines := proxy.GetOnlineUsersTotal()

	PrintBoxHeader("VELTRIX PROXY • DASHBOARD", theme.Cyan, width)

	cpuColor := theme.Green
	if cpuUsage > 75 {
		cpuColor = theme.Red
	} else if cpuUsage > 50 {
		cpuColor = theme.Yellow
	}

	ramColor := theme.Green
	if ram.Percent > 80 {
		ramColor = theme.Red
	} else if ram.Percent > 60 {
		ramColor = theme.Yellow
	}

	proxyStatusBadge := theme.BadgeOffline
	if isProxyActive {
		proxyStatusBadge = theme.BadgeOnline
	}

	isUDPGWActive := udpgw.IsActive()
	udpgwPorts := udpgw.ListConfiguredPorts()
	udpgwStatusBadge := theme.BadgeOffline
	if isUDPGWActive {
		udpgwStatusBadge = theme.BadgeOnline
	}

	var portsLabel string
	if len(udpgwPorts) == 0 {
		portsLabel = "-"
	} else if len(udpgwPorts) == 1 {
		portsLabel = strconv.Itoa(udpgwPorts[0])
	} else if len(udpgwPorts) == 2 {
		portsLabel = fmt.Sprintf("%d, %d", udpgwPorts[0], udpgwPorts[1])
	} else {
		portsLabel = fmt.Sprintf("%d (+%d)", udpgwPorts[0], len(udpgwPorts)-1)
	}

	contentWidth := width - 4
	if contentWidth < 4 {
		contentWidth = 4
	}

	if width >= 54 {
		// Layout de 2 colunas perfeitamente alinhadas
		ipCol := fmt.Sprintf("%sIP:%s %s%s%s", theme.Gray, theme.Reset, theme.White, ip, theme.Reset)
		osCol := fmt.Sprintf("%sSO:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, osName, theme.Reset)
		PrintBoxLine(formatTwoCols(ipCol, osCol, contentWidth), width)

		cpuCol := fmt.Sprintf("%sCPU:%s %s%d%%%s", theme.Gray, theme.Reset, cpuColor, cpuUsage, theme.Reset)
		ramCol := fmt.Sprintf("%sRAM:%s %s%dMB/%dMB (%d%%)%s", theme.Gray, theme.Reset, ramColor, ram.UsedMB, ram.TotalMB, ram.Percent, theme.Reset)
		PrintBoxLine(formatTwoCols(cpuCol, ramCol, contentWidth), width)

		proxyCol := fmt.Sprintf("%sProxy VT:%s %s", theme.Gray, theme.Reset, proxyStatusBadge)
		onlineCol := fmt.Sprintf("%sOnline:%s %s%d con%s", theme.Gray, theme.Reset, theme.Cyan, onlines, theme.Reset)
		PrintBoxLine(formatTwoCols(proxyCol, onlineCol, contentWidth), width)

		avail := contentWidth - 3
		leftCol := avail / 2
		udpgwCol := fmt.Sprintf("%sBadVPN / UDPGW:%s %s", theme.Gray, theme.Reset, udpgwStatusBadge)
		if leftCol < 25 {
			udpgwCol = fmt.Sprintf("%sBadVPN:%s %s", theme.Gray, theme.Reset, udpgwStatusBadge)
		}
		portTitle := "Portas UDP:"
		if len(udpgwPorts) <= 1 {
			portTitle = "Porta UDP:"
		}
		udpgwPortCol := fmt.Sprintf("%s%s%s %s%s%s", theme.Gray, portTitle, theme.Reset, theme.Cyan, portsLabel, theme.Reset)
		PrintBoxLine(formatTwoCols(udpgwCol, udpgwPortCol, contentWidth), width)
	} else {
		// Layout compacto para telas estreitas (< 54 colunas, ex: mobile / split pane)
		PrintBoxLine(fmt.Sprintf("%sIP:%s %s%s%s", theme.Gray, theme.Reset, theme.White, ip, theme.Reset), width)
		PrintBoxLine(fmt.Sprintf("%sSO:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, osName, theme.Reset), width)
		PrintBoxLine(fmt.Sprintf("%sCPU:%s %s%d%%%s %s│ RAM:%s %s%dMB (%d%%)%s",
			theme.Gray, theme.Reset, cpuColor, cpuUsage, theme.Reset,
			theme.DarkGray, theme.Reset, ramColor, ram.UsedMB, ram.Percent, theme.Reset,
		), width)
		PrintBoxLine(fmt.Sprintf("%sProxy VT:%s %s %s(%d con)%s",
			theme.Gray, theme.Reset, proxyStatusBadge, theme.Cyan, onlines, theme.Reset,
		), width)
		PrintBoxLine(fmt.Sprintf("%sBadVPN / UDPGW:%s %s %s(%s)%s",
			theme.Gray, theme.Reset, udpgwStatusBadge, theme.Cyan, portsLabel, theme.Reset,
		), width)
	}

	PrintBoxDivider(width)
}

// PrintSuccess imprime mensagem de sucesso
func PrintSuccess(msg string) {
	fmt.Printf("\n%s✔%s %s%s%s\n", theme.Green, theme.Reset, theme.White, msg, theme.Reset)
}

// PrintError imprime mensagem de erro
func PrintError(msg string) {
	fmt.Fprintf(os.Stderr, "\n%s✖%s %s%s%s\n", theme.Red, theme.Reset, theme.Red, msg, theme.Reset)
}

// PrintWarning imprime mensagem de alerta
func PrintWarning(msg string) {
	fmt.Printf("\n%s!%s %s%s%s\n", theme.Yellow, theme.Reset, theme.Yellow, msg, theme.Reset)
}

// PrintInfo imprime mensagem informativa
func PrintInfo(msg string) {
	fmt.Printf("\n%sℹ%s %s%s%s\n", theme.Cyan, theme.Reset, theme.Gray, msg, theme.Reset)
}

// UpdateDashboardMetrics atualiza no terminal apenas os valores dinâmicos (CPU, RAM, Online, Status) sem piscar a tela
func UpdateDashboardMetrics(width int) {
	if width <= 0 {
		width = GetBoxWidth()
	}

	cpuUsage := system.GetCPUUsage()
	ram := system.GetRAMInfo()
	isProxyActive := system.IsServiceActive(system.ProxyServiceName)
	onlines := proxy.GetOnlineUsersTotal()
	isUDPGWActive := udpgw.IsActive()
	udpgwPorts := udpgw.ListConfiguredPorts()

	cpuColor := theme.Green
	if cpuUsage > 75 {
		cpuColor = theme.Red
	} else if cpuUsage > 50 {
		cpuColor = theme.Yellow
	}

	ramColor := theme.Green
	if ram.Percent > 80 {
		ramColor = theme.Red
	} else if ram.Percent > 60 {
		ramColor = theme.Yellow
	}

	proxyStatusBadge := theme.BadgeOffline
	if isProxyActive {
		proxyStatusBadge = theme.BadgeOnline
	}

	udpgwStatusBadge := theme.BadgeOffline
	if isUDPGWActive {
		udpgwStatusBadge = theme.BadgeOnline
	}

	var portsLabel string
	if len(udpgwPorts) == 0 {
		portsLabel = "-"
	} else if len(udpgwPorts) == 1 {
		portsLabel = strconv.Itoa(udpgwPorts[0])
	} else if len(udpgwPorts) == 2 {
		portsLabel = fmt.Sprintf("%d, %d", udpgwPorts[0], udpgwPorts[1])
	} else {
		portsLabel = fmt.Sprintf("%d (+%d)", udpgwPorts[0], len(udpgwPorts)-1)
	}

	contentWidth := width - 4
	if contentWidth < 4 {
		contentWidth = 4
	}

	var line1, line2, line3 string
	if width >= 54 {
		cpuCol := fmt.Sprintf("%sCPU:%s %s%d%%%s", theme.Gray, theme.Reset, cpuColor, cpuUsage, theme.Reset)
		ramCol := fmt.Sprintf("%sRAM:%s %s%dMB/%dMB (%d%%)%s", theme.Gray, theme.Reset, ramColor, ram.UsedMB, ram.TotalMB, ram.Percent, theme.Reset)
		line1 = FormatBoxLine(formatTwoCols(cpuCol, ramCol, contentWidth), width)

		proxyCol := fmt.Sprintf("%sProxy VT:%s %s", theme.Gray, theme.Reset, proxyStatusBadge)
		onlineCol := fmt.Sprintf("%sOnline:%s %s%d con%s", theme.Gray, theme.Reset, theme.Cyan, onlines, theme.Reset)
		line2 = FormatBoxLine(formatTwoCols(proxyCol, onlineCol, contentWidth), width)

		avail := contentWidth - 3
		leftCol := avail / 2
		udpgwCol := fmt.Sprintf("%sBadVPN / UDPGW:%s %s", theme.Gray, theme.Reset, udpgwStatusBadge)
		if leftCol < 25 {
			udpgwCol = fmt.Sprintf("%sBadVPN:%s %s", theme.Gray, theme.Reset, udpgwStatusBadge)
		}
		portTitle := "Portas UDP:"
		if len(udpgwPorts) <= 1 {
			portTitle = "Porta UDP:"
		}
		udpgwPortCol := fmt.Sprintf("%s%s%s %s%s%s", theme.Gray, portTitle, theme.Reset, theme.Cyan, portsLabel, theme.Reset)
		line3 = FormatBoxLine(formatTwoCols(udpgwCol, udpgwPortCol, contentWidth), width)
	} else {
		line1 = FormatBoxLine(fmt.Sprintf("%sCPU:%s %s%d%%%s %s│ RAM:%s %s%dMB (%d%%)%s",
			theme.Gray, theme.Reset, cpuColor, cpuUsage, theme.Reset,
			theme.DarkGray, theme.Reset, ramColor, ram.UsedMB, ram.Percent, theme.Reset,
		), width)
		line2 = FormatBoxLine(fmt.Sprintf("%sProxy VT:%s %s %s(%d con)%s",
			theme.Gray, theme.Reset, proxyStatusBadge, theme.Cyan, onlines, theme.Reset,
		), width)
		line3 = FormatBoxLine(fmt.Sprintf("%sBadVPN / UDPGW:%s %s %s(%s)%s",
			theme.Gray, theme.Reset, udpgwStatusBadge, theme.Cyan, portsLabel, theme.Reset,
		), width)
	}

	// Sequência ANSI atômica em buffer único:
	// \033[s \0337 : Salva posição do cursor (compatível ANSI e DEC)
	// \033[?25l    : Oculta o cursor temporariamente
	// \033[14A\r   : Move o cursor para cima 14 linhas até a linha 1 dinâmica
	// Redesenha as 3 linhas dinâmicas em seus devidos lugares
	// \0338 \033[u : Restaura o cursor exatamente onde estava no prompt
	// \033[?25h    : Torna o cursor visível novamente
	var buf strings.Builder
	buf.WriteString("\033[s\0337\033[?25l")
	buf.WriteString("\033[14A\r")
	buf.WriteString(line1)
	buf.WriteString("\n\r")
	buf.WriteString(line2)
	buf.WriteString("\n\r")
	buf.WriteString(line3)
	buf.WriteString("\0338\033[u\033[?25h")

	_, _ = os.Stdout.WriteString(buf.String())
	_ = os.Stdout.Sync()
}

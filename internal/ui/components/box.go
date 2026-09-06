package components

import (
	"fmt"
	"os"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/proxy"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

const (
	DefaultBoxWidth = 66
	MinBoxWidth     = 56
	MaxBoxWidth     = 80
)

// ClearScreen limpa o terminal
func ClearScreen() {
	fmt.Print("\033[H\033[2J")
}

// PrintBoxHeader desenha o topo da caixa com o título centralizado
func PrintBoxHeader(title string, color string, width int) {
	if width <= 0 {
		width = DefaultBoxWidth
	}
	if color == "" {
		color = theme.Cyan
	}

	borderCol := theme.DarkGray
	topBorder := strings.Repeat("─", width-2)
	fmt.Printf("%s┌%s┐%s\n", borderCol, topBorder, theme.Reset)

	// Linha do título centralizada
	titleLen := theme.VisibleLen(title)
	leftPad := (width - 2 - titleLen) / 2
	if leftPad < 0 {
		leftPad = 0
	}
	rightPad := width - 2 - titleLen - leftPad
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
		width = DefaultBoxWidth
	}
	borderCol := theme.DarkGray
	divider := strings.Repeat("─", width-2)
	fmt.Printf("%s├%s┤%s\n", borderCol, divider, theme.Reset)
}

// PrintBoxLine imprime uma linha de conteúdo alinhada com as bordas da caixa
func PrintBoxLine(content string, width int) {
	if width <= 0 {
		width = DefaultBoxWidth
	}
	borderCol := theme.DarkGray
	vLen := theme.VisibleLen(content)
	pad := width - 4 - vLen
	if pad < 0 {
		pad = 0
	}

	fmt.Printf("%s│%s  %s%s  %s│%s\n",
		borderCol, theme.Reset,
		content,
		strings.Repeat(" ", pad),
		borderCol, theme.Reset,
	)
}

// PrintBoxFooter fecha a caixa └──────┘
func PrintBoxFooter(width int) {
	if width <= 0 {
		width = DefaultBoxWidth
	}
	borderCol := theme.DarkGray
	bottomBorder := strings.Repeat("─", width-2)
	fmt.Printf("%s└%s┘%s\n", borderCol, bottomBorder, theme.Reset)
}

// PrintDashboardHeader exibe as informações de sistema e status da VPS
func PrintDashboardHeader(width int) {
	if width <= 0 {
		width = DefaultBoxWidth
	}

	cpuUsage := system.GetCPUUsage()
	ram := system.GetRAMInfo()
	ip := system.GetPublicIP()
	osName := system.GetOSName()
	isProxyActive := system.IsServiceActive(system.ProxyServiceName)
	onlines := proxy.GetOnlineUsersTotal()

	PrintBoxHeader("VELTRIX PROXY • DASHBOARD", theme.Cyan, width)

	// Linha 1: IP e SO
	ipLine := fmt.Sprintf("%sIP Público:%s %s%-15s%s %s│ SO:%s %s%s%s",
		theme.Gray, theme.Reset, theme.White, ip, theme.Reset,
		theme.DarkGray, theme.Reset, theme.Cyan, osName, theme.Reset,
	)
	PrintBoxLine(ipLine, width)

	// Linha 2: CPU e RAM
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

	cpuRamLine := fmt.Sprintf("%sCPU:%s %s%d%%%s %s│ RAM:%s %s%dMB / %dMB (%d%%)%s",
		theme.Gray, theme.Reset, cpuColor, cpuUsage, theme.Reset,
		theme.DarkGray, theme.Reset, ramColor, ram.UsedMB, ram.TotalMB, ram.Percent, theme.Reset,
	)
	PrintBoxLine(cpuRamLine, width)

	// Linha 3: Status Proxy e Conexões
	proxyStatusBadge := theme.BadgeOffline
	if isProxyActive {
		proxyStatusBadge = theme.BadgeOnline
	}

	statusLine := fmt.Sprintf("%sProxy VT:%s %s %s│ Online:%s %s%d conexões%s",
		theme.Gray, theme.Reset, proxyStatusBadge,
		theme.DarkGray, theme.Reset, theme.Cyan, onlines, theme.Reset,
	)
	PrintBoxLine(statusLine, width)

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

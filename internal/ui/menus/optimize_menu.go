package menus

import (
	"fmt"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowOptimizeMenu exibe o menu de otimizações de rede e Kernel
func ShowOptimizeMenu() {
	for {
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("optimize_menu_title"), theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Otimizar limites de arquivos e sockets (65536 / limits.d)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Aplicar otimizações de Kernel & TCP BBR (sysctl.d)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Aplicar todas as otimizações recomendadas%s", theme.White, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Voltar ao menu principal%s", theme.Red, theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Selecione a opção [0-3]")
		switch choice {
		case "1":
			if err := system.ApplyFileDescriptorLimits(); err == nil {
				components.PrintSuccess("Limites de descritores configurados para 65536.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao aplicar limites: %v", err))
			}
			components.Pause()

		case "2":
			if err := system.ApplyKernelOptimizations(); err == nil {
				components.PrintSuccess("Otimizações de rede e TCP BBR aplicadas com sucesso.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao aplicar sysctl: %v", err))
			}
			components.Pause()

		case "3":
			_ = system.ApplyFileDescriptorLimits()
			_ = system.ApplyKernelOptimizations()
			components.PrintSuccess("Todas as otimizações foram aplicadas com sucesso.")
			components.Pause()

		case "0":
			return
		}
	}
}

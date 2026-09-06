package menus

import (
	"fmt"
	"strings"

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
		components.PrintDashboardHeader(w)

		// Resumo de Portas
		var activePortsStr string
		if len(cfg.Ports) > 0 {
			activePortsStr = strings.Join(cfg.Ports, ", ")
		} else {
			activePortsStr = "nenhuma"
		}

		portsLine := fmt.Sprintf("%sPortas Ativas:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, activePortsStr, theme.Reset)
		components.PrintBoxLine(portsLine, w)
		components.PrintBoxDivider(w)

		// Opções
		components.PrintBoxLine(fmt.Sprintf("%s1 — %s%s", theme.White, i18n.T("proxy_opt_start_specific"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 — %s%s", theme.White, i18n.T("proxy_opt_start_all"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 — %s%s", theme.White, i18n.T("proxy_opt_pause"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 — %s%s", theme.White, i18n.T("proxy_opt_edit"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 — %s%s", theme.White, i18n.T("proxy_opt_remove"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 — %s%s", theme.White, i18n.T("proxy_opt_restart"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 — %s%s", theme.White, i18n.T("proxy_opt_adv"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s8 — %s%s", theme.White, i18n.T("proxy_opt_http"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s9 — %s%s", theme.White, i18n.T("proxy_opt_details"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%sL — %s%s", theme.White, i18n.T("proxy_opt_logs"), theme.Reset), w)

		components.PrintBoxDivider(w)
		backLine := fmt.Sprintf("%s0 — %s%s", theme.Red, i18n.T("proxy_opt_back"), theme.Reset)
		components.PrintBoxLine(backLine, w)
		components.PrintBoxFooter(w)

		choice := strings.ToLower(components.ReadOption("Selecione a opção desejada [0-9/L]"))
		switch choice {
		case "1":
			portInput := components.Prompt("Digite a porta para abrir (ex: 80 ou 443:ssl)", "")
			if portInput != "" {
				if err := cfgMgr.AddPort(portInput); err == nil {
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess(fmt.Sprintf("Porta %s adicionada e proxy reiniciado.", portInput))
				} else {
					components.PrintError(fmt.Sprintf("Erro ao adicionar porta: %v", err))
				}
			}
			components.Pause()

		case "2":
			if err := system.StartService(system.ProxyServiceName); err == nil {
				components.PrintSuccess("Todas as portas ativas foram iniciadas.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao iniciar: %v", err))
			}
			components.Pause()

		case "3":
			if err := system.StopService(system.ProxyServiceName); err == nil {
				components.PrintSuccess("Serviço proxy pausado com sucesso.")
			} else {
				components.PrintError(fmt.Sprintf("Falha ao pausar: %v", err))
			}
			components.Pause()

		case "4":
			managePortsSubmenu(cfgMgr)

		case "5":
			portInput := components.Prompt("Digite a porta para remover", "")
			if portInput != "" {
				if err := cfgMgr.RemovePort(portInput); err == nil {
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess(fmt.Sprintf("Porta %s removida com sucesso.", portInput))
				} else {
					components.PrintError(fmt.Sprintf("Erro ao remover porta: %v", err))
				}
			}
			components.Pause()

		case "6":
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
			if newResp != "" {
				cfg.Response = newResp
				if err := cfgMgr.Save(cfg); err == nil {
					_ = system.RestartService(system.ProxyServiceName)
					components.PrintSuccess(fmt.Sprintf("Resposta HTTP atualizada para '%s'.", newResp))
				}
			}
			components.Pause()

		case "9":
			showPortDetails(cfgMgr)

		case "l", "10":
			components.ClearScreen()
			logs, err := system.GetServiceLogs(system.ProxyServiceName, 60)
			if err != nil {
				components.PrintError(fmt.Sprintf("Falha ao ler logs: %v", err))
			} else {
				fmt.Printf("%s--- LOGS DO SERVIÇO PROXY (%s) ---%s\n\n", theme.Cyan, system.ProxyServiceName, theme.Reset)
				fmt.Println(logs)
			}
			components.Pause()

		case "0":
			return

		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func managePortsSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("GERENCIAMENTO DE PORTAS", theme.Cyan, w)

		var allPorts []string
		for _, p := range cfg.Ports {
			allPorts = append(allPorts, fmt.Sprintf("%s [ATIVO]", p))
		}
		for _, p := range cfg.DisabledPorts {
			allPorts = append(allPorts, fmt.Sprintf("%s [DESATIVADO]", p))
		}

		if len(allPorts) == 0 {
			components.PrintBoxLine("Nenhuma porta configurada.", w)
		} else {
			for i, p := range allPorts {
				badge := theme.Green + "● ON " + theme.Reset
				if strings.Contains(p, "[DESATIVADO]") {
					badge = theme.Red + "○ OFF" + theme.Reset
				}
				cleanName := strings.Split(p, " ")[0]
				components.PrintBoxLine(fmt.Sprintf("%s%d • %s %s%s", theme.White, i+1, badge, theme.Cyan, cleanName), w)
			}
		}

		components.PrintBoxDivider(w)
		components.PrintBoxLine("Digite o número da porta para alternar (Ativar/Desativar)", w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção")
		if choice == "0" || choice == "" {
			return
		}

		var idx int
		_, err := fmt.Sscanf(choice, "%d", &idx)
		if err == nil && idx > 0 && idx <= len(allPorts) {
			target := strings.Split(allPorts[idx-1], " ")[0]
			nowActive, toggleErr := cfgMgr.TogglePort(target)
			if toggleErr == nil {
				_ = system.RestartService(system.ProxyServiceName)
				statusMsg := "desativada"
				if nowActive {
					statusMsg = "ativada"
				}
				components.PrintSuccess(fmt.Sprintf("Porta %s %s.", target, statusMsg))
			}
			components.Pause()
		}
	}
}

func showPortDetails(cfgMgr *config.Manager) {
	cfg, _ := cfgMgr.Get()
	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader("DETALHES E STATUS DAS PORTAS", theme.Cyan, w)

	for _, p := range cfg.Ports {
		mode := "HTTP"
		if strings.HasSuffix(p, ":ssl") {
			mode = "HTTPS / TLS"
		}
		components.PrintBoxLine(fmt.Sprintf("Porta %s%s%s: %s | Status: %s", theme.Cyan, p, theme.Reset, mode, theme.BadgeOnline), w)
	}

	for _, p := range cfg.DisabledPorts {
		components.PrintBoxLine(fmt.Sprintf("Porta %s%s%s: Status: %s", theme.Gray, p, theme.Reset, theme.BadgeOffline), w)
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

package menus

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowAdvancedMenu exibe o menu de opções avançadas (config.json)
func ShowAdvancedMenu(cfgMgr *config.Manager) {
	for {
		cfg, err := cfgMgr.Get()
		if err != nil {
			components.PrintError(fmt.Sprintf("Erro ao carregar configuração: %v", err))
			components.Pause()
			return
		}

		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("adv_menu_title"), theme.Cyan, components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • %s%s", theme.White, i18n.T("adv_opt_perf"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s%s", theme.White, i18n.T("adv_opt_http_logs"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s%s", theme.White, i18n.T("adv_opt_ssl"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s%s", theme.White, i18n.T("adv_opt_ssh"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s%s", theme.White, i18n.T("adv_opt_btun"), theme.Reset), components.DefaultBoxWidth)

		// Opção 6 SÓ APARECE se ssh.internal for true!
		if cfg.SSH.Internal {
			limiterBadge := theme.Red + "false" + theme.Reset
			if cfg.Limits.Enable {
				limiterBadge = theme.Green + "true" + theme.Reset
			}
			limLine := fmt.Sprintf("%s6 • %s (Limiter: %s%s)%s", theme.White, i18n.T("adv_opt_limits"), limiterBadge, theme.White, theme.Reset)
			components.PrintBoxLine(limLine, components.DefaultBoxWidth)
		}

		components.PrintBoxLine(fmt.Sprintf("%s7 • %s%s", theme.White, i18n.T("adv_opt_connectors"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%sV • %s%s", theme.White, i18n.T("adv_opt_view_json"), theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		backLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("adv_opt_finish"), theme.Reset)
		components.PrintBoxLine(backLine, components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		promptRange := "0-7/V"
		if !cfg.SSH.Internal {
			promptRange = "0-5,7/V"
		}

		choice := strings.ToLower(components.ReadOption(fmt.Sprintf("Selecione a opção [%s]", promptRange)))
		switch choice {
		case "1":
			showPerformanceSubmenu(cfgMgr)
		case "2":
			showHttpLogsSubmenu(cfgMgr)
		case "3":
			showSSLSubmenu(cfgMgr)
		case "4":
			showSSHSubmenu(cfgMgr)
		case "5":
			showBTUNSubmenu(cfgMgr)
		case "6":
			if cfg.SSH.Internal {
				ShowLimitsMenu(cfgMgr)
			} else {
				components.PrintError("Opção indisponível: o Limiter requer o SSH Nativo Go (ssh.internal: true).")
				components.Pause()
			}
		case "7":
			showConnectorsSubmenu(cfgMgr)
		case "v":
			viewConfigFile(cfgMgr)
		case "0":
			if system.IsServiceActive(system.ProxyServiceName) {
				if components.Confirm("Deseja reiniciar o serviço proxy para aplicar eventuais alterações?", true) {
					if err := system.RestartService(system.ProxyServiceName); err == nil {
						components.PrintSuccess("Serviço proxy reiniciado com sucesso.")
					} else {
						components.PrintError(fmt.Sprintf("Falha ao reiniciar: %v", err))
					}
					components.Pause()
				}
			}
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showPerformanceSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		components.ClearScreen()
		components.PrintBoxHeader("DESEMPENHO, BUFFER & TIMEOUTS", theme.Cyan, components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Buffer I/O: %s%d bytes%s (32KB padrão)", theme.White, theme.Cyan, cfg.BufferSize, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Máximo de Conexões: %s%d%s (0=ilimitado)", theme.White, theme.Cyan, cfg.MaxConnections, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Idle Timeout: %s%ds%s (0=desligado)", theme.White, theme.Cyan, cfg.IdleTimeout, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Write Timeout: %s%ds%s (0=desligado)", theme.White, theme.Cyan, cfg.WriteTimeout, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s5 • Ulimit (RLIMIT_NOFILE): %s%d%s", theme.White, theme.Cyan, cfg.Ulimit, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Opção [0-5]")
		switch choice {
		case "1":
			resp := components.Prompt("Tamanho do buffer I/O em bytes (ex: 32768, 65536)", strconv.Itoa(cfg.BufferSize))
			if val, err := strconv.Atoi(resp); err == nil && val > 0 {
				cfg.BufferSize = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Buffer atualizado.")
			}
			components.Pause()
		case "2":
			resp := components.Prompt("Máximo de conexões (0=ilimitado)", strconv.Itoa(cfg.MaxConnections))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.MaxConnections = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Limite de conexões atualizado.")
			}
			components.Pause()
		case "3":
			resp := components.Prompt("Idle timeout em segundos (0=desligado)", strconv.Itoa(cfg.IdleTimeout))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.IdleTimeout = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Idle timeout atualizado.")
			}
			components.Pause()
		case "4":
			resp := components.Prompt("Write timeout em segundos (0=desligado)", strconv.Itoa(cfg.WriteTimeout))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.WriteTimeout = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Write timeout atualizado.")
			}
			components.Pause()
		case "5":
			resp := components.Prompt("Ulimit nofile (padrão 65536)", strconv.Itoa(cfg.Ulimit))
			if val, err := strconv.Atoi(resp); err == nil && val >= 1024 {
				cfg.Ulimit = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Ulimit atualizado.")
			}
			components.Pause()
		case "0":
			return
		}
	}
}

func showHttpLogsSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		components.ClearScreen()
		components.PrintBoxHeader("RESPOSTA HTTP, BANNER & LOGS", theme.Cyan, components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Resposta HTTP 200: %s%s%s", theme.White, theme.Cyan, cfg.Response, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Exibir Banner no Boot: %s%v%s", theme.White, theme.Cyan, cfg.DisplayBanner, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Modo SSH-Only: %s%v%s", theme.White, theme.Cyan, cfg.SSHOnly, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Nível de Log: %s%s%s", theme.White, theme.Cyan, cfg.LogLevel, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Opção [0-4]")
		switch choice {
		case "1":
			resp := components.Prompt("Nova resposta HTTP global", cfg.Response)
			if resp != "" {
				cfg.Response = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Resposta HTTP atualizada.")
			}
			components.Pause()
		case "2":
			cfg.DisplayBanner = components.Confirm("Exibir banner na inicialização?", cfg.DisplayBanner)
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("Display banner atualizado.")
			components.Pause()
		case "3":
			cfg.SSHOnly = components.Confirm("Ativar modo SSH-Only?", cfg.SSHOnly)
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("SSH-Only atualizado.")
			components.Pause()
		case "4":
			fmt.Printf("\nNíveis disponíveis: debug, info, warn, error\n")
			resp := components.Prompt("Nível de log", cfg.LogLevel)
			if resp != "" {
				cfg.LogLevel = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Nível de log atualizado.")
			}
			components.Pause()
		case "0":
			return
		}
	}
}

func showSSLSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		components.ClearScreen()
		components.PrintBoxHeader("CERTIFICADOS TLS / SSL", theme.Cyan, components.DefaultBoxWidth)

		certPath := cfg.Cert
		if certPath == "" {
			certPath = "nenhum"
		}

		components.PrintBoxLine(fmt.Sprintf("%s1 • Certificado Interno Cloudflare: %s%v%s", theme.White, theme.Cyan, cfg.CertInternal, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Certificado Externo .crt/.pem: %s%s%s", theme.White, theme.Cyan, certPath, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Opção [0-2]")
		switch choice {
		case "1":
			cfg.CertInternal = components.Confirm("Usar certificado TLS Cloudflare embutido?", cfg.CertInternal)
			if cfg.CertInternal {
				cfg.Cert = ""
			}
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("Configuração cert_internal atualizada.")
			components.Pause()
		case "2":
			resp := components.Prompt("Caminho do certificado TLS externo (.crt / .pem)", cfg.Cert)
			if resp != "" {
				cfg.Cert = resp
				cfg.CertInternal = false
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Certificado externo configurado.")
			}
			components.Pause()
		case "0":
			return
		}
	}
}

func showSSHSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		components.ClearScreen()
		components.PrintBoxHeader("SERVIDOR SSH NATIVO (ZERO-FORK)", theme.Cyan, components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • SSH Nativo Go (ssh.internal): %s%v%s (Zero-Fork)", theme.White, theme.Cyan, cfg.SSH.Internal, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Porta OpenSSH Externo (ssh.port): %s%d%s", theme.White, theme.Cyan, cfg.SSH.Port, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Porta TCP Direta Interna: %s%d%s (0=apenas WS)", theme.White, theme.Cyan, cfg.SSH.InternalPort, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Permitir Root (allow_root): %s%v%s", theme.White, theme.Cyan, cfg.SSH.AllowRoot, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Opção [0-4]")
		switch choice {
		case "1":
			cfg.SSH.Internal = components.Confirm("Ativar servidor SSH nativo em Go (Zero-Fork)?", cfg.SSH.Internal)
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("Configuração ssh.internal atualizada.")
			components.Pause()
		case "2":
			resp := components.Prompt("Porta do OpenSSH externo legado", strconv.Itoa(cfg.SSH.Port))
			if val, err := strconv.Atoi(resp); err == nil && val > 0 {
				cfg.SSH.Port = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Porta SSH externa atualizada.")
			}
			components.Pause()
		case "3":
			resp := components.Prompt("Porta TCP direta para SSH interno (0=apenas via túnel)", strconv.Itoa(cfg.SSH.InternalPort))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.SSH.InternalPort = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Porta TCP direta atualizada.")
			}
			components.Pause()
		case "4":
			cfg.SSH.AllowRoot = components.Confirm("Permitir login de root no SSH interno?", cfg.SSH.AllowRoot)
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("allow_root atualizado.")
			components.Pause()
		case "0":
			return
		}
	}
}

func showBTUNSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		components.ClearScreen()
		components.PrintBoxHeader("SERVIDOR BTUN (DT-PROTO / UDP NATIVO)", theme.Cyan, components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Habilitar BTUN: %s%v%s", theme.White, theme.Cyan, cfg.BTUN.Enable, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Interface TUN: %s%s%s", theme.White, theme.Cyan, cfg.BTUN.Tun, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Sub-rede IPv4: %s%s%s", theme.White, theme.Cyan, cfg.BTUN.Subnet, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Porta UDP Direta: %s%d%s (0=desativado)", theme.White, theme.Cyan, cfg.BTUN.UDPPort, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Opção [0-4]")
		switch choice {
		case "1":
			cfg.BTUN.Enable = components.Confirm("Habilitar BTUN nativo via TUN?", cfg.BTUN.Enable)
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("btun.enable atualizado.")
			components.Pause()
		case "2":
			resp := components.Prompt("Nome da interface TUN", cfg.BTUN.Tun)
			if resp != "" {
				cfg.BTUN.Tun = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("btun.tun atualizado.")
			}
			components.Pause()
		case "3":
			resp := components.Prompt("Sub-rede IPv4 para clientes BTUN", cfg.BTUN.Subnet)
			if resp != "" {
				cfg.BTUN.Subnet = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("btun.subnet atualizado.")
			}
			components.Pause()
		case "4":
			resp := components.Prompt("Porta UDP direta (0=desativado)", strconv.Itoa(cfg.BTUN.UDPPort))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.BTUN.UDPPort = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("btun.udp_port atualizado.")
			}
			components.Pause()
		case "0":
			return
		}
	}
}

func showConnectorsSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		components.ClearScreen()
		components.PrintBoxHeader("CONECTORES BACKENDS & XHTTP", theme.Cyan, components.DefaultBoxWidth)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Porta Local OpenVPN: %s%d%s", theme.White, theme.Cyan, cfg.Connectors.OpenVPNPort, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Porta Local V2Ray / Xray: %s%d%s", theme.White, theme.Cyan, cfg.Connectors.V2RayPort, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Prefixo URL XHTTP: %s%s%s", theme.White, theme.Cyan, cfg.XHTTP.Path, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Grace Period XHTTP: %s%ds%s", theme.White, theme.Cyan, cfg.XHTTP.Grace, theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s5 • Idle Timeout XHTTP: %s%ds%s", theme.White, theme.Cyan, cfg.XHTTP.Idle, theme.Reset), components.DefaultBoxWidth)

		components.PrintBoxDivider(components.DefaultBoxWidth)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), components.DefaultBoxWidth)
		components.PrintBoxFooter(components.DefaultBoxWidth)

		choice := components.ReadOption("Opção [0-5]")
		switch choice {
		case "1":
			resp := components.Prompt("Porta local OpenVPN", strconv.Itoa(cfg.Connectors.OpenVPNPort))
			if val, err := strconv.Atoi(resp); err == nil && val > 0 {
				cfg.Connectors.OpenVPNPort = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Porta OpenVPN atualizada.")
			}
			components.Pause()
		case "2":
			resp := components.Prompt("Porta local V2Ray / Xray", strconv.Itoa(cfg.Connectors.V2RayPort))
			if val, err := strconv.Atoi(resp); err == nil && val > 0 {
				cfg.Connectors.V2RayPort = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Porta V2Ray atualizada.")
			}
			components.Pause()
		case "3":
			resp := components.Prompt("Prefixo de URL SplitHTTP", cfg.XHTTP.Path)
			if resp != "" {
				cfg.XHTTP.Path = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("xhttp.path atualizado.")
			}
			components.Pause()
		case "4":
			resp := components.Prompt("Grace period em segundos", strconv.Itoa(cfg.XHTTP.Grace))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.XHTTP.Grace = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("xhttp.grace atualizado.")
			}
			components.Pause()
		case "5":
			resp := components.Prompt("Idle timeout em segundos", strconv.Itoa(cfg.XHTTP.Idle))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.XHTTP.Idle = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("xhttp.idle atualizado.")
			}
			components.Pause()
		case "0":
			return
		}
	}
}

func viewConfigFile(cfgMgr *config.Manager) {
	components.ClearScreen()
	data, err := os.ReadFile(cfgMgr.Path())
	if err != nil {
		components.PrintError(fmt.Sprintf("Falha ao ler arquivo: %v", err))
		components.Pause()
		return
	}

	var pretty map[string]interface{}
	_ = json.Unmarshal(data, &pretty)
	formatted, _ := json.MarshalIndent(pretty, "", "  ")

	fmt.Printf("\n%sConteúdo de %s:%s\n\n", theme.Cyan, cfgMgr.Path(), theme.Reset)
	fmt.Println(string(formatted))
	components.Pause()
}

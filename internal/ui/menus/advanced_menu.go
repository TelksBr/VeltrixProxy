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

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("adv_menu_title"), theme.Cyan, w)

		components.PrintBoxLine(advMenuItem("1", i18n.T("adv_opt_perf"), ""), w)
		components.PrintBoxLine(advMenuItem("2", i18n.T("adv_opt_http_logs"), ""), w)
		components.PrintBoxLine(advMenuItem("3", i18n.T("adv_opt_ssl"), components.FormatBool(cfg.CertInternal)), w)
		components.PrintBoxLine(advMenuItem("4", i18n.T("adv_opt_ssh"), components.FormatBool(cfg.SSH.Internal)), w)
		components.PrintBoxLine(advMenuItem("5", i18n.T("adv_opt_btun"), components.FormatBool(cfg.BTUN.Enable)), w)
		components.PrintBoxLine(advMenuItem("6", i18n.T("adv_opt_limits"), components.FormatBool(cfg.Limits.Enable)), w)
		components.PrintBoxLine(advMenuItem("7", i18n.T("adv_opt_xhttp"), ""), w)
		components.PrintBoxLine(advMenuItem("8", i18n.T("adv_opt_dnstt"), components.FormatBool(cfg.DNSTT.Enable)), w)
		components.PrintBoxLine(advMenuItem("9", i18n.T("adv_opt_ztun"), components.FormatBool(cfg.Ztun.Enable)), w)
		components.PrintBoxLine(advMenuItem("V", i18n.T("adv_opt_view_json"), ""), w)

		components.PrintBoxDivider(w)
		backLine := fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("adv_opt_finish"), theme.Reset)
		components.PrintBoxLine(backLine, w)
		components.PrintBoxFooter(w)

		choice := strings.ToLower(components.ReadOption(i18n.T("adv_prompt_range")))
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
			ShowLimitsMenu(cfgMgr)
		case "7":
			showXHTTPSubmenu(cfgMgr)
		case "8":
			ShowDNSTTMenu(cfgMgr)
		case "9":
			showZtunSubmenu(cfgMgr)
		case "v":
			viewConfigFile(cfgMgr)
		case "0":
			if system.IsServiceActive(system.ProxyServiceName) {
				if components.Confirm(i18n.T("confirm_restart_proxy"), true) {
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

func advMenuItem(num, label, badge string) string {
	if badge == "" {
		return fmt.Sprintf("%s%s • %s%s", theme.White, num, label, theme.Reset)
	}
	return fmt.Sprintf("%s%s • %s: %s%s", theme.White, num, label, badge, theme.Reset)
}

func displayOrEmpty(v string) string {
	if strings.TrimSpace(v) == "" {
		return "(vazio)"
	}
	return v
}

func promptAuthMode(current string) string {
	fmt.Printf("\n%s%s%s\n", theme.Cyan, i18n.T("auth_mode_title"), theme.Reset)
	fmt.Printf("  1 • %s\n", i18n.T("auth_mode_shadow"))
	fmt.Printf("  2 • %s\n", i18n.T("auth_mode_file"))
	fmt.Printf("  3 • %s\n", i18n.T("auth_mode_allow"))
	choice := components.ReadOption(i18n.T("prompt_select_option") + " [0-3]")
	switch choice {
	case "1":
		return "shadow"
	case "2":
		return "file"
	case "3":
		return "allow"
	default:
		return current
	}
}

func promptLogLevel(current string) string {
	current = config.NormalizeLogLevel(current)
	fmt.Printf("\n%sNível de log (do mais verboso ao mais quieto)%s\n", theme.Cyan, theme.Reset)
	fmt.Printf("  Atual: %s%s%s\n\n", theme.Yellow, current, theme.Reset)
	fmt.Printf("  1 • trace   — classify, copy, preview HTTP, tls-mux\n")
	fmt.Printf("  2 • debug   — sessão, connector, ztun/xhttp/bhttp-trace\n")
	fmt.Printf("  3 • info    — startup, auth, listeners\n")
	fmt.Printf("  4 • warn    — só avisos e erros\n")
	fmt.Printf("  5 • error   — só erros (padrão de instalação)\n")
	fmt.Printf("  6 • silent  — sem logs (banner/Fatalf ainda saem)\n")
	fmt.Printf("  0 • manter atual\n")
	choice := components.ReadOption(i18n.T("prompt_select_option") + " [0-6]")
	switch choice {
	case "1":
		return "trace"
	case "2":
		return "debug"
	case "3":
		return "info"
	case "4":
		return "warn"
	case "5":
		return "error"
	case "6":
		return "silent"
	default:
		return current
	}
}

func applyJSONBoolToggle(cfgMgr *config.Manager, cfg *config.Config, current bool, set func(bool), enableQuestion, disableQuestion, field string) {
	newValue, changed := components.ConfirmToggle(enableQuestion, disableQuestion, current)
	if !changed {
		components.PrintInfo(i18n.T("confirm_no_change", field, current))
		components.Pause()
		return
	}

	set(newValue)
	if err := cfgMgr.Save(cfg); err != nil {
		components.PrintError(fmt.Sprintf("Falha ao salvar: %v", err))
		components.Pause()
		return
	}
	if newValue {
		components.PrintSuccess(i18n.T("toggle_enabled", field))
	} else {
		components.PrintSuccess(i18n.T("toggle_disabled", field))
	}
	components.Pause()
}

func showPerformanceSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("DESEMPENHO, BUFFER & TIMEOUTS", theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Buffer I/O: %s%d bytes%s (32KB padrão)", theme.White, theme.Cyan, cfg.BufferSize, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Máximo de Conexões: %s%d%s (0=ilimitado)", theme.White, theme.Cyan, cfg.MaxConnections, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Idle Timeout: %s%ds%s (0=desligado)", theme.White, theme.Cyan, cfg.IdleTimeout, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Write Timeout: %s%ds%s (0=desligado)", theme.White, theme.Cyan, cfg.WriteTimeout, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • Ulimit (RLIMIT_NOFILE): %s%d%s", theme.White, theme.Cyan, cfg.Ulimit, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

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
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("RESPOSTA HTTP, BANNER & LOGS", theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Resposta HTTP 200: %s%s%s", theme.White, theme.Cyan, cfg.Response, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Exibir Banner no Boot: %s%s", theme.White, components.FormatBool(cfg.DisplayBanner), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Nível de Log: %s%s%s", theme.White, theme.Cyan, cfg.LogLevel, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Arquivo de Log: %s%s%s", theme.White, theme.Cyan, cfg.LogFile, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

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
			applyJSONBoolToggle(cfgMgr, cfg, cfg.DisplayBanner, func(v bool) { cfg.DisplayBanner = v },
				i18n.T("toggle_banner_on"),
				i18n.T("toggle_banner_off"),
				"display_banner")
		case "3":
			level := promptLogLevel(cfg.LogLevel)
			if level != "" && level != cfg.LogLevel {
				cfg.LogLevel = level
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess(fmt.Sprintf("Nível de log atualizado para '%s'.", level))
			}
			components.Pause()
		case "4":
			resp := components.Prompt("Caminho do arquivo de log", cfg.LogFile)
			if resp != "" {
				cfg.LogFile = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Caminho do arquivo de log atualizado.")
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
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("CERTIFICADOS TLS / SSL", theme.Cyan, w)

		certPath := cfg.Cert
		if certPath == "" {
			certPath = "nenhum (usando gerador embutido)"
		}
		components.PrintBoxLine(fmt.Sprintf("%s1 • Certificado Interno Cloudflare: %s%s", theme.White, components.FormatBool(cfg.CertInternal), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Certificado Externo .crt/.pem: %s%s%s", theme.White, theme.Cyan, certPath, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-2]")
		switch choice {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.CertInternal, func(v bool) {
				cfg.CertInternal = v
				if v {
					cfg.Cert = ""
				}
			},
				i18n.T("toggle_cert_internal_on"),
				i18n.T("toggle_cert_internal_off"),
				"cert_internal")
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
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("SERVIDOR SSH NATIVO (ZERO-FORK)", theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • SSH Nativo Go (ssh.internal): %s%s", theme.White, components.FormatBool(cfg.SSH.Internal), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Porta OpenSSH Externo (ssh.port): %s%d%s", theme.White, theme.Cyan, cfg.SSH.Port, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Porta TCP Direta Interna: %s%d%s (0=apenas WS)", theme.White, theme.Cyan, cfg.SSH.InternalPort, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Permitir Root (allow_root): %s%s", theme.White, components.FormatBool(cfg.SSH.AllowRoot), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s: %s%s%s", theme.White, i18n.T("ssh_opt_auth"), theme.Cyan, displayOrEmpty(cfg.SSH.Auth), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s: %s%s%s", theme.White, i18n.T("ssh_opt_auth_file"), theme.Cyan, displayOrEmpty(cfg.SSH.AuthFile), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 • %s: %s%s%s", theme.White, i18n.T("ssh_opt_banner"), theme.Cyan, displayOrEmpty(cfg.SSH.Banner), theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-7]")
		switch choice {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.SSH.Internal, func(v bool) { cfg.SSH.Internal = v },
				i18n.T("toggle_ssh_internal_on"),
				i18n.T("toggle_ssh_internal_off"),
				"ssh.internal")
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
				if val > 0 && val != cfg.SSH.InternalPort {
					inUse, procInfo := system.IsPortInUseByOther("tcp", val)
					if inUse {
						components.PrintWarning(fmt.Sprintf("Atenção: A porta TCP %d já está em uso por '%s'.", val, procInfo))
						if !components.Confirm("Deseja configurar esta porta mesmo assim?", false) {
							break
						}
					}
				}
				cfg.SSH.InternalPort = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Porta TCP direta atualizada.")
			}
			components.Pause()
		case "4":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.SSH.AllowRoot, func(v bool) { cfg.SSH.AllowRoot = v },
				i18n.T("toggle_allow_root_on"),
				i18n.T("toggle_allow_root_off"),
				"ssh.allow_root")
		case "5":
			mode := promptAuthMode(cfg.SSH.Auth)
			if mode != cfg.SSH.Auth {
				cfg.SSH.Auth = mode
				if mode == "file" && strings.TrimSpace(cfg.SSH.AuthFile) == "" {
					cfg.SSH.AuthFile = components.Prompt(i18n.T("ssh_opt_auth_file"), cfg.SSH.AuthFile)
				}
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("ssh.auth atualizado.")
			}
			components.Pause()
		case "6":
			resp := components.Prompt(i18n.T("ssh_opt_auth_file"), cfg.SSH.AuthFile)
			cfg.SSH.AuthFile = resp
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("ssh.auth_file atualizado.")
			components.Pause()
		case "7":
			resp := components.Prompt(i18n.T("ssh_opt_banner"), cfg.SSH.Banner)
			if resp != "" {
				cfg.SSH.Banner = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("ssh.banner atualizado.")
			}
			components.Pause()
		case "0":
			return
		}
	}
}

func showBTUNSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("SERVIDOR BTUN (DT-PROTO / UDP NATIVO)", theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Habilitar BTUN: %s%s", theme.White, components.FormatBool(cfg.BTUN.Enable), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Interface TUN: %s%s%s", theme.White, theme.Cyan, cfg.BTUN.Tun, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Sub-rede IPv4: %s%s%s", theme.White, theme.Cyan, cfg.BTUN.Subnet, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • Porta UDP Direta: %s%d%s (0=desativado)", theme.White, theme.Cyan, cfg.BTUN.UDPPort, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s: %s%s%s", theme.White, i18n.T("btun_opt_auth"), theme.Cyan, displayOrEmpty(cfg.BTUN.Auth), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s: %s%s%s", theme.White, i18n.T("btun_opt_auth_file"), theme.Cyan, displayOrEmpty(cfg.BTUN.AuthFile), theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-6]")
		switch choice {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.BTUN.Enable, func(v bool) { cfg.BTUN.Enable = v },
				i18n.T("toggle_btun_on"),
				i18n.T("toggle_btun_off"),
				"btun.enable")
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
				if val > 0 && val != cfg.BTUN.UDPPort {
					avail, procInfo := system.CheckUDPPortAvailable(val)
					if !avail {
						components.PrintWarning(fmt.Sprintf("Atenção: A porta UDP %d já está em uso por '%s'.", val, procInfo))
						if !components.Confirm("Deseja configurar esta porta mesmo assim?", false) {
							break
						}
					}
				}
				cfg.BTUN.UDPPort = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("btun.udp_port atualizado.")
			}
			components.Pause()
		case "5":
			mode := promptAuthMode(cfg.BTUN.Auth)
			if mode != cfg.BTUN.Auth {
				cfg.BTUN.Auth = mode
				if mode == "file" && strings.TrimSpace(cfg.BTUN.AuthFile) == "" {
					cfg.BTUN.AuthFile = components.Prompt(i18n.T("btun_opt_auth_file"), cfg.BTUN.AuthFile)
				}
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("btun.auth atualizado.")
			}
			components.Pause()
		case "6":
			resp := components.Prompt(i18n.T("btun_opt_auth_file"), cfg.BTUN.AuthFile)
			cfg.BTUN.AuthFile = resp
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("btun.auth_file atualizado.")
			components.Pause()
		case "0":
			return
		}
	}
}

func showXHTTPSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("CONFIGURAÇÕES XHTTP / SPLITHTTP", theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • Prefixo URL XHTTP: %s%s%s", theme.White, theme.Cyan, cfg.XHTTP.Path, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Grace Period XHTTP: %s%ds%s", theme.White, theme.Cyan, cfg.XHTTP.Grace, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Idle Timeout XHTTP: %s%ds%s", theme.White, theme.Cyan, cfg.XHTTP.Idle, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-3]")
		switch choice {
		case "1":
			resp := components.Prompt("Prefixo de URL SplitHTTP", cfg.XHTTP.Path)
			if resp != "" {
				cfg.XHTTP.Path = resp
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("xhttp.path atualizado.")
			}
			components.Pause()
		case "2":
			resp := components.Prompt("Grace period em segundos", strconv.Itoa(cfg.XHTTP.Grace))
			if val, err := strconv.Atoi(resp); err == nil && val >= 0 {
				cfg.XHTTP.Grace = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("xhttp.grace atualizado.")
			}
			components.Pause()
		case "3":
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

func ztunRuntimeMode(cfg *config.Config) string {
	if strings.TrimSpace(cfg.Ztun.Upstream) != "" {
		return i18n.T("ztun_mode_passthrough")
	}
	if cfg.Ztun.Enable {
		return i18n.T("ztun_mode_native")
	}
	return i18n.T("ztun_mode_classify_only")
}

func showZtunSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, _ := cfgMgr.Get()
		if cfg.Ztun.Auth == "" {
			cfg.Ztun.Auth = "shadow"
		}
		if cfg.Ztun.Idle <= 0 {
			cfg.Ztun.Idle = 180
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("ztun_menu_title"), theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%s• Modo: %s%s%s", theme.White, theme.Cyan, ztunRuntimeMode(cfg), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("ztun_upstream_hint"), theme.Reset), w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • %s: %s%s", theme.White, i18n.T("ztun_opt_enable"), components.FormatBool(cfg.Ztun.Enable), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s: %s%s%s", theme.White, i18n.T("ztun_opt_upstream"), theme.Cyan, displayOrEmpty(cfg.Ztun.Upstream), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s: %s%s%s", theme.White, i18n.T("ztun_opt_auth"), theme.Cyan, displayOrEmpty(cfg.Ztun.Auth), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s: %s%s%s", theme.White, i18n.T("ztun_opt_auth_file"), theme.Cyan, displayOrEmpty(cfg.Ztun.AuthFile), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s: %s%d%s", theme.White, i18n.T("ztun_opt_idle"), theme.Cyan, cfg.Ztun.Idle, theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := components.ReadOption("Opção [0-5]")
		switch choice {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Ztun.Enable, func(v bool) { cfg.Ztun.Enable = v },
				i18n.T("toggle_ztun_on"),
				i18n.T("toggle_ztun_off"),
				"ztun.enable")
		case "2":
			resp := components.Prompt(i18n.T("ztun_opt_upstream")+" (ex: 127.0.0.1:9443)", cfg.Ztun.Upstream)
			cfg.Ztun.Upstream = strings.TrimSpace(resp)
			if err := cfgMgr.Save(cfg); err == nil {
				components.PrintSuccess("ztun.upstream atualizado.")
			} else {
				components.PrintError(fmt.Sprintf("Erro ao salvar: %v", err))
			}
			components.Pause()
		case "3":
			mode := promptAuthMode(cfg.Ztun.Auth)
			if mode != cfg.Ztun.Auth {
				cfg.Ztun.Auth = mode
				if mode == "file" && strings.TrimSpace(cfg.Ztun.AuthFile) == "" {
					cfg.Ztun.AuthFile = components.Prompt(i18n.T("ztun_opt_auth_file"), "/etc/proxy/users")
				}
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("ztun.auth atualizado.")
			}
			components.Pause()
		case "4":
			resp := components.Prompt(i18n.T("ztun_opt_auth_file"), cfg.Ztun.AuthFile)
			cfg.Ztun.AuthFile = strings.TrimSpace(resp)
			_ = cfgMgr.Save(cfg)
			components.PrintSuccess("ztun.auth_file atualizado.")
			components.Pause()
		case "5":
			resp := components.Prompt(i18n.T("ztun_opt_idle")+" (padrão 180)", strconv.Itoa(cfg.Ztun.Idle))
			if val, err := strconv.Atoi(strings.TrimSpace(resp)); err == nil {
				if val <= 0 {
					val = 180
				}
				cfg.Ztun.Idle = val
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess(fmt.Sprintf("ztun.idle atualizado para %d.", val))
			} else {
				components.PrintError("Valor inválido.")
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

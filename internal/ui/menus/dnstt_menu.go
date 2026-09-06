package menus

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowDNSTTMenu gerencia a configuração e ativação do servidor DNS Tunneling (DNSTT)
func ShowDNSTTMenu(cfgMgr *config.Manager) {
	for {
		cfg, err := cfgMgr.Get()
		if err != nil {
			components.PrintError(fmt.Sprintf("Erro ao carregar configuração: %v", err))
			components.Pause()
			return
		}

		// Garante padrões se campos estiverem vazios
		if cfg.DNSTT.UDP == "" {
			cfg.DNSTT.UDP = ":53"
		}
		if cfg.DNSTT.PrivkeyFile == "" && cfg.DNSTT.Privkey == "" {
			cfg.DNSTT.PrivkeyFile = system.DefaultDNSTTKeyFile
		}
		if cfg.DNSTT.MTU <= 0 {
			cfg.DNSTT.MTU = 1232
		}

		// Obtém a chave pública atual se houver chave configurada
		currentPubkey := ""
		if cfg.DNSTT.Privkey != "" {
			if pub, errPub := system.PubkeyFromPrivkeyHex(cfg.DNSTT.Privkey); errPub == nil {
				currentPubkey = pub
			}
		} else if cfg.DNSTT.PrivkeyFile != "" {
			if privFile, errRead := system.ReadPrivateKeyFromFile(cfg.DNSTT.PrivkeyFile); errRead == nil {
				if pub, errPub := system.PubkeyFromPrivkeyHex(privFile); errPub == nil {
					currentPubkey = pub
				}
			}
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("dnstt_menu_title"), theme.Cyan, w)

		// Status Badge
		statusBadge := theme.BadgeOffline
		if cfg.DNSTT.Enable {
			statusBadge = theme.BadgeOnline
		}

		domainDisplay := cfg.DNSTT.Domain
		if domainDisplay == "" {
			domainDisplay = "[Não configurado]"
		}

		pubkeyDisplay := currentPubkey
		if pubkeyDisplay == "" {
			pubkeyDisplay = "[Nenhuma chave gerada]"
		} else if len(pubkeyDisplay) > 28 {
			pubkeyDisplay = pubkeyDisplay[:12] + "..." + pubkeyDisplay[len(pubkeyDisplay)-12:]
		}

		fallbackDisplay := cfg.DNSTT.Fallback
		if fallbackDisplay == "" {
			fallbackDisplay = "[Desativado]"
		}

		upstreamDisplay := cfg.DNSTT.Upstream
		if upstreamDisplay == "" {
			upstreamDisplay = "[Pipeline Nativo VTProxy]"
		}

		components.PrintBoxLine(fmt.Sprintf("%s• DNSTT Server:%s %s  │  %sPorta UDP:%s %s%s%s", theme.White, theme.Reset, statusBadge, theme.White, theme.Reset, theme.Cyan, cfg.DNSTT.UDP, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Domínio:     %s%s%s", theme.White, theme.Cyan, domainDisplay, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Chave Pública:%s %s%s%s", theme.White, theme.Reset, theme.Yellow, pubkeyDisplay, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Fallback:    %s%s%s  │  %sMTU:%s %s%d%s", theme.White, theme.Cyan, fallbackDisplay, theme.Reset, theme.White, theme.Reset, theme.Cyan, cfg.DNSTT.MTU, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Upstream:    %s%s%s", theme.White, theme.Cyan, upstreamDisplay, theme.Reset), w)

		components.PrintBoxDivider(w)

		components.PrintBoxLine(fmt.Sprintf("%s1 • %s%s", theme.White, i18n.T("dnstt_opt_toggle"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • %s%s", theme.White, i18n.T("dnstt_opt_domain"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • %s%s", theme.White, i18n.T("dnstt_opt_udp"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s4 • %s%s", theme.White, i18n.T("dnstt_opt_keys"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s5 • %s%s", theme.White, i18n.T("dnstt_opt_fallback"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s6 • %s%s", theme.White, i18n.T("dnstt_opt_upstream"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s7 • %s%s", theme.White, i18n.T("dnstt_opt_mtu"), theme.Reset), w)

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("adv_opt_finish"), theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := strings.TrimSpace(components.ReadOption("Selecione a opção [0-7]"))
		switch choice {
		case "1":
			handleToggleDNSTT(cfgMgr, cfg, currentPubkey)
		case "2":
			handleEditDomain(cfgMgr, cfg)
		case "3":
			handleEditUDP(cfgMgr, cfg)
		case "4":
			handleManageKeys(cfgMgr, cfg)
		case "5":
			handleEditFallback(cfgMgr, cfg)
		case "6":
			handleEditUpstream(cfgMgr, cfg)
		case "7":
			handleEditMTU(cfgMgr, cfg)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func handleToggleDNSTT(cfgMgr *config.Manager, cfg *config.Config, pubkey string) {
	newStatus := !cfg.DNSTT.Enable
	if newStatus {
		// Validar se há domínio configurado
		if strings.TrimSpace(cfg.DNSTT.Domain) == "" {
			components.PrintWarning("Aviso: Nenhum domínio configurado. O DNSTT requer uma zona NS apontada para esta VPS.")
			dom := components.Prompt("Digite o domínio do túnel agora (ex: t.seudominio.com)", "")
			if strings.TrimSpace(dom) != "" {
				cfg.DNSTT.Domain = strings.TrimSpace(dom)
			}
		}

		// Se não há chaves criadas, gerar par automaticamente
		if pubkey == "" {
			components.PrintInfo("Gerando par de chaves Noise Curve25519 automaticamente...")
			privHex, pubHex, created, err := system.LoadOrCreateDNSTTKeys("", cfg.DNSTT.PrivkeyFile)
			if err != nil {
				components.PrintError(fmt.Sprintf("Falha ao gerar par de chaves: %v", err))
				components.Pause()
				return
			}
			if created {
				components.PrintSuccess(fmt.Sprintf("Chave gerada e salva em %s!", cfg.DNSTT.PrivkeyFile))
				components.PrintSuccess(fmt.Sprintf("Chave Pública: %s", pubHex))
			}
			_ = privHex
		}

		// Checagem preventiva de porta UDP
		udpPort := parsePortFromUDPAddr(cfg.DNSTT.UDP)
		if udpPort > 0 {
			avail, procInfo := system.CheckUDPPortAvailable(udpPort)
			if !avail {
				components.PrintWarning(fmt.Sprintf("Aviso: A porta UDP %d já está em uso por '%s'.", udpPort, procInfo))
				if udpPort == 53 {
					components.PrintInfo("Dica: Em sistemas com systemd-resolved, desative o listener local em /etc/systemd/resolved.conf (DNSStubListener=no) para liberar a porta 53.")
				}
				if !components.Confirm("Deseja ativar o DNSTT mesmo assim?", true) {
					return
				}
			}
		}
	}

	cfg.DNSTT.Enable = newStatus
	if err := cfgMgr.Save(cfg); err != nil {
		components.PrintError(fmt.Sprintf("Erro ao salvar configuração: %v", err))
	} else {
		if newStatus {
			components.PrintSuccess("Servidor DNSTT ATIVADO na configuração.")
		} else {
			components.PrintSuccess("Servidor DNSTT DESATIVADO na configuração.")
		}
		if system.IsServiceActive(system.ProxyServiceName) {
			if components.Confirm("Deseja reiniciar o serviço proxy para aplicar a alteração agora?", true) {
				_ = system.RestartService(system.ProxyServiceName)
				components.PrintSuccess("Serviço proxy reiniciado.")
			}
		}
	}
	components.Pause()
}

func handleEditDomain(cfgMgr *config.Manager, cfg *config.Config) {
	components.ClearScreen()
	fmt.Printf("\n%s=== CONFIGURAR DOMÍNIO DO TÚNEL DNS (DNSTT) ===%s\n\n", theme.Cyan, theme.Reset)
	fmt.Printf("%sInstrução:%s Configure no seu registrador DNS (ex: Cloudflare):\n", theme.Yellow, theme.Reset)
	fmt.Printf("1. Registro A:  %sns.seudominio.com%s  -> IP da sua VPS\n", theme.White, theme.Reset)
	fmt.Printf("2. Registro NS: %st.seudominio.com%s   -> ns.seudominio.com\n\n", theme.White, theme.Reset)

	newDom := components.Prompt("Domínio do túnel (ex: t.seudominio.com)", cfg.DNSTT.Domain)
	if newDom != "" && newDom != cfg.DNSTT.Domain {
		cfg.DNSTT.Domain = strings.TrimSpace(newDom)
		if err := cfgMgr.Save(cfg); err == nil {
			components.PrintSuccess(fmt.Sprintf("Domínio atualizado para '%s'.", cfg.DNSTT.Domain))
			if system.IsServiceActive(system.ProxyServiceName) && cfg.DNSTT.Enable {
				if components.Confirm("Reiniciar proxy para aplicar novo domínio?", true) {
					_ = system.RestartService(system.ProxyServiceName)
				}
			}
		} else {
			components.PrintError(fmt.Sprintf("Erro ao salvar: %v", err))
		}
		components.Pause()
	}
}

func handleEditUDP(cfgMgr *config.Manager, cfg *config.Config) {
	components.ClearScreen()
	fmt.Printf("\n%s=== ENDEREÇO / PORTA UDP DE ESCUTA ===%s\n\n", theme.Cyan, theme.Reset)
	fmt.Printf("%sPadrão:%s :53 (escuta em todas as interfaces na porta 53)\n", theme.Gray, theme.Reset)
	fmt.Printf("%sOutro exemplo:%s 0.0.0.0:5300\n\n", theme.Gray, theme.Reset)

	newUDP := components.Prompt("Endereço/Porta UDP de escuta", cfg.DNSTT.UDP)
	clean := strings.TrimSpace(newUDP)
	if clean != "" && clean != cfg.DNSTT.UDP {
		port := parsePortFromUDPAddr(clean)
		if port > 0 {
			avail, procInfo := system.CheckUDPPortAvailable(port)
			if !avail {
				components.PrintWarning(fmt.Sprintf("Aviso: A porta UDP %d já está em uso por '%s'.", port, procInfo))
				if !components.Confirm("Deseja aplicar mesmo assim?", false) {
					return
				}
			}
		}
		cfg.DNSTT.UDP = clean
		if err := cfgMgr.Save(cfg); err == nil {
			components.PrintSuccess(fmt.Sprintf("Endereço UDP atualizado para '%s'.", clean))
			if system.IsServiceActive(system.ProxyServiceName) && cfg.DNSTT.Enable {
				if components.Confirm("Reiniciar proxy para aplicar novo listener UDP?", true) {
					_ = system.RestartService(system.ProxyServiceName)
				}
			}
		}
		components.Pause()
	}
}

func handleManageKeys(cfgMgr *config.Manager, cfg *config.Config) {
	for {
		// Carrega par de chaves ativo
		privHex, pubHex, _, _ := system.LoadOrCreateDNSTTKeys(cfg.DNSTT.Privkey, cfg.DNSTT.PrivkeyFile)

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader("GERENCIAMENTO DE CHAVES CRIPTOGRÁFICAS (DNSTT)", theme.Cyan, w)

		components.PrintBoxLine(fmt.Sprintf("%sProtocolo: Noise_NK_25519_ChaChaPoly_BLAKE2s (Curve25519)%s", theme.Gray, theme.Reset), w)
		components.PrintBoxDivider(w)

		if pubHex != "" {
			components.PrintBoxLine(fmt.Sprintf("%sCHAVE PÚBLICA (UTILIZADA NOS APLICATIVOS CLIENTES):%s", theme.Green, theme.Reset), w)
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Yellow, pubHex, theme.Reset), w)
			components.PrintBoxDivider(w)

			fileInfo := cfg.DNSTT.PrivkeyFile
			if fileInfo == "" {
				fileInfo = "[Configurado diretamente no config.json]"
			}
			components.PrintBoxLine(fmt.Sprintf("Arquivo Privkey: %s%s%s", theme.Cyan, fileInfo, theme.Reset), w)

			maskedPriv := "[Oculta]"
			if len(privHex) >= 8 {
				maskedPriv = privHex[:4] + "..." + privHex[len(privHex)-4:]
			}
			components.PrintBoxLine(fmt.Sprintf("Chave Privada:   %s%s%s", theme.DarkGray, maskedPriv, theme.Reset), w)
		} else {
			components.PrintBoxLine(fmt.Sprintf("%sNenhum par de chaves ativo no momento.%s", theme.Red, theme.Reset), w)
		}

		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s1 • Gerar Novo Par de Chaves (Gera nova Chave Pública & Privada)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s2 • Alterar Caminho do Arquivo de Chave (privkey_file)%s", theme.White, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s3 • Definir Chave Privada Hex Manualmente (privkey)%s", theme.White, theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(fmt.Sprintf("%s0 • Voltar ao Menu DNSTT%s", theme.Red, theme.Reset), w)
		components.PrintBoxFooter(w)

		choice := strings.TrimSpace(components.ReadOption("Selecione a opção [0-3]"))
		switch choice {
		case "1":
			if pubHex != "" {
				if !components.Confirm("ATENÇÃO: Gerar uma nova chave tornará inválidas as configurações anteriores dos clientes. Continuar?", false) {
					continue
				}
			}
			newPriv, newPub, err := system.GenerateDNSTTKeypair()
			if err != nil {
				components.PrintError(fmt.Sprintf("Falha ao gerar chave: %v", err))
				components.Pause()
				continue
			}

			keyFile := cfg.DNSTT.PrivkeyFile
			if keyFile == "" {
				keyFile = system.DefaultDNSTTKeyFile
				cfg.DNSTT.PrivkeyFile = keyFile
			}

			if err := system.SavePrivateKeyToFile(newPriv, keyFile); err != nil {
				components.PrintWarning(fmt.Sprintf("Aviso ao salvar arquivo (%v). Salvando chave diretamente no config.json...", err))
				cfg.DNSTT.Privkey = newPriv
			} else {
				cfg.DNSTT.Privkey = "" // Mantém em arquivo
			}

			if err := cfgMgr.Save(cfg); err == nil {
				components.PrintSuccess("Novo par de chaves Curve25519 gerado com sucesso!")
				fmt.Printf("\n%sNova Chave Pública para Clientes:%s\n%s%s%s\n\n", theme.Green, theme.Reset, theme.Yellow, newPub, theme.Reset)
				if system.IsServiceActive(system.ProxyServiceName) && cfg.DNSTT.Enable {
					if components.Confirm("Reiniciar o proxy para carregar a nova chave?", true) {
						_ = system.RestartService(system.ProxyServiceName)
					}
				}
			}
			components.Pause()

		case "2":
			newFile := components.Prompt("Novo caminho do arquivo de chave privada", cfg.DNSTT.PrivkeyFile)
			if newFile != "" && newFile != cfg.DNSTT.PrivkeyFile {
				cfg.DNSTT.PrivkeyFile = strings.TrimSpace(newFile)
				_ = cfgMgr.Save(cfg)
				components.PrintSuccess("Caminho privkey_file atualizado.")
				components.Pause()
			}

		case "3":
			newPriv := components.Prompt("Digite a chave privada Curve25519 (64 caracteres hex)", "")
			cleanPriv := strings.TrimSpace(newPriv)
			if cleanPriv != "" {
				pub, err := system.PubkeyFromPrivkeyHex(cleanPriv)
				if err != nil {
					components.PrintError(fmt.Sprintf("Chave privada inválida: %v", err))
				} else {
					cfg.DNSTT.Privkey = cleanPriv
					_ = cfgMgr.Save(cfg)
					components.PrintSuccess(fmt.Sprintf("Chave privada salva! Chave pública derivada: %s", pub))
				}
				components.Pause()
			}

		case "0", "":
			return
		}
	}
}

func handleEditFallback(cfgMgr *config.Manager, cfg *config.Config) {
	components.ClearScreen()
	fmt.Printf("\n%s=== CONFIGURAR FALLBACK UDP ===%s\n\n", theme.Cyan, theme.Reset)
	fmt.Printf("%sDescrição:%s Endereço UDP para onde pacotes que NÃO sejam consultas DNS do túnel\n", theme.Gray, theme.Reset)
	fmt.Printf("são encaminhados automaticamente (ex: um servidor DNS real ou outro serviço UDP local).\n")
	fmt.Printf("Exemplo: %s127.0.0.1:8888%s ou vazio para desativar.\n\n", theme.White, theme.Reset)

	newFallback := components.Prompt("Endereço UDP de fallback (vazio para desativar)", cfg.DNSTT.Fallback)
	cfg.DNSTT.Fallback = strings.TrimSpace(newFallback)
	if err := cfgMgr.Save(cfg); err == nil {
		components.PrintSuccess("Configuração de fallback atualizada.")
		if system.IsServiceActive(system.ProxyServiceName) && cfg.DNSTT.Enable {
			if components.Confirm("Reiniciar proxy para aplicar alteração de fallback?", true) {
				_ = system.RestartService(system.ProxyServiceName)
			}
		}
	}
	components.Pause()
}

func handleEditUpstream(cfgMgr *config.Manager, cfg *config.Config) {
	components.ClearScreen()
	fmt.Printf("\n%s=== CONFIGURAR UPSTREAM TCP ===%s\n\n", theme.Cyan, theme.Reset)
	fmt.Printf("%sDescrição:%s Endereço TCP para onde o túnel DNSTT despacha conexões.\n", theme.Gray, theme.Reset)
	fmt.Printf("Se deixado vazio, utiliza o pipeline em memória nativo do VTProxy (recomendado).\n")
	fmt.Printf("Exemplo: %s127.0.0.1:22%s (para despachar diretamente para OpenSSH).\n\n", theme.White, theme.Reset)

	newUpstream := components.Prompt("Endereço TCP de upstream (vazio = pipeline interno)", cfg.DNSTT.Upstream)
	cfg.DNSTT.Upstream = strings.TrimSpace(newUpstream)
	if err := cfgMgr.Save(cfg); err == nil {
		components.PrintSuccess("Configuração de upstream atualizada.")
		if system.IsServiceActive(system.ProxyServiceName) && cfg.DNSTT.Enable {
			if components.Confirm("Reiniciar proxy para aplicar alteração de upstream?", true) {
				_ = system.RestartService(system.ProxyServiceName)
			}
		}
	}
	components.Pause()
}

func handleEditMTU(cfgMgr *config.Manager, cfg *config.Config) {
	components.ClearScreen()
	fmt.Printf("\n%s=== CONFIGURAR MTU DO TÚNEL DNS ===%s\n\n", theme.Cyan, theme.Reset)
	fmt.Printf("%sPadrão recomendado:%s 1232 (valor padrão DNS EDNS0 seguro para evitar fragmentação UDP)\n\n", theme.Gray, theme.Reset)

	resp := components.Prompt("Tamanho do MTU DNS (512 a 4096)", strconv.Itoa(cfg.DNSTT.MTU))
	if val, err := strconv.Atoi(strings.TrimSpace(resp)); err == nil && val >= 512 && val <= 4096 {
		cfg.DNSTT.MTU = val
		if err := cfgMgr.Save(cfg); err == nil {
			components.PrintSuccess(fmt.Sprintf("MTU atualizado para %d bytes.", val))
			if system.IsServiceActive(system.ProxyServiceName) && cfg.DNSTT.Enable {
				if components.Confirm("Reiniciar proxy para aplicar novo MTU?", true) {
					_ = system.RestartService(system.ProxyServiceName)
				}
			}
		}
	} else {
		components.PrintError("Valor de MTU inválido. Deve ser entre 512 e 4096.")
	}
	components.Pause()
}

// parsePortFromUDPAddr extrai o número da porta de uma string como ":53" ou "0.0.0.0:5300"
func parsePortFromUDPAddr(addr string) int {
	clean := strings.TrimSpace(addr)
	if clean == "" {
		return 53
	}
	idx := strings.LastIndex(clean, ":")
	if idx >= 0 {
		portStr := clean[idx+1:]
		if port, err := strconv.Atoi(portStr); err == nil {
			return port
		}
	}
	if port, err := strconv.Atoi(clean); err == nil {
		return port
	}
	return 0
}

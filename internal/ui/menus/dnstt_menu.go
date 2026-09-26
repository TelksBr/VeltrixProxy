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
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
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

		currentPubkey := dnsttCurrentPubkey(cfg)

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("dnstt_menu_title"), theme.Cyan, w)

		domainDisplay := cfg.DNSTT.Domain
		if domainDisplay == "" {
			domainDisplay = i18n.T("dnstt_not_configured")
		}
		pubkeyDisplay := currentPubkey
		if pubkeyDisplay == "" {
			pubkeyDisplay = i18n.T("dnstt_no_key")
		} else if len(pubkeyDisplay) > 28 {
			pubkeyDisplay = pubkeyDisplay[:12] + "..." + pubkeyDisplay[len(pubkeyDisplay)-12:]
		}
		fallbackDisplay := cfg.DNSTT.Fallback
		if fallbackDisplay == "" {
			fallbackDisplay = i18n.T("dnstt_fallback_off")
		}
		upstreamDisplay := cfg.DNSTT.Upstream
		if upstreamDisplay == "" {
			upstreamDisplay = i18n.T("dnstt_native_pipeline")
		}

		info := func(label, value string) {
			components.PrintBoxLine(fmt.Sprintf("%s• %s:%s %s", theme.White, label, theme.Reset, value), w)
		}
		info("DNSTT", fmt.Sprintf("%s  %s│ UDP:%s %s", featureBadge(cfg.DNSTT.Enable), theme.DarkGray, theme.Reset, valueBadge(cfg.DNSTT.UDP)))
		info(i18n.T("dnstt_label_domain"), valueBadge(domainDisplay))
		info(i18n.T("dnstt_label_pubkey"), theme.Yellow+pubkeyDisplay+theme.Reset)
		info("Fallback", fmt.Sprintf("%s  %s│ MTU:%s %s", valueBadge(fallbackDisplay), theme.DarkGray, theme.Reset, valueBadge(cfg.DNSTT.MTU)))
		info("Upstream", valueBadge(upstreamDisplay))
		components.PrintBoxDivider(w)

		components.PrintBoxLine(menuItem("1", i18n.T("dnstt_opt_toggle"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("dnstt_opt_domain"), ""), w)
		components.PrintBoxLine(menuItem("3", i18n.T("dnstt_opt_keys"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("4", i18n.T("dnstt_opt_udp"), ""), w)
		components.PrintBoxLine(menuItem("5", i18n.T("dnstt_opt_fallback"), ""), w)
		components.PrintBoxLine(menuItem("6", i18n.T("dnstt_opt_upstream"), ""), w)
		components.PrintBoxLine(menuItem("7", i18n.T("dnstt_opt_mtu"), ""), w)
		components.PrintBoxLine(menuItem("8", i18n.T("dnstt_opt_free_port53"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-8") {
		case "1":
			handleToggleDNSTT(cfgMgr, cfg, currentPubkey)
		case "2":
			handleEditDomain(cfgMgr, cfg)
		case "3":
			handleManageKeys(cfgMgr, cfg)
		case "4":
			handleEditUDP(cfgMgr, cfg)
		case "5":
			handleEditFallback(cfgMgr, cfg)
		case "6":
			handleEditUpstream(cfgMgr, cfg)
		case "7":
			handleEditMTU(cfgMgr, cfg)
		case "8":
			handleFreePort53()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func dnsttCurrentPubkey(cfg *config.Config) string {
	if cfg.DNSTT.Privkey != "" {
		if pub, err := system.PubkeyFromPrivkeyHex(cfg.DNSTT.Privkey); err == nil {
			return pub
		}
		return ""
	}
	if cfg.DNSTT.PrivkeyFile != "" {
		if priv, err := system.ReadPrivateKeyFromFile(cfg.DNSTT.PrivkeyFile); err == nil {
			if pub, err := system.PubkeyFromPrivkeyHex(priv); err == nil {
				return pub
			}
		}
	}
	return ""
}

func dnsttScreenTitle(key string) {
	components.ClearScreen()
	fmt.Printf("\n%s=== %s ===%s\n\n", theme.Cyan, i18n.T(key), theme.Reset)
}

// confirmDNSTTUDPPort warns when the UDP port is busy and, for :53 held by
// systemd-resolved, offers to free it. Returns whether to proceed.
func confirmDNSTTUDPPort(port int, confirmKey string) bool {
	if port <= 0 {
		return true
	}
	inUse, procInfo := system.IsPortInUseByOther("udp", port)
	if !inUse {
		return true
	}
	components.PrintWarning(i18n.T("port_in_use_udp", port, procInfo))
	proc := strings.ToLower(procInfo)
	isResolved := strings.Contains(proc, "resolved") || strings.Contains(proc, "desconhecido")
	if port == 53 && isResolved && components.Confirm(i18n.T("dnstt_confirm_free53"), true) {
		err := system.ReleasePort53FromSystemdResolved()
		if err == nil {
			components.PrintSuccess(i18n.T("dnstt_port53_freed"))
			return true
		}
		components.PrintError(i18n.T("dnstt_port53_failed", err))
	}
	return components.Confirm(i18n.T(confirmKey), false)
}

func handleToggleDNSTT(cfgMgr *config.Manager, cfg *config.Config, pubkey string) {
	newStatus, changed := components.ConfirmToggle(i18n.T("toggle_dnstt_on"), i18n.T("toggle_dnstt_off"), cfg.DNSTT.Enable)
	if !changed {
		components.PrintInfo(i18n.T("confirm_no_change", "dnstt.enable", cfg.DNSTT.Enable))
		components.Pause()
		return
	}
	if newStatus {
		if strings.TrimSpace(cfg.DNSTT.Domain) == "" {
			components.PrintWarning(i18n.T("dnstt_warn_no_domain"))
			if dom := strings.TrimSpace(components.Prompt(i18n.T("dnstt_prompt_domain"), "")); dom != "" {
				cfg.DNSTT.Domain = dom
			}
		}

		if pubkey == "" {
			components.PrintInfo(i18n.T("dnstt_generating_keys"))
			_, pubHex, created, err := system.LoadOrCreateDNSTTKeys("", cfg.DNSTT.PrivkeyFile)
			if err != nil {
				components.PrintError(i18n.T("dnstt_keygen_failed", err))
				components.Pause()
				return
			}
			if created {
				components.PrintSuccess(i18n.T("dnstt_key_saved", cfg.DNSTT.PrivkeyFile))
				components.PrintSuccess(i18n.T("dnstt_pubkey", pubHex))
			}
		}

		if !confirmDNSTTUDPPort(parsePortFromUDPAddr(cfg.DNSTT.UDP), "dnstt_confirm_enable_anyway") {
			return
		}
	}

	cfg.DNSTT.Enable = newStatus
	if err := cfgMgr.Save(cfg); err != nil {
		components.PrintError(i18n.T("save_failed", err))
	} else if newStatus {
		components.PrintSuccess(i18n.T("toggle_enabled", "dnstt.enable"))
	} else {
		components.PrintSuccess(i18n.T("toggle_disabled", "dnstt.enable"))
	}
	components.Pause()
}

func handleEditDomain(cfgMgr *config.Manager, cfg *config.Config) {
	dnsttScreenTitle("dnstt_domain_title")
	fmt.Printf("%s%s%s\n", theme.Yellow, i18n.T("dnstt_domain_instr"), theme.Reset)
	fmt.Printf("1. A:  %sns.seudominio.com%s  -> %s\n", theme.White, theme.Reset, i18n.T("dnstt_domain_vps_ip"))
	fmt.Printf("2. NS: %st.seudominio.com%s   -> ns.seudominio.com\n\n", theme.White, theme.Reset)

	newDom := strings.TrimSpace(components.Prompt(i18n.T("dnstt_prompt_domain"), cfg.DNSTT.Domain))
	if newDom != "" && newDom != cfg.DNSTT.Domain {
		cfg.DNSTT.Domain = newDom
		saveField(cfgMgr, cfg, "dnstt.domain")
		components.Pause()
	}
}

func handleEditUDP(cfgMgr *config.Manager, cfg *config.Config) {
	dnsttScreenTitle("dnstt_udp_title")
	fmt.Printf("%s%s%s\n\n", theme.Gray, i18n.T("dnstt_udp_hint"), theme.Reset)

	clean := strings.TrimSpace(components.Prompt(i18n.T("dnstt_prompt_udp"), cfg.DNSTT.UDP))
	if clean == "" || clean == cfg.DNSTT.UDP {
		return
	}
	if !confirmDNSTTUDPPort(parsePortFromUDPAddr(clean), "confirm_apply_anyway") {
		return
	}
	cfg.DNSTT.UDP = clean
	saveField(cfgMgr, cfg, "dnstt.udp")
	components.Pause()
}

func handleFreePort53() {
	dnsttScreenTitle("dnstt_free53_title")
	fmt.Printf("%s%s%s\n", theme.Yellow, i18n.T("dnstt_free53_actions"), theme.Reset)
	fmt.Println(i18n.T("dnstt_free53_steps"))
	fmt.Println()

	if inUse, proc := system.IsPortInUseByOther("udp", 53); !inUse {
		components.PrintSuccess(i18n.T("dnstt_free53_already_free"))
		if !components.Confirm(i18n.T("dnstt_free53_confirm_anyway"), true) {
			return
		}
	} else {
		fmt.Printf("%s%s%s\n\n", theme.Yellow, i18n.T("port_in_use_udp", 53, proc), theme.Reset)
		if !components.Confirm(i18n.T("dnstt_free53_confirm"), true) {
			return
		}
	}

	components.PrintInfo(i18n.T("dnstt_free53_applying"))
	if err := system.ReleasePort53FromSystemdResolved(); err != nil {
		components.PrintError(i18n.T("dnstt_port53_failed", err))
	} else {
		components.PrintSuccess(i18n.T("dnstt_free53_done"))
	}
	components.Pause()
}

func handleManageKeys(cfgMgr *config.Manager, cfg *config.Config) {
	for {
		privHex, pubHex, _, _ := system.LoadOrCreateDNSTTKeys(cfg.DNSTT.Privkey, cfg.DNSTT.PrivkeyFile)

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("dnstt_keys_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%sNoise_NK_25519_ChaChaPoly_BLAKE2s (Curve25519)%s", theme.Gray, theme.Reset), w)
		components.PrintBoxDivider(w)

		if pubHex != "" {
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Green, i18n.T("dnstt_keys_pub_header"), theme.Reset), w)
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Yellow, pubHex, theme.Reset), w)
			components.PrintBoxDivider(w)

			fileInfo := cfg.DNSTT.PrivkeyFile
			if fileInfo == "" {
				fileInfo = i18n.T("dnstt_keys_in_json")
			}
			components.PrintBoxLine(fmt.Sprintf("privkey_file: %s", valueBadge(fileInfo)), w)

			maskedPriv := i18n.T("dnstt_keys_hidden")
			if len(privHex) >= 8 {
				maskedPriv = privHex[:4] + "..." + privHex[len(privHex)-4:]
			}
			components.PrintBoxLine(fmt.Sprintf("privkey:      %s%s%s", theme.DarkGray, maskedPriv, theme.Reset), w)
		} else {
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Red, i18n.T("dnstt_keys_none"), theme.Reset), w)
		}

		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("dnstt_keys_opt_generate"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("dnstt_keys_opt_file"), ""), w)
		components.PrintBoxLine(menuItem("3", i18n.T("dnstt_keys_opt_manual"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-3") {
		case "1":
			if pubHex != "" && !components.Confirm(i18n.T("dnstt_keys_confirm_regen"), false) {
				continue
			}
			newPriv, newPub, err := system.GenerateDNSTTKeypair()
			if err != nil {
				components.PrintError(i18n.T("dnstt_keygen_failed", err))
				components.Pause()
				continue
			}
			keyFile := cfg.DNSTT.PrivkeyFile
			if keyFile == "" {
				keyFile = system.DefaultDNSTTKeyFile
				cfg.DNSTT.PrivkeyFile = keyFile
			}
			if err := system.SavePrivateKeyToFile(newPriv, keyFile); err != nil {
				components.PrintWarning(i18n.T("dnstt_keys_save_warn", err))
				cfg.DNSTT.Privkey = newPriv
			} else {
				cfg.DNSTT.Privkey = ""
			}
			if err := cfgMgr.Save(cfg); err != nil {
				components.PrintError(i18n.T("save_failed", err))
			} else {
				components.PrintSuccess(i18n.T("dnstt_keys_generated"))
				fmt.Printf("\n%s%s%s\n%s%s%s\n\n", theme.Green, i18n.T("dnstt_keys_new_pub"), theme.Reset, theme.Yellow, newPub, theme.Reset)
			}
			components.Pause()
		case "2":
			newFile := strings.TrimSpace(components.Prompt(i18n.T("dnstt_keys_opt_file"), cfg.DNSTT.PrivkeyFile))
			if newFile != "" && newFile != cfg.DNSTT.PrivkeyFile {
				cfg.DNSTT.PrivkeyFile = newFile
				saveField(cfgMgr, cfg, "dnstt.privkey_file")
				components.Pause()
			}
		case "3":
			cleanPriv := strings.TrimSpace(components.Prompt(i18n.T("dnstt_keys_prompt_manual"), ""))
			if cleanPriv != "" {
				if pub, err := system.PubkeyFromPrivkeyHex(cleanPriv); err != nil {
					components.PrintError(i18n.T("dnstt_keys_invalid", err))
				} else {
					cfg.DNSTT.Privkey = cleanPriv
					saveField(cfgMgr, cfg, "dnstt.privkey")
					components.PrintInfo(i18n.T("dnstt_pubkey", pub))
				}
				components.Pause()
			}
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func handleEditFallback(cfgMgr *config.Manager, cfg *config.Config) {
	dnsttScreenTitle("dnstt_fallback_title")
	fmt.Printf("%s%s%s\n\n", theme.Gray, i18n.T("dnstt_fallback_desc"), theme.Reset)

	cfg.DNSTT.Fallback = strings.TrimSpace(components.Prompt(i18n.T("dnstt_prompt_fallback"), cfg.DNSTT.Fallback))
	saveField(cfgMgr, cfg, "dnstt.fallback")
	components.Pause()
}

func handleEditUpstream(cfgMgr *config.Manager, cfg *config.Config) {
	dnsttScreenTitle("dnstt_upstream_title")
	fmt.Printf("%s%s%s\n\n", theme.Gray, i18n.T("dnstt_upstream_desc"), theme.Reset)

	cfg.DNSTT.Upstream = strings.TrimSpace(components.Prompt(i18n.T("dnstt_prompt_upstream"), cfg.DNSTT.Upstream))
	saveField(cfgMgr, cfg, "dnstt.upstream")
	components.Pause()
}

func handleEditMTU(cfgMgr *config.Manager, cfg *config.Config) {
	dnsttScreenTitle("dnstt_mtu_title")
	fmt.Printf("%s%s%s\n\n", theme.Gray, i18n.T("dnstt_mtu_desc"), theme.Reset)

	resp := components.Prompt(i18n.T("dnstt_prompt_mtu"), strconv.Itoa(cfg.DNSTT.MTU))
	if val, err := strconv.Atoi(strings.TrimSpace(resp)); err == nil && val >= 512 && val <= 4096 {
		cfg.DNSTT.MTU = val
		saveField(cfgMgr, cfg, "dnstt.mtu")
	} else {
		components.PrintError(i18n.T("dnstt_mtu_invalid"))
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

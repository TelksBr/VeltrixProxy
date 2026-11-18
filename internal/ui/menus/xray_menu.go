package menus

import (
	"context"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowXrayMenu is the Xray hub: share link first, then enable and grouped settings.
func ShowXrayMenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.Xray.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_menu_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("xray_hint"), theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• Path:%s %s %s│ H3:%s %s %s│ Sync:%s %s",
			theme.Gray, theme.Reset, valueBadge(cfg.Xray.Path),
			theme.DarkGray, theme.Reset, featureBadge(cfg.Xray.H3),
			theme.DarkGray, theme.Reset, featureBadge(cfg.Xray.SyncPasswd),
		), w)
		components.PrintBoxLine(fmt.Sprintf("%s• %s:%s %s",
			theme.Gray, i18n.T("xray_status_protocols"), theme.Reset, valueBadge(strings.Join(cfg.Xray.Protocols, ",")),
		), w)
		components.PrintBoxLine(fmt.Sprintf("%s• %s:%s %s",
			theme.Gray, i18n.T("xray_status_transports"), theme.Reset, valueBadge(strings.Join(cfg.Xray.Transports, ",")),
		), w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_share"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_enable"), featureBadge(cfg.Xray.Enable)), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_general"), ""), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_routes_group"), ""), w)
		components.PrintBoxLine(menuItem("5", i18n.T("xray_opt_listeners_group"), ""), w)
		components.PrintBoxLine(menuItem("6", i18n.T("xray_opt_native_group"), featureBadge(cfg.Xray.SyncPasswd)), w)
		components.PrintBoxLine(menuItem("7", i18n.T("xray_opt_tls_group"), ""), w)
		components.PrintBoxLine(menuItem("8", i18n.T("xray_opt_legacy_group"), featureBadge(cfg.Xray.Legacy.Enable)), w)
		printMenuBack(w)

		switch readMenuOption("0-8") {
		case "1":
			showXrayShareWizard(cfg)
		case "2":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.Enable, func(v bool) { cfg.Xray.Enable = v },
				i18n.T("toggle_xray_on"), i18n.T("toggle_xray_off"), "xray.enable")
		case "3":
			showXrayGeneralSubmenu(cfgMgr)
		case "4":
			showXrayRoutesSubmenu(cfgMgr)
		case "5":
			showXrayListenersSubmenu(cfgMgr)
		case "6":
			showXrayNativeSubmenu(cfgMgr)
		case "7":
			showXrayTLSSubmenu(cfgMgr)
		case "8":
			showXrayLegacySubmenu(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func promptOptionalValue(label, current string) string {
	hintLabel := label + " " + i18n.T("clear_with_dash_hint")
	resp := strings.TrimSpace(components.Prompt(hintLabel, current))
	switch strings.ToLower(resp) {
	case "-", "none", "off", "clear":
		return ""
	default:
		return resp
	}
}

func showXrayGeneralSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.Xray.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_general_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_path"), valueBadge(cfg.Xray.Path)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_protocols"), valueBadge(strings.Join(cfg.Xray.Protocols, ","))), w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_transports"), valueBadge(strings.Join(cfg.Xray.Transports, ","))), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_grpc_service"), valueBadge(cfg.Xray.GRPCService)), w)
		components.PrintBoxLine(menuItem("5", i18n.T("xray_opt_h3"), featureBadge(cfg.Xray.H3)), w)
		components.PrintBoxLine(menuItem("6", i18n.T("xray_opt_h3_config"), valueBadge(displayOrEmpty(cfg.Xray.H3Config))), w)
		printMenuBack(w)

		switch readMenuOption("0-6") {
		case "1":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_path"), cfg.Xray.Path))
			if resp != "" {
				if !strings.HasPrefix(resp, "/") {
					resp = "/" + resp
				}
				cfg.Xray.Path = resp
				saveField(cfgMgr, cfg, "xray.path")
			}
			components.Pause()
		case "2":
			resp := components.Prompt(i18n.T("xray_opt_protocols")+" (vless,vmess,trojan,socks,http,shadowsocks | all)", strings.Join(cfg.Xray.Protocols, ","))
			cfg.Xray.Protocols = splitCSV(resp)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.protocols")
			components.Pause()
		case "3":
			resp := components.Prompt(i18n.T("xray_opt_transports")+" (ws,splithttp,httpupgrade,grpc,tcp,mkcp,hysteria | all)", strings.Join(cfg.Xray.Transports, ","))
			cfg.Xray.Transports = splitCSV(resp)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.transports")
			components.Pause()
		case "4":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_grpc_service"), cfg.Xray.GRPCService))
			if resp != "" {
				cfg.Xray.GRPCService = resp
				saveField(cfgMgr, cfg, "xray.grpc_service")
			}
			components.Pause()
		case "5":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.H3, func(v bool) { cfg.Xray.H3 = v },
				i18n.T("toggle_xray_h3_on"), i18n.T("toggle_xray_h3_off"), "xray.h3")
		case "6":
			cfg.Xray.H3Config = promptOptionalValue(i18n.T("xray_opt_h3_config"), cfg.Xray.H3Config)
			saveField(cfgMgr, cfg, "xray.h3_config")
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXrayRoutesSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.Xray.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_routes_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("xray_routes_hint"), theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_path"), valueBadge(cfg.Xray.Path)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_ws_path"), valueBadge(displayOrEmpty(cfg.Xray.WSPath))), w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_splithttp_path"), valueBadge(displayOrEmpty(cfg.Xray.SplitHTTPPath))), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_httpupgrade_path"), valueBadge(displayOrEmpty(cfg.Xray.HTTPUpgradePath))), w)
		components.PrintBoxLine(menuItem("5", i18n.T("xray_opt_splithttp_config"), valueBadge(displayOrEmpty(cfg.Xray.SplitHTTPConfig))), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_path"), cfg.Xray.Path))
			if resp != "" {
				cfg.Xray.Path = resp
				cfg.Xray.Normalize()
				saveField(cfgMgr, cfg, "xray.path")
			}
			components.Pause()
		case "2":
			cfg.Xray.WSPath = promptOptionalValue(i18n.T("xray_opt_ws_path"), cfg.Xray.WSPath)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.ws_path")
			components.Pause()
		case "3":
			cfg.Xray.SplitHTTPPath = promptOptionalValue(i18n.T("xray_opt_splithttp_path"), cfg.Xray.SplitHTTPPath)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.splithttp_path")
			components.Pause()
		case "4":
			cfg.Xray.HTTPUpgradePath = promptOptionalValue(i18n.T("xray_opt_httpupgrade_path"), cfg.Xray.HTTPUpgradePath)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.httpupgrade_path")
			components.Pause()
		case "5":
			val := promptOptionalValue(i18n.T("xray_opt_splithttp_config"), cfg.Xray.SplitHTTPConfig)
			if val != "" && !cfg.Xray.AllowsTransport("splithttp") {
				cfg.Xray.Transports = append(cfg.Xray.Transports, "splithttp")
			}
			cfg.Xray.SplitHTTPConfig = val
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.splithttp_config")
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXrayListenersSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.Xray.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_listeners_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_udp_listen"), valueBadge(displayOrEmpty(cfg.Xray.UDPListen))), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_kcp_listen"), valueBadge(displayOrEmpty(cfg.Xray.KCPListen))), w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_kcp_tls"), featureBadge(cfg.Xray.KCPTLS)), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_kcp_cert"), valueBadge(displayOrEmpty(cfg.Xray.KCPCertFile))), w)
		components.PrintBoxLine(menuItem("5", i18n.T("xray_opt_kcp_key"), valueBadge(displayOrEmpty(cfg.Xray.KCPKeyFile))), w)
		components.PrintBoxLine(menuItem("6", i18n.T("xray_opt_kcp_config"), valueBadge(displayOrEmpty(cfg.Xray.KCPConfig))), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("7", i18n.T("xray_opt_hysteria_listen"), valueBadge(displayOrEmpty(cfg.Xray.HysteriaListen))), w)
		components.PrintBoxLine(menuItem("8", i18n.T("xray_opt_hysteria_config"), valueBadge(displayOrEmpty(cfg.Xray.HysteriaConfig))), w)
		components.PrintBoxLine(menuItem("9", i18n.T("xray_opt_udp_finalmask"), valueBadge(displayOrEmpty(cfg.Xray.UDPFinalMaskConfig))), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("T", i18n.T("xray_opt_tcp_fm_listen"), valueBadge(displayOrEmpty(cfg.Xray.TCPFinalMaskListen))), w)
		components.PrintBoxLine(menuItem("F", i18n.T("xray_opt_tcp_fm_config"), valueBadge(displayOrEmpty(cfg.Xray.TCPFinalMaskConfig))), w)
		printMenuBack(w)

		switch readMenuOption("0-9/T/F") {
		case "1":
			val := promptOptionalValue(i18n.T("xray_opt_udp_listen")+" (ex: :8388)", cfg.Xray.UDPListen)
			if p := system.ParseListenPort(val); p > 0 && val != cfg.Xray.UDPListen && !confirmPortInUse("udp", p) {
				continue
			}
			if val != "" && !cfg.Xray.AllowsProtocol("shadowsocks") {
				cfg.Xray.Protocols = append(cfg.Xray.Protocols, "shadowsocks")
			}
			cfg.Xray.UDPListen = val
			saveField(cfgMgr, cfg, "xray.udp_listen")
			components.Pause()
		case "2":
			val := promptOptionalValue(i18n.T("xray_opt_kcp_listen")+" (ex: :4000)", cfg.Xray.KCPListen)
			if p := system.ParseListenPort(val); p > 0 && val != cfg.Xray.KCPListen && !confirmPortInUse("udp", p) {
				continue
			}
			if val != "" && !cfg.Xray.AllowsTransport("mkcp") {
				cfg.Xray.Transports = append(cfg.Xray.Transports, "mkcp")
			}
			if val == "" && cfg.Xray.KCPConfig != "" {
				cfg.Xray.KCPConfig = ""
			}
			cfg.Xray.KCPListen = val
			saveField(cfgMgr, cfg, "xray.kcp_listen")
			components.Pause()
		case "3":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.KCPTLS, func(v bool) { cfg.Xray.KCPTLS = v },
				i18n.T("toggle_xray_kcp_tls_on"), i18n.T("toggle_xray_kcp_tls_off"), "xray.kcp_tls")
		case "4":
			cfg.Xray.KCPCertFile = promptOptionalValue(i18n.T("xray_opt_kcp_cert"), cfg.Xray.KCPCertFile)
			saveField(cfgMgr, cfg, "xray.kcp_cert_file")
			components.Pause()
		case "5":
			cfg.Xray.KCPKeyFile = promptOptionalValue(i18n.T("xray_opt_kcp_key"), cfg.Xray.KCPKeyFile)
			saveField(cfgMgr, cfg, "xray.kcp_key_file")
			components.Pause()
		case "6":
			val := promptOptionalValue(i18n.T("xray_opt_kcp_config"), cfg.Xray.KCPConfig)
			if val != "" && strings.TrimSpace(cfg.Xray.KCPListen) == "" {
				components.PrintWarning(i18n.T("xray_warn_kcp_requires_listen"))
				components.Pause()
				continue
			}
			cfg.Xray.KCPConfig = val
			saveField(cfgMgr, cfg, "xray.kcp_config")
			components.Pause()
		case "7":
			val := promptOptionalValue(i18n.T("xray_opt_hysteria_listen")+" (ex: :44443)", cfg.Xray.HysteriaListen)
			if p := system.ParseListenPort(val); p > 0 && val != cfg.Xray.HysteriaListen && !confirmPortInUse("udp", p) {
				continue
			}
			if val != "" && !cfg.Xray.AllowsTransport("hysteria") {
				cfg.Xray.Transports = append(cfg.Xray.Transports, "hysteria")
			}
			if val == "" && cfg.Xray.HysteriaConfig != "" {
				cfg.Xray.HysteriaConfig = ""
			}
			cfg.Xray.HysteriaListen = val
			saveField(cfgMgr, cfg, "xray.hysteria_listen")
			components.Pause()
		case "8":
			val := promptOptionalValue(i18n.T("xray_opt_hysteria_config"), cfg.Xray.HysteriaConfig)
			if val != "" && strings.TrimSpace(cfg.Xray.HysteriaListen) == "" {
				components.PrintWarning(i18n.T("xray_warn_hysteria_requires_listen"))
				components.Pause()
				continue
			}
			cfg.Xray.HysteriaConfig = val
			saveField(cfgMgr, cfg, "xray.hysteria_config")
			components.Pause()
		case "9":
			cfg.Xray.UDPFinalMaskConfig = promptOptionalValue(i18n.T("xray_opt_udp_finalmask"), cfg.Xray.UDPFinalMaskConfig)
			saveField(cfgMgr, cfg, "xray.udp_finalmask_config")
			components.Pause()
		case "t":
			val := promptOptionalValue(i18n.T("xray_opt_tcp_fm_listen")+" (ex: :2443)", cfg.Xray.TCPFinalMaskListen)
			if p := system.ParseListenPort(val); p > 0 && val != cfg.Xray.TCPFinalMaskListen && !confirmPortInUse("tcp", p) {
				continue
			}
			if val != "" && strings.TrimSpace(cfg.Xray.TCPFinalMaskConfig) == "" {
				cfgFile := promptOptionalValue(i18n.T("xray_opt_tcp_fm_config"), cfg.Xray.TCPFinalMaskConfig)
				if cfgFile == "" {
					components.PrintWarning(i18n.T("xray_warn_tcp_fm_requires_config"))
					components.Pause()
					continue
				}
				cfg.Xray.TCPFinalMaskConfig = cfgFile
			}
			cfg.Xray.TCPFinalMaskListen = val
			saveField(cfgMgr, cfg, "xray.tcp_finalmask_listen")
			components.Pause()
		case "f":
			val := promptOptionalValue(i18n.T("xray_opt_tcp_fm_config"), cfg.Xray.TCPFinalMaskConfig)
			if val == "" && strings.TrimSpace(cfg.Xray.TCPFinalMaskListen) != "" {
				cfg.Xray.TCPFinalMaskListen = ""
			}
			cfg.Xray.TCPFinalMaskConfig = val
			saveField(cfgMgr, cfg, "xray.tcp_finalmask_config")
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXrayNativeSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.Xray.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_native_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("xray_native_hint"), theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_sync_passwd"), featureBadge(cfg.Xray.SyncPasswd)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_native_config"), valueBadge(displayOrEmpty(cfg.Xray.NativeConfig))), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_ss2022_listen"), valueBadge(displayOrEmpty(cfg.Xray.SS2022Listen))), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_ss2022_method"), valueBadge(cfg.Xray.SS2022Method)), w)
		keyPreview := displayOrEmpty(cfg.Xray.SS2022MasterKey)
		if len(cfg.Xray.SS2022MasterKey) > 12 {
			keyPreview = cfg.Xray.SS2022MasterKey[:8] + "…"
		}
		components.PrintBoxLine(menuItem("5", i18n.T("xray_opt_ss2022_key"), valueBadge(keyPreview)), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("6", i18n.T("xray_opt_masque_listen"), valueBadge(displayOrEmpty(cfg.Xray.MASQUEListen))), w)
		components.PrintBoxLine(menuItem("7", i18n.T("xray_opt_masque_subnet"), valueBadge(cfg.Xray.MASQUESubnet)), w)
		components.PrintBoxLine(menuItem("8", i18n.T("xray_opt_masque_path"), valueBadge(cfg.Xray.MASQUEPath)), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("9", i18n.T("xray_opt_wg_config"), valueBadge(displayOrEmpty(cfg.Xray.WireGuardConfig))), w)
		components.PrintBoxLine(menuItem("X", i18n.T("xray_opt_xdrive_config"), valueBadge(displayOrEmpty(cfg.Xray.XDriveConfig))), w)
		components.PrintBoxLine(menuItem("Q", i18n.T("xray_opt_traffic_file"), valueBadge(cfg.Xray.TrafficUsageFile)), w)
		printMenuBack(w)

		switch readMenuOption("0-9/X/Q") {
		case "1":
			if cfg.Xray.SyncPasswd && cfg.Xray.RequiresSyncPasswd() {
				components.PrintWarning(i18n.T("xray_warn_sync_required"))
				components.Pause()
				continue
			}
			if !cfg.Xray.SyncPasswd && !cfg.Xray.CanEnableSyncPasswd() {
				components.PrintWarning(i18n.T("xray_warn_sync_needs_target"))
				components.Pause()
				continue
			}
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.SyncPasswd, func(v bool) { cfg.Xray.SyncPasswd = v },
				i18n.T("toggle_xray_sync_on"), i18n.T("toggle_xray_sync_off"), "xray.sync_passwd")
		case "2":
			cfg.Xray.NativeConfig = promptOptionalValue(i18n.T("xray_opt_native_config"), cfg.Xray.NativeConfig)
			saveField(cfgMgr, cfg, "xray.native_config")
			components.Pause()
		case "3":
			val := promptOptionalValue(i18n.T("xray_opt_ss2022_listen")+" (ex: 0.0.0.0:8388)", cfg.Xray.SS2022Listen)
			if p := system.ParseListenPort(val); p > 0 && val != cfg.Xray.SS2022Listen {
				if !confirmPortInUse("tcp", p) || !confirmPortInUse("udp", p) {
					continue
				}
			}
			if val != "" && strings.TrimSpace(cfg.Xray.SS2022MasterKey) == "" {
				genKey := config.GenerateSS2022MasterKey(cfg.Xray.SS2022Method)
				keyInput := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_ss2022_key"), genKey))
				if keyInput == "" {
					keyInput = genKey
				}
				cfg.Xray.SS2022MasterKey = keyInput
			}
			cfg.Xray.SS2022Listen = val
			if val != "" {
				cfg.Xray.SyncPasswd = true
			}
			saveField(cfgMgr, cfg, "xray.ss2022_listen")
			components.Pause()
		case "4":
			fmt.Printf("\n%s%s%s\n", theme.White, i18n.T("xray_opt_ss2022_method"), theme.Reset)
			fmt.Printf("  %s1 • 2022-blake3-aes-128-gcm (16B key)%s\n", theme.Cyan, theme.Reset)
			fmt.Printf("  %s2 • 2022-blake3-aes-256-gcm (32B key)%s\n", theme.Cyan, theme.Reset)
			switch components.ReadOption(i18n.T("xray_share_pick")) {
			case "2":
				cfg.Xray.SS2022Method = "2022-blake3-aes-256-gcm"
			default:
				cfg.Xray.SS2022Method = "2022-blake3-aes-128-gcm"
			}
			if components.Confirm(i18n.T("xray_confirm_regen_ss2022_key"), cfg.Xray.SS2022MasterKey == "") {
				cfg.Xray.SS2022MasterKey = config.GenerateSS2022MasterKey(cfg.Xray.SS2022Method)
				components.PrintInfo("Master Key: " + cfg.Xray.SS2022MasterKey)
			}
			saveField(cfgMgr, cfg, "xray.ss2022_method")
			components.Pause()
		case "5":
			defKey := cfg.Xray.SS2022MasterKey
			if defKey == "" {
				defKey = config.GenerateSS2022MasterKey(cfg.Xray.SS2022Method)
			}
			cfg.Xray.SS2022MasterKey = promptOptionalValue(i18n.T("xray_opt_ss2022_key"), defKey)
			saveField(cfgMgr, cfg, "xray.ss2022_master_key")
			components.Pause()
		case "6":
			val := promptOptionalValue(i18n.T("xray_opt_masque_listen")+" (ex: 0.0.0.0:8443)", cfg.Xray.MASQUEListen)
			if p := system.ParseListenPort(val); p > 0 && val != cfg.Xray.MASQUEListen && !confirmPortInUse("udp", p) {
				continue
			}
			cfg.Xray.MASQUEListen = val
			if val != "" {
				cfg.Xray.SyncPasswd = true
			}
			saveField(cfgMgr, cfg, "xray.masque_listen")
			components.Pause()
		case "7":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_masque_subnet"), cfg.Xray.MASQUESubnet))
			if resp != "" {
				cfg.Xray.MASQUESubnet = resp
				saveField(cfgMgr, cfg, "xray.masque_subnet")
			}
			components.Pause()
		case "8":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_masque_path"), cfg.Xray.MASQUEPath))
			if resp != "" {
				cfg.Xray.MASQUEPath = resp
				saveField(cfgMgr, cfg, "xray.masque_path")
			}
			components.Pause()
		case "9":
			val := promptOptionalValue(i18n.T("xray_opt_wg_config"), cfg.Xray.WireGuardConfig)
			cfg.Xray.WireGuardConfig = val
			if val != "" {
				cfg.Xray.SyncPasswd = true
			}
			saveField(cfgMgr, cfg, "xray.wireguard_config")
			components.Pause()
		case "x":
			val := promptOptionalValue(i18n.T("xray_opt_xdrive_config"), cfg.Xray.XDriveConfig)
			cfg.Xray.XDriveConfig = val
			if val != "" {
				cfg.Xray.SyncPasswd = true
			}
			saveField(cfgMgr, cfg, "xray.xdrive_config")
			components.Pause()
		case "q":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_traffic_file"), cfg.Xray.TrafficUsageFile))
			if resp != "" {
				cfg.Xray.TrafficUsageFile = resp
				saveField(cfgMgr, cfg, "xray.traffic_usage_file")
			}
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXrayTLSSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_tls_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_tls_inherit"), featureBadge(cfg.Xray.TLS.InheritPort)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_tls_internal"), featureBadge(cfg.Xray.TLS.CertInternal)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_tls_cert"), valueBadge(displayOrEmpty(cfg.Xray.TLS.CertFile))), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_tls_key"), valueBadge(displayOrEmpty(cfg.Xray.TLS.KeyFile))), w)
		printMenuBack(w)

		switch readMenuOption("0-4") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.TLS.InheritPort, func(v bool) { cfg.Xray.TLS.InheritPort = v },
				i18n.T("toggle_xray_tls_inherit_on"), i18n.T("toggle_xray_tls_inherit_off"), "xray.tls.inherit_port")
		case "2":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.TLS.CertInternal, func(v bool) { cfg.Xray.TLS.CertInternal = v },
				i18n.T("toggle_xray_tls_internal_on"), i18n.T("toggle_xray_tls_internal_off"), "xray.tls.cert_internal")
		case "3":
			cfg.Xray.TLS.CertFile = strings.TrimSpace(components.Prompt(i18n.T("xray_opt_tls_cert"), cfg.Xray.TLS.CertFile))
			saveField(cfgMgr, cfg, "xray.tls.cert_file")
			components.Pause()
		case "4":
			cfg.Xray.TLS.KeyFile = strings.TrimSpace(components.Prompt(i18n.T("xray_opt_tls_key"), cfg.Xray.TLS.KeyFile))
			saveField(cfgMgr, cfg, "xray.tls.key_file")
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXrayLegacySubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xray_legacy_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_legacy"), featureBadge(cfg.Xray.Legacy.Enable)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_legacy_file"), valueBadge(displayOrEmpty(cfg.Xray.Legacy.ConfigFile))), w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_detect"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-3") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.Legacy.Enable, func(v bool) { cfg.Xray.Legacy.Enable = v },
				i18n.T("toggle_xray_legacy_on"), i18n.T("toggle_xray_legacy_off"), "xray.legacy.enable")
		case "2":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xray_opt_legacy_file"), cfg.Xray.Legacy.ConfigFile))
			if resp != "" {
				cfg.Xray.Legacy.ConfigFile = resp
				saveField(cfgMgr, cfg, "xray.legacy.config_file")
			}
			components.Pause()
		case "3":
			redetectXrayLegacy(cfgMgr, cfg)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXrayShareWizard(cfg *config.Config) {
	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("xray_share_title"), theme.Cyan, w)
	components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("xray_share_hint"), theme.Reset), w)
	components.PrintBoxDivider(w)
	components.PrintBoxLine(fmt.Sprintf("%s%s: %s%s%s", theme.White, i18n.T("xray_share_format"), theme.Cyan, i18n.T("xray_share_format_value"), theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%s%s: %s%s%s", theme.White, i18n.T("xray_share_path"), theme.Cyan, cfg.Xray.Path, theme.Reset), w)
	components.PrintBoxFooter(w)

	proxy := strings.TrimSpace(components.Prompt(i18n.T("xray_share_proxy"), ""))
	if proxy == "" {
		components.PrintError(i18n.T("xray_share_invalid_proxy"))
		components.Pause()
		return
	}

	proto := pickXrayShareProtocol(cfg.Xray)
	if proto == "" {
		components.PrintError(i18n.T("xray_share_none"))
		components.Pause()
		return
	}
	useTLS := pickXrayShareTLS()

	portDefault := strconv.Itoa(config.DefaultXraySharePortFor(cfg.Ports, useTLS))
	portRaw := strings.TrimSpace(components.Prompt(i18n.T("xray_share_port"), portDefault))
	port, err := strconv.Atoi(portRaw)
	if err != nil || port <= 0 || port > 65535 {
		components.PrintError(i18n.T("xray_share_invalid_port"))
		components.Pause()
		return
	}
	host := strings.TrimSpace(components.Prompt(i18n.T("xray_share_host"), ""))
	if host == "" {
		components.PrintError(i18n.T("xray_share_invalid_host"))
		components.Pause()
		return
	}
	sni := ""
	pcs := ""
	if useTLS {
		sniDefault := ""
		if net.ParseIP(strings.Trim(host, "[]")) == nil {
			sniDefault = host
		}
		sni = strings.TrimSpace(components.Prompt(i18n.T("xray_share_sni"), sniDefault))
		if sni == "" || net.ParseIP(strings.Trim(sni, "[]")) != nil {
			components.PrintError(i18n.T("xray_share_invalid_sni"))
			components.Pause()
			return
		}
		var ok bool
		if pcs, ok = askXraySharePCS(host); !ok {
			return
		}
	}

	shareTransports := cfg.Xray.ShareableTransports()
	transports := shareTransports
	if len(shareTransports) > 1 {
		resp := components.Prompt(i18n.T("xray_share_transport"), config.ShareTransportPrompt(shareTransports))
		picked := intersectXrayList(splitCSV(resp), shareTransports, cfg.Xray.AllowsTransport)
		if len(picked) > 0 {
			transports = picked
		}
	}

	links, err := config.BuildXrayShareLinks(config.XrayShareParams{
		Address:         proxy,
		Host:            host,
		SNI:             sni,
		Port:            port,
		Path:            cfg.Xray.Path,
		WSPath:          cfg.Xray.WSPath,
		SplitHTTPPath:   cfg.Xray.SplitHTTPPath,
		HTTPUpgradePath: cfg.Xray.HTTPUpgradePath,
		Remark:          "Veltrix",
		TLS:             useTLS,
		PCS:             pcs,
		Protocols:       []string{proto},
		Transports:      transports,
		GRPCService:     cfg.Xray.GRPCService,
	})
	if err != nil {
		if strings.Contains(err.Error(), "sni") {
			components.PrintError(i18n.T("xray_share_invalid_sni"))
		} else {
			components.PrintError(err.Error())
		}
		components.Pause()
		return
	}
	if len(links) == 0 {
		components.PrintError(i18n.T("xray_share_none"))
		components.Pause()
		return
	}

	fmt.Println()
	summary := fmt.Sprintf("%s: %s:%d   %s: %s", i18n.T("xray_share_label_proxy"), proxy, port, i18n.T("xray_share_label_host"), host)
	if useTLS {
		summary += fmt.Sprintf("   SNI: %s", sni)
	}
	fmt.Printf("%s%s%s\n\n", theme.Gray, summary, theme.Reset)
	for _, link := range links {
		fmt.Printf("%s%s%s\n%s\n\n", theme.Cyan, link.Label, theme.Reset, link.URI)
	}
	if !config.XrayPortConfigured(cfg.Ports, port) {
		components.PrintWarning(fmt.Sprintf(i18n.T("xray_share_port_inactive"), port, config.FormatPortList(cfg.Ports)))
	}
	components.Pause()
}

// askXraySharePCS returns ok=false when the user aborts after a failed lookup.
func askXraySharePCS(host string) (string, bool) {
	if !components.Confirm(i18n.T("xray_share_pcs_ask"), false) {
		return "", true
	}
	domain := system.XrayPCSDomain(host)
	if domain == "" {
		components.PrintWarning(i18n.T("xray_share_pcs_no_domain"))
		return "", components.Confirm(i18n.T("xray_share_pcs_continue"), true)
	}
	components.PrintInfo(fmt.Sprintf(i18n.T("xray_share_pcs_fetching"), domain))
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	res, err := system.FetchXrayPCS(ctx, domain)
	if err != nil {
		components.PrintWarning(fmt.Sprintf(i18n.T("xray_share_pcs_failed"), domain, err))
		return "", components.Confirm(i18n.T("xray_share_pcs_continue"), true)
	}
	msg := fmt.Sprintf(i18n.T("xray_share_pcs_ok"), res.PCS)
	if res.ValidTo != "" {
		msg += fmt.Sprintf(" (%s %s)", i18n.T("xray_share_pcs_valid_to"), res.ValidTo)
	}
	components.PrintSuccess(msg)
	return res.PCS, true
}

func pickXrayShareProtocol(xray config.XrayConfig) string {
	shareable := make([]string, 0, 3)
	for _, p := range []string{"vless", "vmess", "trojan"} {
		if xray.AllowsProtocol(p) {
			shareable = append(shareable, p)
		}
	}
	if len(shareable) == 1 {
		return shareable[0]
	}
	if len(shareable) == 0 {
		return ""
	}
	fmt.Printf("\n%s%s%s\n", theme.White, i18n.T("xray_share_protocol"), theme.Reset)
	fmt.Printf("  %s1 • VLESS%s\n", theme.Cyan, theme.Reset)
	fmt.Printf("  %s2 • VMess%s\n", theme.Cyan, theme.Reset)
	fmt.Printf("  %s3 • Trojan%s\n", theme.Cyan, theme.Reset)
	switch components.ReadOption(i18n.T("xray_share_pick")) {
	case "3", "trojan":
		if xray.AllowsProtocol("trojan") {
			return "trojan"
		}
	case "2", "vmess":
		if xray.AllowsProtocol("vmess") {
			return "vmess"
		}
	case "1", "vless", "":
		if xray.AllowsProtocol("vless") {
			return "vless"
		}
	}
	return shareable[0]
}

func pickXrayShareTLS() bool {
	fmt.Printf("\n%s%s%s\n", theme.White, i18n.T("xray_share_security"), theme.Reset)
	fmt.Printf("  %s1 • TLS%s\n", theme.Cyan, theme.Reset)
	fmt.Printf("  %s2 • Direct%s\n", theme.Cyan, theme.Reset)
	switch components.ReadOption(i18n.T("xray_share_pick")) {
	case "2", "direct", "none":
		return false
	default:
		return true
	}
}

func intersectXrayList(picked, enabled []string, allow func(string) bool) []string {
	if len(picked) == 0 {
		return enabled
	}
	out := make([]string, 0, len(picked))
	seen := map[string]bool{}
	for _, item := range picked {
		item = strings.ToLower(strings.TrimSpace(item))
		if item == "xhttp" {
			item = "splithttp"
		}
		if seen[item] || !allow(item) {
			continue
		}
		seen[item] = true
		out = append(out, item)
	}
	return out
}

func redetectXrayLegacy(cfgMgr *config.Manager, cfg *config.Config) {
	path, found := config.DetectXrayLegacyConfig()
	if found {
		cfg.Xray.Legacy.ConfigFile = path
		cfg.Xray.Legacy.Enable = true
		_ = cfgMgr.Save(cfg)
		components.PrintSuccess(i18n.T("xray_json_detected", path))
		components.Pause()
		return
	}
	path = config.DefaultXrayLegacyConfig
	if !components.Confirm(fmt.Sprintf(i18n.T("xray_confirm_stub"), path), true) {
		return
	}
	if err := config.EnsureXrayLegacyStub(path); err != nil {
		components.PrintError(i18n.T("xray_stub_failed", err))
		components.Pause()
		return
	}
	cfg.Xray.Legacy.ConfigFile = path
	cfg.Xray.Legacy.Enable = true
	_ = cfgMgr.Save(cfg)
	components.PrintSuccess(i18n.T("xray_stub_created", path))
	components.Pause()
}

func splitCSV(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

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
		components.PrintBoxLine(fmt.Sprintf("%s• Path:%s %s", theme.Gray, theme.Reset, valueBadge(cfg.Xray.Path)), w)
		components.PrintBoxLine(fmt.Sprintf("%s• %s:%s %s %s│ %s:%s %s",
			theme.Gray, i18n.T("xray_status_protocols"), theme.Reset, valueBadge(strings.Join(cfg.Xray.Protocols, ",")),
			theme.DarkGray, i18n.T("xray_status_transports"), theme.Reset, valueBadge(config.ShareTransportPrompt(cfg.Xray.Transports)),
		), w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(menuItem("1", i18n.T("xray_opt_share"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xray_opt_enable"), featureBadge(cfg.Xray.Enable)), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("3", i18n.T("xray_opt_general"), ""), w)
		components.PrintBoxLine(menuItem("4", i18n.T("xray_opt_tls_group"), ""), w)
		components.PrintBoxLine(menuItem("5", i18n.T("xray_opt_legacy_group"), featureBadge(cfg.Xray.Legacy.Enable)), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			showXrayShareWizard(cfg)
		case "2":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Xray.Enable, func(v bool) { cfg.Xray.Enable = v },
				i18n.T("toggle_xray_on"), i18n.T("toggle_xray_off"), "xray.enable")
		case "3":
			showXrayGeneralSubmenu(cfgMgr)
		case "4":
			showXrayTLSSubmenu(cfgMgr)
		case "5":
			showXrayLegacySubmenu(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
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
		printMenuBack(w)

		switch readMenuOption("0-3") {
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
			resp := components.Prompt(i18n.T("xray_opt_protocols")+" (vless,vmess)", strings.Join(cfg.Xray.Protocols, ","))
			cfg.Xray.Protocols = splitCSV(resp)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.protocols")
			components.Pause()
		case "3":
			resp := components.Prompt(i18n.T("xray_opt_transports")+" (ws,splithttp)", strings.Join(cfg.Xray.Transports, ","))
			cfg.Xray.Transports = splitCSV(resp)
			cfg.Xray.Normalize()
			saveField(cfgMgr, cfg, "xray.transports")
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
	components.PrintBoxLine(fmt.Sprintf("%s%s: %s%s%s", theme.White, i18n.T("xray_share_path"), theme.Cyan, cfg.Xray.Path, theme.Reset), w)
	components.PrintBoxFooter(w)

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
	proxy := strings.TrimSpace(components.Prompt(i18n.T("xray_share_proxy"), ""))
	if proxy == "" {
		components.PrintError(i18n.T("xray_share_invalid_proxy"))
		components.Pause()
		return
	}
	host := strings.TrimSpace(components.Prompt(i18n.T("xray_share_host"), proxy))
	if host == "" {
		host = proxy
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
		if pcs, ok = askXraySharePCS(sni, host, proxy); !ok {
			return
		}
	}

	transports := cfg.Xray.Transports
	if len(cfg.Xray.Transports) > 1 {
		resp := components.Prompt(i18n.T("xray_share_transport"), config.ShareTransportPrompt(cfg.Xray.Transports))
		picked := intersectXrayList(splitCSV(resp), cfg.Xray.Transports, cfg.Xray.AllowsTransport)
		if len(picked) > 0 {
			transports = picked
		}
	}

	links, err := config.BuildXrayShareLinks(config.XrayShareParams{
		Address:    proxy,
		Host:       host,
		SNI:        sni,
		Port:       port,
		Path:       cfg.Xray.Path,
		Remark:     "Veltrix",
		TLS:        useTLS,
		PCS:        pcs,
		Protocols:  []string{proto},
		Transports: transports,
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
	for _, link := range links {
		fmt.Printf("%s%s%s\n%s\n\n", theme.Cyan, link.Label, theme.Reset, link.URI)
	}
	if !config.XrayPortConfigured(cfg.Ports, port) {
		components.PrintWarning(fmt.Sprintf(i18n.T("xray_share_port_inactive"), port, config.FormatPortList(cfg.Ports)))
	}
	components.Pause()
}

// askXraySharePCS returns ok=false when the user aborts after a failed lookup.
func askXraySharePCS(sni, host, proxy string) (string, bool) {
	if !components.Confirm(i18n.T("xray_share_pcs_ask"), false) {
		return "", true
	}
	domain := system.XrayPCSDomain(sni, host, proxy)
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
	enabled := append([]string(nil), xray.Protocols...)
	if len(enabled) == 1 {
		return enabled[0]
	}
	fmt.Printf("\n%s%s%s\n", theme.White, i18n.T("xray_share_protocol"), theme.Reset)
	fmt.Printf("  %s1 • VLESS%s\n", theme.Cyan, theme.Reset)
	fmt.Printf("  %s2 • VMess%s\n", theme.Cyan, theme.Reset)
	switch components.ReadOption(i18n.T("xray_share_pick")) {
	case "2", "vmess":
		if xray.AllowsProtocol("vmess") {
			return "vmess"
		}
	case "1", "vless", "":
		if xray.AllowsProtocol("vless") {
			return "vless"
		}
	}
	if xray.AllowsProtocol("vless") {
		return "vless"
	}
	if xray.AllowsProtocol("vmess") {
		return "vmess"
	}
	return ""
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

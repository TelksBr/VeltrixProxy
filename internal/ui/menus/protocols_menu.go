package menus

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// promptAuth updates *mode (and *file when switching to "file") and saves.
func promptAuth(cfgMgr *config.Manager, cfg *config.Config, mode, file *string, fileLabel, fileDefault, field string) {
	newMode := promptAuthMode(*mode)
	if newMode == *mode {
		return
	}
	*mode = newMode
	if newMode == "file" && strings.TrimSpace(*file) == "" {
		def := *file
		if def == "" {
			def = fileDefault
		}
		*file = strings.TrimSpace(components.Prompt(fileLabel, def))
	}
	saveField(cfgMgr, cfg, field)
}

func showSSHSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("ssh_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("ssh_opt_internal"), featureBadge(cfg.SSH.Internal)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("ssh_opt_port"), valueBadge(cfg.SSH.Port)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("ssh_opt_internal_port"), valueBadge(cfg.SSH.InternalPort)), w)
		components.PrintBoxLine(menuItem("4", i18n.T("ssh_opt_allow_root"), featureBadge(cfg.SSH.AllowRoot)), w)
		components.PrintBoxLine(menuItem("5", i18n.T("ssh_opt_auth"), valueBadge(displayOrEmpty(cfg.SSH.Auth))), w)
		components.PrintBoxLine(menuItem("6", i18n.T("ssh_opt_auth_file"), valueBadge(displayOrEmpty(cfg.SSH.AuthFile))), w)
		components.PrintBoxLine(menuItem("7", i18n.T("ssh_opt_banner"), valueBadge(displayOrEmpty(cfg.SSH.Banner))), w)
		components.PrintBoxLine(menuItem("8", i18n.T("ssh_opt_banner_enable"), featureBadge(cfg.SSH.BannerEnable)), w)
		components.PrintBoxLine(menuItem("9", i18n.T("ssh_opt_banner_file"), valueBadge(displayOrEmpty(cfg.SSH.BannerFile))), w)
		printMenuBack(w)

		switch readMenuOption("0-9") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.SSH.Internal, func(v bool) { cfg.SSH.Internal = v },
				i18n.T("toggle_ssh_internal_on"), i18n.T("toggle_ssh_internal_off"), "ssh.internal")
		case "2":
			if val, ok := promptInt(i18n.T("ssh_opt_port"), cfg.SSH.Port, 1); ok {
				cfg.SSH.Port = val
				saveField(cfgMgr, cfg, "ssh.port")
			}
			components.Pause()
		case "3":
			if val, ok := promptInt(i18n.T("ssh_prompt_internal_port"), cfg.SSH.InternalPort, 0); ok {
				if val == cfg.SSH.InternalPort || confirmPortInUse("tcp", val) {
					cfg.SSH.InternalPort = val
					saveField(cfgMgr, cfg, "ssh.internal_port")
				}
			}
			components.Pause()
		case "4":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.SSH.AllowRoot, func(v bool) { cfg.SSH.AllowRoot = v },
				i18n.T("toggle_allow_root_on"), i18n.T("toggle_allow_root_off"), "ssh.allow_root")
		case "5":
			promptAuth(cfgMgr, cfg, &cfg.SSH.Auth, &cfg.SSH.AuthFile, i18n.T("ssh_opt_auth_file"), "", "ssh.auth")
			components.Pause()
		case "6":
			cfg.SSH.AuthFile = strings.TrimSpace(components.Prompt(i18n.T("ssh_opt_auth_file"), cfg.SSH.AuthFile))
			saveField(cfgMgr, cfg, "ssh.auth_file")
			components.Pause()
		case "7":
			resp := strings.TrimSpace(components.Prompt(i18n.T("ssh_opt_banner"), cfg.SSH.Banner))
			if resp != "" {
				cfg.SSH.Banner = resp
				saveField(cfgMgr, cfg, "ssh.banner")
			}
			components.Pause()
		case "8":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.SSH.BannerEnable, func(v bool) { cfg.SSH.BannerEnable = v },
				i18n.T("toggle_banner_enable_on"), i18n.T("toggle_banner_enable_off"), "ssh.banner_enable")
		case "9":
			resp := strings.TrimSpace(components.Prompt(i18n.T("ssh_opt_banner_file"), cfg.SSH.BannerFile))
			if resp != "" {
				cfg.SSH.BannerFile = resp
				saveField(cfgMgr, cfg, "ssh.banner_file")
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

func showBTUNSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("btun_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("btun_opt_enable"), featureBadge(cfg.BTUN.Enable)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("btun_opt_tun"), valueBadge(cfg.BTUN.Tun)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("btun_opt_subnet"), valueBadge(cfg.BTUN.Subnet)), w)
		components.PrintBoxLine(menuItem("4", i18n.T("btun_opt_udp"), valueBadge(cfg.BTUN.UDPPort)), w)
		components.PrintBoxLine(menuItem("5", i18n.T("btun_opt_auth"), valueBadge(displayOrEmpty(cfg.BTUN.Auth))), w)
		components.PrintBoxLine(menuItem("6", i18n.T("btun_opt_auth_file"), valueBadge(displayOrEmpty(cfg.BTUN.AuthFile))), w)
		printMenuBack(w)

		switch readMenuOption("0-6") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.BTUN.Enable, func(v bool) { cfg.BTUN.Enable = v },
				i18n.T("toggle_btun_on"), i18n.T("toggle_btun_off"), "btun.enable")
		case "2":
			resp := strings.TrimSpace(components.Prompt(i18n.T("btun_opt_tun"), cfg.BTUN.Tun))
			if resp != "" {
				cfg.BTUN.Tun = resp
				saveField(cfgMgr, cfg, "btun.tun")
			}
			components.Pause()
		case "3":
			resp := strings.TrimSpace(components.Prompt(i18n.T("btun_opt_subnet"), cfg.BTUN.Subnet))
			if resp != "" {
				cfg.BTUN.Subnet = resp
				saveField(cfgMgr, cfg, "btun.subnet")
			}
			components.Pause()
		case "4":
			if val, ok := promptInt(i18n.T("btun_opt_udp"), cfg.BTUN.UDPPort, 0); ok {
				if val == cfg.BTUN.UDPPort || confirmPortInUse("udp", val) {
					cfg.BTUN.UDPPort = val
					saveField(cfgMgr, cfg, "btun.udp_port")
				}
			}
			components.Pause()
		case "5":
			promptAuth(cfgMgr, cfg, &cfg.BTUN.Auth, &cfg.BTUN.AuthFile, i18n.T("btun_opt_auth_file"), "", "btun.auth")
			components.Pause()
		case "6":
			cfg.BTUN.AuthFile = strings.TrimSpace(components.Prompt(i18n.T("btun_opt_auth_file"), cfg.BTUN.AuthFile))
			saveField(cfgMgr, cfg, "btun.auth_file")
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showXHTTPSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("xhttp_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("xhttp_opt_path"), valueBadge(cfg.XHTTP.Path)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("xhttp_opt_grace"), valueBadge(cfg.XHTTP.Grace)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("xhttp_opt_idle"), valueBadge(cfg.XHTTP.Idle)), w)
		printMenuBack(w)

		switch readMenuOption("0-3") {
		case "1":
			resp := strings.TrimSpace(components.Prompt(i18n.T("xhttp_opt_path"), cfg.XHTTP.Path))
			if resp != "" {
				cfg.XHTTP.Path = resp
				saveField(cfgMgr, cfg, "xhttp.path")
			}
			components.Pause()
		case "2":
			if val, ok := promptInt(i18n.T("xhttp_opt_grace"), cfg.XHTTP.Grace, 0); ok {
				cfg.XHTTP.Grace = val
				saveField(cfgMgr, cfg, "xhttp.grace")
			}
			components.Pause()
		case "3":
			if val, ok := promptInt(i18n.T("xhttp_opt_idle"), cfg.XHTTP.Idle, 0); ok {
				cfg.XHTTP.Idle = val
				saveField(cfgMgr, cfg, "xhttp.idle")
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
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		if cfg.Ztun.Auth == "" {
			cfg.Ztun.Auth = "shadow"
		}
		if cfg.Ztun.Idle <= 0 {
			cfg.Ztun.Idle = 180
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("ztun_menu_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%s• %s: %s", theme.White, i18n.T("ztun_mode_label"), valueBadge(ztunRuntimeMode(cfg))), w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("ztun_upstream_hint"), theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("ztun_opt_enable"), featureBadge(cfg.Ztun.Enable)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("ztun_opt_upstream"), valueBadge(displayOrEmpty(cfg.Ztun.Upstream))), w)
		components.PrintBoxLine(menuItem("3", i18n.T("ztun_opt_auth"), valueBadge(displayOrEmpty(cfg.Ztun.Auth))), w)
		components.PrintBoxLine(menuItem("4", i18n.T("ztun_opt_auth_file"), valueBadge(displayOrEmpty(cfg.Ztun.AuthFile))), w)
		components.PrintBoxLine(menuItem("5", i18n.T("ztun_opt_idle"), valueBadge(cfg.Ztun.Idle)), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.Ztun.Enable, func(v bool) { cfg.Ztun.Enable = v },
				i18n.T("toggle_ztun_on"), i18n.T("toggle_ztun_off"), "ztun.enable")
		case "2":
			cfg.Ztun.Upstream = strings.TrimSpace(components.Prompt(i18n.T("ztun_opt_upstream")+" (ex: 127.0.0.1:9443)", cfg.Ztun.Upstream))
			saveField(cfgMgr, cfg, "ztun.upstream")
			components.Pause()
		case "3":
			promptAuth(cfgMgr, cfg, &cfg.Ztun.Auth, &cfg.Ztun.AuthFile, i18n.T("ztun_opt_auth_file"), "/etc/proxy/users", "ztun.auth")
			components.Pause()
		case "4":
			cfg.Ztun.AuthFile = strings.TrimSpace(components.Prompt(i18n.T("ztun_opt_auth_file"), cfg.Ztun.AuthFile))
			saveField(cfgMgr, cfg, "ztun.auth_file")
			components.Pause()
		case "5":
			if val, ok := promptInt(i18n.T("ztun_opt_idle"), cfg.Ztun.Idle, 0); ok {
				if val == 0 {
					val = 180
				}
				cfg.Ztun.Idle = val
				saveField(cfgMgr, cfg, "ztun.idle")
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

func showHCRSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.HCR.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("hcr_menu_title"), theme.Cyan, w)
		components.PrintBoxLine(fmt.Sprintf("%s   %s%s", theme.Gray, i18n.T("hcr_transport_hint"), theme.Reset), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("hcr_opt_enable"), featureBadge(cfg.HCR.Enable)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("hcr_opt_transport"), valueBadge(cfg.HCR.Transport)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("hcr_opt_target"), valueBadge(displayOrEmpty(cfg.HCR.Target))), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("4", i18n.T("hcr_opt_tls_group"), featureBadge(cfg.HCR.TLSInternal)), w)
		components.PrintBoxLine(menuItem("5", i18n.T("hcr_opt_sessions_group"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.HCR.Enable, func(v bool) { cfg.HCR.Enable = v },
				i18n.T("toggle_hcr_on"), i18n.T("toggle_hcr_off"), "hcr.enable")
		case "2":
			resp := strings.ToLower(strings.TrimSpace(components.Prompt(i18n.T("hcr_opt_transport")+" [plain|tls|auto]", cfg.HCR.Transport)))
			switch resp {
			case "plain", "tls", "auto":
				cfg.HCR.Transport = resp
				saveField(cfgMgr, cfg, "hcr.transport")
			default:
				components.PrintError(i18n.T("hcr_transport_invalid"))
			}
			components.Pause()
		case "3":
			cfg.HCR.Target = strings.TrimSpace(components.Prompt(i18n.T("hcr_target_prompt"), cfg.HCR.Target))
			saveField(cfgMgr, cfg, "hcr.target")
			components.Pause()
		case "4":
			showHCRTLSSubmenu(cfgMgr)
		case "5":
			showHCRSessionsSubmenu(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showHCRTLSSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("hcr_tls_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("hcr_opt_tls_internal"), featureBadge(cfg.HCR.TLSInternal)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("hcr_opt_tls_cert"), valueBadge(displayOrEmpty(cfg.HCR.TLSCert))), w)
		components.PrintBoxLine(menuItem("3", i18n.T("hcr_opt_tls_key"), valueBadge(displayOrEmpty(cfg.HCR.TLSKey))), w)
		printMenuBack(w)

		switch readMenuOption("0-3") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.HCR.TLSInternal, func(v bool) { cfg.HCR.TLSInternal = v },
				i18n.T("toggle_hcr_tls_internal_on"), i18n.T("toggle_hcr_tls_internal_off"), "hcr.tls_internal")
		case "2":
			cfg.HCR.TLSCert = strings.TrimSpace(components.Prompt(i18n.T("hcr_opt_tls_cert"), cfg.HCR.TLSCert))
			saveField(cfgMgr, cfg, "hcr.tls_cert")
			components.Pause()
		case "3":
			cfg.HCR.TLSKey = strings.TrimSpace(components.Prompt(i18n.T("hcr_opt_tls_key"), cfg.HCR.TLSKey))
			saveField(cfgMgr, cfg, "hcr.tls_key")
			components.Pause()
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

type hcrIntField struct {
	labelKey string
	field    string
	min      int
	ptr      func(*config.Config) *int
}

var hcrSessionFields = []hcrIntField{
	{"hcr_opt_max_sessions", "hcr.max_sessions", 1, func(c *config.Config) *int { return &c.HCR.MaxSessions }},
	{"hcr_opt_max_source_sessions", "hcr.max_source_sessions", 0, func(c *config.Config) *int { return &c.HCR.MaxSourceSessions }},
	{"hcr_opt_max_connections", "hcr.max_connections", 1, func(c *config.Config) *int { return &c.HCR.MaxConnections }},
	{"hcr_opt_poll_timeout", "hcr.poll_timeout", 1, func(c *config.Config) *int { return &c.HCR.PollTimeout }},
	{"hcr_opt_idle", "hcr.idle", 1, func(c *config.Config) *int { return &c.HCR.Idle }},
	{"hcr_opt_max_download_frame", "hcr.max_download_frame", 1, func(c *config.Config) *int { return &c.HCR.MaxDownloadFrame }},
	{"hcr_opt_max_replay_bytes", "hcr.max_replay_bytes", 1, func(c *config.Config) *int { return &c.HCR.MaxReplayBytes }},
	{"hcr_opt_session_stats_interval", "hcr.session_stats_interval", 0, func(c *config.Config) *int { return &c.HCR.SessionStatsInterval }},
}

func showHCRSessionsSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.HCR.Normalize()
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("hcr_sessions_title"), theme.Cyan, w)
		for i, f := range hcrSessionFields {
			components.PrintBoxLine(menuItem(strconv.Itoa(i+1), i18n.T(f.labelKey), valueBadge(*f.ptr(cfg))), w)
		}
		printMenuBack(w)

		choice := readMenuOption(fmt.Sprintf("0-%d", len(hcrSessionFields)))
		if choice == "0" || choice == "" {
			return
		}
		idx, err := strconv.Atoi(choice)
		if err != nil || idx < 1 || idx > len(hcrSessionFields) {
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
			continue
		}
		f := hcrSessionFields[idx-1]
		if val, ok := promptInt(i18n.T(f.labelKey), *f.ptr(cfg), f.min); ok {
			*f.ptr(cfg) = val
			saveField(cfgMgr, cfg, f.field)
		}
		components.Pause()
	}
}

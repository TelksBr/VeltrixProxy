package menus

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowSettingsMenu groups the advanced config.json sections.
func ShowSettingsMenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("adv_menu_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("settings_opt_protocols"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("adv_opt_ssl"), featureBadge(cfg.CertInternal)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("adv_opt_perf"), ""), w)
		components.PrintBoxLine(menuItem("4", i18n.T("adv_opt_http_logs"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("5", i18n.T("adv_opt_view_json"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			showProtocolsSubmenu(cfgMgr)
		case "2":
			showSSLSubmenu(cfgMgr)
		case "3":
			showPerformanceSubmenu(cfgMgr)
		case "4":
			showHttpLogsSubmenu(cfgMgr)
		case "5":
			viewConfigFile(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func showProtocolsSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("protocols_menu_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("adv_opt_ssh"), featureBadge(cfg.SSH.Internal)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("adv_opt_btun"), featureBadge(cfg.BTUN.Enable)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("adv_opt_xhttp"), ""), w)
		components.PrintBoxLine(menuItem("4", i18n.T("adv_opt_ztun"), featureBadge(cfg.Ztun.Enable)), w)
		components.PrintBoxLine(menuItem("5", i18n.T("adv_opt_hcr"), featureBadge(cfg.HCR.Enable)), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			showSSHSubmenu(cfgMgr)
		case "2":
			showBTUNSubmenu(cfgMgr)
		case "3":
			showXHTTPSubmenu(cfgMgr)
		case "4":
			showZtunSubmenu(cfgMgr)
		case "5":
			showHCRSubmenu(cfgMgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func promptAuthMode(current string) string {
	fmt.Printf("\n%s%s%s\n", theme.Cyan, i18n.T("auth_mode_title"), theme.Reset)
	fmt.Printf("  1 • %s\n", i18n.T("auth_mode_shadow"))
	fmt.Printf("  2 • %s\n", i18n.T("auth_mode_file"))
	fmt.Printf("  3 • %s\n", i18n.T("auth_mode_allow"))
	fmt.Printf("  0 • %s\n", i18n.T("keep_current"))
	switch readMenuOption("0-3") {
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
	fmt.Printf("\n%s%s%s\n", theme.Cyan, i18n.T("loglevel_title"), theme.Reset)
	fmt.Printf("  %s: %s%s%s\n\n", i18n.T("loglevel_current"), theme.Yellow, current, theme.Reset)
	levels := []string{"trace", "debug", "info", "warn", "error", "silent"}
	for i, lvl := range levels {
		fmt.Printf("  %d • %-7s — %s\n", i+1, lvl, i18n.T("loglevel_"+lvl))
	}
	fmt.Printf("  0 • %s\n", i18n.T("keep_current"))
	choice := readMenuOption("0-6")
	if idx, err := strconv.Atoi(choice); err == nil && idx >= 1 && idx <= len(levels) {
		return levels[idx-1]
	}
	return current
}

// promptInt reads an int >= min; ok=false (with an error printed) on bad input.
func promptInt(label string, current, min int) (int, bool) {
	resp := strings.TrimSpace(components.Prompt(label, strconv.Itoa(current)))
	val, err := strconv.Atoi(resp)
	if err != nil || val < min {
		components.PrintError(i18n.T("invalid_value"))
		return 0, false
	}
	return val, true
}

func showPerformanceSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("perf_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("perf_opt_buffer"), valueBadge(cfg.BufferSize)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("perf_opt_max_conn"), valueBadge(cfg.MaxConnections)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("perf_opt_idle"), valueBadge(cfg.IdleTimeout)), w)
		components.PrintBoxLine(menuItem("4", i18n.T("perf_opt_write"), valueBadge(cfg.WriteTimeout)), w)
		components.PrintBoxLine(menuItem("5", i18n.T("perf_opt_ulimit"), valueBadge(cfg.Ulimit)), w)
		printMenuBack(w)

		switch readMenuOption("0-5") {
		case "1":
			if val, ok := promptInt(i18n.T("perf_prompt_buffer"), cfg.BufferSize, 1); ok {
				cfg.BufferSize = val
				saveField(cfgMgr, cfg, "buffer_size")
			}
			components.Pause()
		case "2":
			if val, ok := promptInt(i18n.T("perf_opt_max_conn"), cfg.MaxConnections, 0); ok {
				cfg.MaxConnections = val
				saveField(cfgMgr, cfg, "max_connections")
			}
			components.Pause()
		case "3":
			if val, ok := promptInt(i18n.T("perf_opt_idle"), cfg.IdleTimeout, 0); ok {
				cfg.IdleTimeout = val
				saveField(cfgMgr, cfg, "idle_timeout")
			}
			components.Pause()
		case "4":
			if val, ok := promptInt(i18n.T("perf_opt_write"), cfg.WriteTimeout, 0); ok {
				cfg.WriteTimeout = val
				saveField(cfgMgr, cfg, "write_timeout")
			}
			components.Pause()
		case "5":
			if val, ok := promptInt(i18n.T("perf_prompt_ulimit"), cfg.Ulimit, 1024); ok {
				cfg.Ulimit = val
				saveField(cfgMgr, cfg, "ulimit")
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

func showHttpLogsSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("httplogs_title"), theme.Cyan, w)
		components.PrintBoxLine(menuItem("1", i18n.T("httplogs_opt_response"), valueBadge(cfg.Response)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("httplogs_opt_banner"), featureBadge(cfg.DisplayBanner)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("httplogs_opt_level"), valueBadge(cfg.LogLevel)), w)
		components.PrintBoxLine(menuItem("4", i18n.T("httplogs_opt_file"), valueBadge(cfg.LogFile)), w)
		printMenuBack(w)

		switch readMenuOption("0-4") {
		case "1":
			resp := strings.TrimSpace(components.Prompt(i18n.T("httplogs_opt_response"), cfg.Response))
			if resp != "" && resp != cfg.Response {
				cfg.Response = resp
				saveField(cfgMgr, cfg, "response")
			}
			components.Pause()
		case "2":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.DisplayBanner, func(v bool) { cfg.DisplayBanner = v },
				i18n.T("toggle_banner_on"), i18n.T("toggle_banner_off"), "display_banner")
		case "3":
			level := promptLogLevel(cfg.LogLevel)
			if level != "" && level != cfg.LogLevel {
				cfg.LogLevel = level
				saveField(cfgMgr, cfg, "log_level")
			}
			components.Pause()
		case "4":
			resp := strings.TrimSpace(components.Prompt(i18n.T("httplogs_opt_file"), cfg.LogFile))
			if resp != "" {
				cfg.LogFile = resp
				saveField(cfgMgr, cfg, "log_file")
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

func showSSLSubmenu(cfgMgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("ssl_title"), theme.Cyan, w)

		certPath := cfg.Cert
		if certPath == "" {
			certPath = i18n.T("ssl_none")
		}
		components.PrintBoxLine(menuItem("1", i18n.T("ssl_opt_internal"), featureBadge(cfg.CertInternal)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("ssl_opt_external"), valueBadge(certPath)), w)
		printMenuBack(w)

		switch readMenuOption("0-2") {
		case "1":
			applyJSONBoolToggle(cfgMgr, cfg, cfg.CertInternal, func(v bool) {
				cfg.CertInternal = v
				if v {
					cfg.Cert = ""
				}
			}, i18n.T("toggle_cert_internal_on"), i18n.T("toggle_cert_internal_off"), "cert_internal")
		case "2":
			resp := strings.TrimSpace(components.Prompt(i18n.T("ssl_prompt_external"), cfg.Cert))
			if resp != "" {
				cfg.Cert = resp
				cfg.CertInternal = false
				saveField(cfgMgr, cfg, "cert")
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

func viewConfigFile(cfgMgr *config.Manager) {
	components.ClearScreen()
	data, err := os.ReadFile(cfgMgr.Path())
	if err != nil {
		components.PrintError(i18n.T("config_read_failed", err))
		components.Pause()
		return
	}

	var pretty map[string]interface{}
	_ = json.Unmarshal(data, &pretty)
	formatted, _ := json.MarshalIndent(pretty, "", "  ")

	fmt.Printf("\n%s%s:%s\n\n", theme.Cyan, i18n.T("config_file_content", cfgMgr.Path()), theme.Reset)
	fmt.Println(string(formatted))
	components.Pause()
}

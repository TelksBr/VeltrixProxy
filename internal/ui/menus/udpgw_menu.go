package menus

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/udpgw"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowUDPGWMenu gerencia o BadVPN udpgw embutido no proxy.
func ShowUDPGWMenu(cfgMgr *config.Manager) {
	// Limpeza residual (install/update já remove; aqui só se sobrar algo)
	if udpgw.HasLegacyUnits() || len(udpgw.ListConfiguredPorts()) > 0 {
		_ = udpgw.DisableAndRemoveAll()
	}

	for {
		cfg, ok := loadConfigOrWarn(cfgMgr)
		if !ok {
			return
		}
		cfg.UDPGW.Normalize()

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("udpgw_menu_title"), theme.Cyan, w)

		modeText := i18n.T("udpgw_mode_external")
		if cfg.UDPGW.Internal {
			modeText = i18n.T("udpgw_mode_internal")
		}
		components.PrintBoxLine(fmt.Sprintf("%s• %s:%s %s %s│ %s%s%s",
			theme.White, i18n.T("udpgw_opt_internal"), theme.Reset, featureBadge(cfg.UDPGW.Internal),
			theme.DarkGray, theme.Cyan, modeText, theme.Reset), w)
		components.PrintBoxLine(fmt.Sprintf("%s• %s: %s%d–%d%s %s",
			theme.Gray, i18n.T("udpgw_port_range_hint"), theme.Cyan, cfg.UDPGW.PortMin, cfg.UDPGW.PortMax, theme.Reset, i18n.T("udpgw_loopback_hint")), w)

		if !cfg.SSH.Internal {
			components.PrintBoxDivider(w)
			components.PrintBoxLine(fmt.Sprintf("%s%s%s", theme.Yellow, i18n.T("udpgw_requires_ssh"), theme.Reset), w)
		}

		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("1", i18n.T("udpgw_opt_internal"), featureBadge(cfg.UDPGW.Internal)), w)
		components.PrintBoxLine(menuItem("2", i18n.T("udpgw_opt_port_min"), valueBadge(cfg.UDPGW.PortMin)), w)
		components.PrintBoxLine(menuItem("3", i18n.T("udpgw_opt_port_max"), valueBadge(cfg.UDPGW.PortMax)), w)
		printMenuBack(w)

		switch readMenuOption("0-3") {
		case "1":
			handleToggleUDPGWInternal(cfgMgr, cfg)
		case "2":
			handleEditUDPGWPortBound(cfgMgr, cfg, true)
		case "3":
			handleEditUDPGWPortBound(cfgMgr, cfg, false)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func handleToggleUDPGWInternal(cfgMgr *config.Manager, cfg *config.Config) {
	if !cfg.SSH.Internal && !cfg.UDPGW.Internal {
		components.PrintWarning(i18n.T("udpgw_requires_ssh"))
		if !components.Confirm(i18n.T("udpgw_confirm_without_ssh"), false) {
			return
		}
	}

	newVal, changed := components.ConfirmToggle(
		i18n.T("toggle_udpgw_internal_on"),
		i18n.T("toggle_udpgw_internal_off"),
		cfg.UDPGW.Internal,
	)
	if !changed {
		components.PrintInfo(i18n.T("confirm_no_change", "udpgw.internal", cfg.UDPGW.Internal))
		components.Pause()
		return
	}

	cfg.UDPGW.Internal = newVal
	if err := cfgMgr.Save(cfg); err != nil {
		components.PrintError(i18n.T("save_failed", err))
		components.Pause()
		return
	}

	if newVal {
		components.PrintSuccess(i18n.T("toggle_enabled", "udpgw.internal"))
		_ = udpgw.DisableAndRemoveAll()
	} else {
		components.PrintSuccess(i18n.T("toggle_disabled", "udpgw.internal"))
		components.PrintInfo(i18n.T("udpgw_external_hint"))
	}
	components.Pause()
}

func handleEditUDPGWPortBound(cfgMgr *config.Manager, cfg *config.Config, isMin bool) {
	cfg.UDPGW.Normalize()
	key := "udpgw.port_min"
	label := i18n.T("udpgw_opt_port_min")
	current := cfg.UDPGW.PortMin
	if !isMin {
		key = "udpgw.port_max"
		label = i18n.T("udpgw_opt_port_max")
		current = cfg.UDPGW.PortMax
	}

	resp := components.Prompt(fmt.Sprintf("%s (1–65535)", label), strconv.Itoa(current))
	val, err := strconv.Atoi(strings.TrimSpace(resp))
	if err != nil || val < 1 || val > 65535 {
		components.PrintError(i18n.T("udpgw_invalid_port"))
		components.Pause()
		return
	}

	if isMin {
		if val > cfg.UDPGW.PortMax {
			components.PrintError(i18n.T("udpgw_port_min_gt_max"))
			components.Pause()
			return
		}
		cfg.UDPGW.PortMin = val
	} else {
		if val < cfg.UDPGW.PortMin {
			components.PrintError(i18n.T("udpgw_port_max_lt_min"))
			components.Pause()
			return
		}
		cfg.UDPGW.PortMax = val
	}

	if err := cfgMgr.Save(cfg); err != nil {
		components.PrintError(i18n.T("save_failed", err))
		components.Pause()
		return
	}

	components.PrintSuccess(fmt.Sprintf("%s = %d", key, val))
	components.Pause()
}

package menus

import (
	"bytes"
	"fmt"
	"os"
	"strings"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// menuItem formats "K • label" and, when badge is set, "K • label: badge".
func menuItem(key, label, badge string) string {
	if badge == "" {
		return fmt.Sprintf("%s%s • %s%s", theme.White, key, label, theme.Reset)
	}
	return fmt.Sprintf("%s%s • %s: %s%s", theme.White, key, label, badge, theme.Reset)
}

// valueBadge highlights a configured value (ports, paths, numbers).
func valueBadge(v interface{}) string {
	return fmt.Sprintf("%s%v%s", theme.Cyan, v, theme.Reset)
}

// featureBadge is the standard [ACTIVE]/[INACTIVE] label for config flags.
func featureBadge(on bool) string {
	return components.FormatBool(on)
}

// serviceBadge is the standard ONLINE/OFFLINE label for running services.
func serviceBadge(on bool) string {
	if on {
		return theme.BadgeOnline
	}
	return theme.BadgeOffline
}

// printMenuBack closes a submenu box with the standard "0 • Back" line.
func printMenuBack(w int) {
	components.PrintBoxDivider(w)
	components.PrintBoxLine(fmt.Sprintf("%s0 • %s%s", theme.Red, i18n.T("back"), theme.Reset), w)
	components.PrintBoxFooter(w)
}

// readMenuOption shows the standard prompt with the valid range, e.g. "0-5".
func readMenuOption(rangeLabel string) string {
	return strings.ToLower(strings.TrimSpace(components.ReadOption(i18n.T("prompt_select_option") + " [" + rangeLabel + "]")))
}

func displayOrEmpty(v string) string {
	if strings.TrimSpace(v) == "" {
		return i18n.T("empty_value")
	}
	return v
}

func loadConfigOrWarn(cfgMgr *config.Manager) (*config.Config, bool) {
	cfg, err := cfgMgr.Get()
	if err != nil || cfg == nil {
		components.PrintError(i18n.T("config_load_failed", err))
		components.Pause()
		return nil, false
	}
	return cfg, true
}

// withRestartPrompt runs a config submenu and, when config.json changed on disk,
// asks once whether to restart the proxy. Compares file bytes because
// Manager.Get returns a shared pointer that submenus may mutate without saving.
func withRestartPrompt(cfgMgr *config.Manager, run func()) {
	before, _ := os.ReadFile(cfgMgr.Path())
	run()
	after, _ := os.ReadFile(cfgMgr.Path())
	if bytes.Equal(before, after) {
		return
	}
	maybeRestartProxy()
}

func maybeRestartProxy() {
	if !system.IsServiceActive(system.ProxyServiceName) {
		return
	}
	if !components.Confirm(i18n.T("confirm_restart_proxy"), true) {
		return
	}
	if err := system.RestartService(system.ProxyServiceName); err != nil {
		components.PrintError(i18n.T("proxy_restart_failed", err))
	} else {
		components.PrintSuccess(i18n.T("proxy_restarted"))
	}
	components.Pause()
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
		components.PrintError(i18n.T("save_failed", err))
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

// saveField persists cfg and prints "<field> updated." (or the save error).
func saveField(cfgMgr *config.Manager, cfg *config.Config, field string) {
	if err := cfgMgr.Save(cfg); err != nil {
		components.PrintError(i18n.T("save_failed", err))
		return
	}
	components.PrintSuccess(i18n.T("field_updated", field))
}

// confirmPortInUse warns when proto/port is taken by another process and
// returns whether the caller should proceed.
func confirmPortInUse(proto string, port int) bool {
	if port <= 0 {
		return true
	}
	var inUse bool
	var procInfo string
	if proto == "udp" {
		avail, info := system.CheckUDPPortAvailable(port)
		inUse, procInfo = !avail, info
	} else {
		inUse, procInfo = system.IsPortInUseByOther(proto, port)
	}
	if !inUse {
		return true
	}
	key := "port_in_use_tcp"
	if proto == "udp" {
		key = "port_in_use_udp"
	}
	components.PrintWarning(i18n.T(key, port, procInfo))
	return components.Confirm(i18n.T("confirm_apply_anyway"), false)
}

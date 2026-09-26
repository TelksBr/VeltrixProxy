package menus

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

var allLanguages = []i18n.Language{i18n.LangPT, i18n.LangEN, i18n.LangES}

// Option labels shown with a status badge; they must fit the default box.
var badgeOptionKeys = []string{
	"menu_opt_xray", "menu_opt_dnstt", "menu_opt_udpgw", "menu_opt_users",
	"adv_opt_ssl", "adv_opt_ssh", "adv_opt_btun", "adv_opt_ztun", "adv_opt_hcr", "adv_opt_limits",
	"xray_opt_enable", "xray_opt_legacy_group", "xray_opt_tls_inherit", "xray_opt_tls_internal", "xray_opt_legacy",
	"hcr_opt_enable", "hcr_opt_tls_group", "hcr_opt_tls_internal",
	"ssh_opt_internal", "ssh_opt_allow_root", "ssh_opt_banner_enable",
	"btun_opt_enable", "ztun_opt_enable", "limits_opt_enable", "udpgw_opt_internal",
	"ssl_opt_internal", "httplogs_opt_banner",
}

var plainOptionKeys = []string{
	"menu_opt_proxy", "menu_opt_tokens", "menu_opt_settings", "menu_opt_update",
	"menu_opt_change_language", "menu_opt_uninstall", "menu_opt_exit",
	"proxy_opt_add", "proxy_opt_remove", "proxy_opt_details", "proxy_opt_start", "proxy_opt_stop",
	"proxy_opt_restart", "proxy_opt_journal_logs", "proxy_opt_file_logs",
	"settings_opt_protocols", "adv_opt_perf", "adv_opt_http_logs", "adv_opt_view_json", "adv_opt_xhttp",
	"xray_opt_share", "xray_opt_general", "xray_opt_tls_group", "xray_opt_detect",
	"dnstt_opt_toggle", "dnstt_opt_domain", "dnstt_opt_keys", "dnstt_opt_udp", "dnstt_opt_fallback",
	"dnstt_opt_upstream", "dnstt_opt_mtu", "dnstt_opt_free_port53",
	"dnstt_keys_opt_generate", "dnstt_keys_opt_file", "dnstt_keys_opt_manual",
	"users_opt_list", "users_opt_kill", "users_opt_kill_expired",
	"tokens_opt_set", "tokens_opt_validate", "hcr_opt_sessions_group",
	"update_opt_apply", "update_opt_check_again", "back",
}

func assertFitsBox(t *testing.T, lang i18n.Language, key, line string) {
	t.Helper()
	width := components.DefaultBoxWidth
	if visible := theme.VisibleLen(line); visible > width-4 {
		t.Errorf("%s/%s: %d colunas visíveis > %d: %q", lang, key, visible, width-4, theme.StripANSI(line))
	}
	box := components.FormatBoxLine(line, width)
	if strings.Contains(box, "...") || strings.Contains(box, "…") {
		t.Errorf("%s/%s: linha truncada: %q", lang, key, theme.StripANSI(box))
	}
}

func TestMenuOptionsFitDefaultBox(t *testing.T) {
	defer i18n.SetLanguage(i18n.LangPT)
	for _, lang := range allLanguages {
		_ = i18n.SetLanguage(lang)
		for _, key := range badgeOptionKeys {
			assertFitsBox(t, lang, key, menuItem("9", i18n.T(key), featureBadge(false)))
		}
		for _, key := range plainOptionKeys {
			assertFitsBox(t, lang, key, menuItem("9", i18n.T(key), ""))
		}
		assertFitsBox(t, lang, "menu_opt_update+badge", mainMenuItem("8", i18n.T("menu_opt_update"), "["+i18n.T("update_badge_available")+"]"))
	}
}

var i18nCallRe = regexp.MustCompile(`i18n\.T\("([a-z0-9_]+)"[,)]`)

// Every literal i18n key used by the menus must exist in PT, EN and ES.
func TestMenuKeysTranslated(t *testing.T) {
	defer i18n.SetLanguage(i18n.LangPT)
	files, _ := filepath.Glob("*.go")
	extra, _ := filepath.Glob("../components/*.go")
	files = append(files, extra...)

	keys := map[string]bool{}
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		data, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		for _, m := range i18nCallRe.FindAllStringSubmatch(string(data), -1) {
			keys[m[1]] = true
		}
	}
	for _, lvl := range []string{"trace", "debug", "info", "warn", "error", "silent"} {
		keys["loglevel_"+lvl] = true
	}
	for _, f := range hcrSessionFields {
		keys[f.labelKey] = true
	}
	keys = mergeKeys(keys, badgeOptionKeys, plainOptionKeys)

	for _, lang := range allLanguages {
		_ = i18n.SetLanguage(lang)
		for key := range keys {
			if !i18n.Has(lang, key) {
				t.Errorf("%s: chave i18n ausente: %s", lang, key)
			}
		}
	}
}

func mergeKeys(dst map[string]bool, lists ...[]string) map[string]bool {
	for _, l := range lists {
		for _, k := range l {
			dst[k] = true
		}
	}
	return dst
}

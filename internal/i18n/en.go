package i18n

var dictEN = map[string]string{
	// Main Menu
	"app_title":                  "VELTRIX PROXY MANAGER",
	"menu_opt_proxy":             "Proxy Menu (Ports & JSON)",
	"menu_opt_udpgw":             "BadVPN / UDPGW Menu",
	"menu_opt_tokens":            "Manage License Tokens",
	"menu_opt_connected_users":   "Connected Users (Online)",
	"menu_opt_update":            "Update System & Binaries",
	"menu_opt_change_language":   "Change Language",
	"menu_opt_exit":              "Exit Menu",

	// Proxy Menu
	"proxy_menu_title":           "VT PROXY MANAGER",
	"proxy_opt_add":              "Add port to proxy",
	"proxy_opt_remove":           "Remove port from proxy",
	"proxy_opt_start":            "Start proxy service (Turn On)",
	"proxy_opt_stop":             "Stop proxy service (Turn Off)",
	"proxy_opt_restart":          "Restart proxy service",
	"proxy_opt_adv":              "Advanced options (config.json)",
	"proxy_opt_http":             "Change global HTTP response",
	"proxy_opt_details":          "Port details and status",
	"proxy_opt_logs":             "View service logs",
	"proxy_opt_journal_logs":     "Real-time service logs (Journalctl)",
	"proxy_opt_file_logs":        "Proxy metrics & logs from file (log_file)",
	"proxy_opt_back":             "Back to main menu",

	// UDPGW Submenu
	"udpgw_menu_title":           "BADVPN / UDPGW MANAGER",
	"udpgw_opt_open":             "Open / create new UDPGW port",
	"udpgw_opt_remove":           "Remove UDPGW port",
	"udpgw_opt_start":            "Start UDPGW port / service",
	"udpgw_opt_stop":             "Pause / stop UDPGW port",
	"udpgw_opt_restart":          "Restart UDPGW port",
	"udpgw_opt_adv":              "Advanced options (buffers, timeouts, metrics)",
	"udpgw_opt_logs":             "View service logs",
	"udpgw_adv_title":            "ADVANCED UDPGW",
	"udpgw_adv_network":          "Network (listen, udp-bind)",
	"udpgw_adv_metrics":          "Prometheus Metrics (-metrics-listen)",
	"udpgw_adv_perf":             "Performance (buffers, frame, channel)",
	"udpgw_adv_limits":           "Client limits",
	"udpgw_adv_timeouts":         "Timeouts & maintenance",
	"udpgw_adv_debug":            "Toggle debug mode (-debug)",
	"udpgw_adv_execstart":        "View ExecStart command",
	"udpgw_adv_apply":            "Save and apply to systemd",
	"tokens_menu_title":          "MANAGE LICENSE TOKENS",
	"onlines_menu_title":         "CONNECTED USERS (ONLINE)",

	// Advanced Menu
	"adv_menu_title":             "ADVANCED PROXY OPTIONS (JSON)",
	"adv_opt_perf":               "Performance & Timeouts (Buffer, Conns, Ulimit)",
	"adv_opt_http_logs":          "HTTP Response, Banner & Logs",
	"adv_opt_ssl":                "TLS / SSL Certificates (Internal / External)",
	"adv_opt_ssh":                "Native SSH Server (Zero-Fork)",
	"adv_opt_btun":               "BTUN / UDP DT-Proto Server",
	"adv_opt_limits":             "Connection Limits & Expiration (Limiter)",
	"adv_opt_connectors":         "Backend Connectors (OpenVPN, V2Ray) & XHTTP",
	"adv_opt_view_json":          "View config.json file",
	"adv_opt_finish":             "Finish / Back",

	// Limiter
	"limits_menu_title":          "CONNECTION LIMITS & EXPIRATION (LIMITER)",
	"limits_opt_enable":          "Enable Limiter (limits.enable)",
	"limits_opt_default_limit":   "Default Limit Per Account (0=unlimited)",
	"limits_opt_expire_check":    "Automatic Expired Users Check",
	"limits_opt_passwd_file":     "Limits / Password File (/etc/passwd)",

	// Status
	"status_online":              "ONLINE",
	"status_offline":             "OFFLINE",
	"status_active":              "ACTIVE",
	"status_inactive":            "INACTIVE",
	"service_running":            "Running",
	"service_stopped":            "Stopped",

	// Prompts
	"prompt_select_option":       "Select an option",
	"prompt_press_enter":         "Press [Enter] to continue...",
	"invalid_option":             "Invalid option!",
	"operation_success":          "Operation completed successfully.",
	"operation_failed":           "Operation failed.",
	"confirm_action":             "Do you confirm this action? (y/n)",
	"back":                       "Back",

	// Updates
	"update_title":               "SYSTEM & BINARIES UPDATE",
	"update_badge_available":     "NEW UPDATE!",
	"update_badge_current":       "UP TO DATE",
	"update_opt_apply":           "Update now (Binaries and Menu)",
	"update_opt_check_again":     "Force check on GitHub",
	"update_preserve_notice":     "Settings and ports will be 100% preserved.",
	"update_running":             "Downloading and applying official update...",
	"update_success":             "Update completed successfully!",
	"update_canceled":            "Update canceled.",
}

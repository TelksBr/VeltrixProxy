package menus

import (
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/proxy"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

// ShowAccountsMenu exibe o gerenciador completo de contas e credenciais do VTProxy
func ShowAccountsMenu(cfgMgr *config.Manager) {
	mgr := system.DefaultAccountManager()

	for {
		accounts, _ := mgr.ListAccounts()
		total := len(accounts)
		withUUID, active, expired, locked := 0, 0, 0, 0
		for _, a := range accounts {
			if a.HasUUID {
				withUUID++
			}
			switch a.Status {
			case system.StatusActive:
				active++
			case system.StatusExpired:
				expired++
			case system.StatusLocked:
				locked++
			}
		}

		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("accounts_menu_title"), theme.Cyan, w)

		statsLine := fmt.Sprintf("%s%s:%s %s%d%s (%s%d UUID%s) │ %s%s:%s %s%d%s │ %s%s:%s %s%d%s",
			theme.Gray, i18n.T("acc_label_total"), theme.Reset, theme.Cyan, total, theme.Reset,
			theme.Yellow, withUUID, theme.Reset,
			theme.Gray, i18n.T("acc_label_active"), theme.Reset, theme.Green, active, theme.Reset,
			theme.Gray, i18n.T("acc_label_expired"), theme.Reset, theme.Red, expired, theme.Reset,
		)
		components.PrintBoxLine(statsLine, w)
		components.PrintBoxDivider(w)

		components.PrintBoxLine(menuItem("1", i18n.T("acc_opt_create"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("acc_opt_list"), ""), w)
		components.PrintBoxLine(menuItem("3", i18n.T("acc_opt_details"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("4", i18n.T("acc_opt_change_pass"), ""), w)
		components.PrintBoxLine(menuItem("5", i18n.T("acc_opt_change_expiry"), ""), w)
		components.PrintBoxLine(menuItem("6", i18n.T("acc_opt_change_limit"), ""), w)
		components.PrintBoxLine(menuItem("7", i18n.T("acc_opt_manage_uuid"), ""), w)
		components.PrintBoxLine(menuItem("8", i18n.T("acc_opt_toggle_lock"), ""), w)
		components.PrintBoxLine(menuItem("9", i18n.T("acc_opt_delete"), ""), w)
		components.PrintBoxDivider(w)
		components.PrintBoxLine(menuItem("E", i18n.T("acc_opt_purge_expired"), ""), w)
		printMenuBack(w)

		switch readMenuOption("0-9/E") {
		case "1":
			createAccountWizard(cfgMgr, mgr)
		case "2":
			listAccountsTable(mgr)
		case "3":
			showAccountDetailsWizard(cfgMgr, mgr)
		case "4":
			changePasswordWizard(mgr)
		case "5":
			changeExpiryWizard(mgr)
		case "6":
			changeLimitWizard(mgr)
		case "7":
			manageUUIDWizard(mgr)
		case "8":
			toggleLockWizard(mgr)
		case "9":
			deleteAccountWizard(mgr)
		case "e":
			purgeExpiredWizard(mgr)
		case "0", "":
			return
		default:
			components.PrintError(i18n.T("invalid_option"))
			components.Pause()
		}
	}
}

func createAccountWizard(cfgMgr *config.Manager, mgr *system.AccountManager) {
	cfg, _ := cfgMgr.Get()

	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("acc_create_title"), theme.Cyan, w)
	components.PrintBoxFooter(w)

	// 1. Username
	username := ""
	for {
		username = strings.TrimSpace(strings.ToLower(components.Prompt(i18n.T("acc_prompt_username"), "")))
		if username == "" {
			return
		}
		if !system.IsValidUsername(username) {
			components.PrintError(i18n.T("acc_err_invalid_username"))
			continue
		}
		if _, err := mgr.GetAccount(username); err == nil {
			components.PrintError(fmt.Sprintf(i18n.T("acc_err_user_exists"), username))
			continue
		}
		break
	}

	// 2. Password
	defaultPass := system.GenerateSecurePassword(8)
	password := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_password"), defaultPass))
	if password == "" {
		password = defaultPass
	}

	// 3. Suporte a Xray com UUID?
	withUUID := components.Confirm(i18n.T("acc_prompt_enable_uuid"), true)
	uuidStr := ""
	if withUUID {
		generatedUUID := system.GenerateUUIDv4()
		for {
			uuidStr = strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_uuid"), generatedUUID))
			if uuidStr == "" {
				uuidStr = generatedUUID
			}
			norm, ok := system.NormalizeUUID(uuidStr)
			if !ok {
				components.PrintError(i18n.T("acc_err_invalid_uuid"))
				continue
			}
			uuidStr = norm
			break
		}
	}

	// 4. Limite de conexões
	defaultLimit := 1
	if cfg != nil && cfg.Limits.DefaultUserLimit > 0 {
		defaultLimit = cfg.Limits.DefaultUserLimit
	}
	limit := defaultLimit
	if limitInput := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_limit"), strconv.Itoa(defaultLimit))); limitInput != "" {
		if val, err := strconv.Atoi(limitInput); err == nil && val >= 0 {
			limit = val
		}
	}

	// 5. Validade em dias
	days := 30
	if daysInput := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_days"), "30")); daysInput != "" {
		if val, err := strconv.Atoi(daysInput); err == nil {
			days = val
		}
	}

	// Criação
	err := mgr.CreateAccount(username, password, uuidStr, limit, days)
	if err != nil {
		components.PrintError(fmt.Sprintf(i18n.T("acc_err_create_failed"), err))
		components.Pause()
		return
	}

	// Cartão de confirmação de criação
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("acc_created_success"), theme.Green, w)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_user"), theme.Reset, theme.White, username, theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_password"), theme.Reset, theme.Yellow, password, theme.Reset), w)

	accType := i18n.T("acc_type_ssh_pure")
	if uuidStr != "" {
		accType = i18n.T("acc_type_ssh_xray")
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_type"), theme.Reset, theme.Cyan, accType, theme.Reset), w)
	if uuidStr != "" {
		components.PrintBoxLine(fmt.Sprintf("%sUUID:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, uuidStr, theme.Reset), w)
	}

	limitText := i18n.T("acc_unlimited")
	if limit > 0 {
		limitText = fmt.Sprintf("%d", limit)
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_limit"), theme.Reset, theme.White, limitText, theme.Reset), w)

	expiryText := i18n.T("acc_unlimited")
	if days > 0 {
		targetDate := time.Now().AddDate(0, 0, days).Format("2006-01-02")
		expiryText = fmt.Sprintf(i18n.T("acc_days_format"), days) + " (" + targetDate + ")"
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_expiry"), theme.Reset, theme.White, expiryText, theme.Reset), w)
	components.PrintBoxFooter(w)

	// Se tiver UUID, oferece gerar links na hora
	if uuidStr != "" && cfg != nil && cfg.Xray.Enable {
		if components.Confirm(i18n.T("acc_created_ask_share"), true) {
			acc, _ := mgr.GetAccount(username)
			if acc != nil {
				generateXrayShareForAccount(acc, cfg)
				return
			}
		}
	}

	components.Pause()
}

func listAccountsTable(mgr *system.AccountManager) {
	components.ClearScreen()
	accounts, err := mgr.ListAccounts()
	if err != nil {
		components.PrintError(err.Error())
		components.Pause()
		return
	}

	if len(accounts) == 0 {
		components.PrintWarning(i18n.T("acc_none_found"))
		components.Pause()
		return
	}

	fmt.Printf("\n%s=== %s ===%s\n\n", theme.Cyan, i18n.T("acc_list_title"), theme.Reset)
	fmt.Printf("%-18s %-10s %-8s %-14s %-8s %-12s\n",
		i18n.T("acc_col_user"), i18n.T("acc_col_type"), i18n.T("acc_col_limit"),
		i18n.T("acc_col_expiry"), i18n.T("acc_col_conns"), i18n.T("acc_col_status"))
	fmt.Println(strings.Repeat("─", 74))

	for _, a := range accounts {
		typeStr := "SSH"
		if a.HasUUID {
			typeStr = "SSH+Xray"
		}

		limitStr := i18n.T("acc_unlimited")
		if a.Limit > 0 {
			limitStr = strconv.Itoa(a.Limit)
		}

		expiryStr := i18n.T("acc_unlimited")
		if a.ExpiryDays >= 0 {
			if a.DaysLeft > 0 {
				expiryStr = fmt.Sprintf(i18n.T("acc_days_format"), a.DaysLeft)
			} else if a.DaysLeft == 0 {
				expiryStr = i18n.T("acc_expires_today")
			} else {
				expiryStr = i18n.T("acc_status_expired")
			}
		}

		activeConns := proxy.GetUserSessionCount(a.Username)
		connsStr := fmt.Sprintf("%d/%s", activeConns, limitStr)

		statusBadge := theme.Green + "[" + i18n.T("acc_status_active") + "]" + theme.Reset
		switch a.Status {
		case system.StatusExpired:
			statusBadge = theme.Red + "[" + i18n.T("acc_status_expired") + "]" + theme.Reset
		case system.StatusLocked:
			statusBadge = theme.Yellow + "[" + i18n.T("acc_status_locked") + "]" + theme.Reset
		}

		fmt.Printf("%-18s %-10s %-8s %-14s %-8s %s\n",
			a.Username, typeStr, limitStr, expiryStr, connsStr, statusBadge)
	}

	fmt.Println(strings.Repeat("─", 74))
	fmt.Printf("%sTotal: %d contas%s\n\n", theme.Gray, len(accounts), theme.Reset)
	components.Pause()
}

func showAccountDetailsWizard(cfgMgr *config.Manager, mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}
	cfg, _ := cfgMgr.Get()

	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("acc_details_title"), theme.Cyan, w)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_user"), theme.Reset, theme.White, acc.Username, theme.Reset), w)

	typeStr := i18n.T("acc_type_ssh_pure")
	if acc.HasUUID {
		typeStr = i18n.T("acc_type_ssh_xray")
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_type"), theme.Reset, theme.Cyan, typeStr, theme.Reset), w)

	if acc.HasUUID {
		components.PrintBoxLine(fmt.Sprintf("%sUUID:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, acc.UUID, theme.Reset), w)
	}

	limitStr := i18n.T("acc_unlimited")
	if acc.Limit > 0 {
		limitStr = strconv.Itoa(acc.Limit)
	}
	activeConns := proxy.GetUserSessionCount(acc.Username)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s │ %s%s:%s %s%d%s",
		theme.Gray, i18n.T("acc_label_limit"), theme.Reset, theme.White, limitStr, theme.Reset,
		theme.Gray, i18n.T("acc_col_conns"), theme.Reset, theme.Cyan, activeConns, theme.Reset), w)

	expiryStr := i18n.T("acc_unlimited")
	if acc.ExpiryDays >= 0 {
		if acc.DaysLeft > 0 {
			expiryStr = fmt.Sprintf(i18n.T("acc_days_format"), acc.DaysLeft) + " (" + acc.ExpiryDate + ")"
		} else if acc.DaysLeft == 0 {
			expiryStr = i18n.T("acc_expires_today") + " (" + acc.ExpiryDate + ")"
		} else {
			expiryStr = i18n.T("acc_status_expired") + " (" + acc.ExpiryDate + ")"
		}
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_expiry"), theme.Reset, theme.White, expiryStr, theme.Reset), w)

	statusStr := theme.Green + i18n.T("acc_status_active") + theme.Reset
	switch acc.Status {
	case system.StatusExpired:
		statusStr = theme.Red + i18n.T("acc_status_expired") + theme.Reset
	case system.StatusLocked:
		statusStr = theme.Yellow + i18n.T("acc_status_locked") + theme.Reset
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s", theme.Gray, i18n.T("acc_label_status"), theme.Reset, statusStr), w)
	components.PrintBoxDivider(w)

	if acc.HasUUID {
		components.PrintBoxLine(menuItem("1", i18n.T("acc_opt_gen_links"), ""), w)
	} else {
		components.PrintBoxLine(menuItem("1", i18n.T("acc_opt_upgrade_uuid"), ""), w)
	}
	printMenuBack(w)

	switch readMenuOption("0-1") {
	case "1":
		if acc.HasUUID {
			if cfg != nil {
				generateXrayShareForAccount(acc, cfg)
			}
		} else {
			if components.Confirm(i18n.T("acc_confirm_upgrade_uuid"), true) {
				newUUID := system.GenerateUUIDv4()
				if err := mgr.SetUUID(acc.Username, newUUID); err == nil {
					components.PrintSuccess(fmt.Sprintf(i18n.T("acc_uuid_updated"), acc.Username, newUUID))
				} else {
					components.PrintError(err.Error())
				}
				components.Pause()
			}
		}
	}
}

func changePasswordWizard(mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}

	defaultPass := system.GenerateSecurePassword(8)
	newPass := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_new_password"), defaultPass))
	if newPass == "" {
		newPass = defaultPass
	}

	if err := mgr.UpdatePassword(acc.Username, newPass); err != nil {
		components.PrintError(fmt.Sprintf(i18n.T("acc_err_update_failed"), err))
	} else {
		components.PrintSuccess(fmt.Sprintf(i18n.T("acc_pass_updated"), acc.Username))
	}
	components.Pause()
}

func changeExpiryWizard(mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}

	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("acc_change_expiry_title"), theme.Cyan, w)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s", theme.Gray, i18n.T("acc_label_user"), theme.Reset, acc.Username), w)
	currentExp := i18n.T("acc_unlimited")
	if acc.ExpiryDays >= 0 {
		currentExp = fmt.Sprintf(i18n.T("acc_days_format"), acc.DaysLeft) + " (" + acc.ExpiryDate + ")"
	}
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s", theme.Gray, i18n.T("acc_label_expiry"), theme.Reset, currentExp), w)
	components.PrintBoxDivider(w)
	components.PrintBoxLine(menuItem("1", i18n.T("acc_opt_expiry_add_days"), ""), w)
	components.PrintBoxLine(menuItem("2", i18n.T("acc_opt_expiry_unlimited"), ""), w)
	components.PrintBoxLine(menuItem("3", i18n.T("acc_opt_expiry_expire_now"), ""), w)
	printMenuBack(w)

	switch readMenuOption("0-3") {
	case "1":
		daysInput := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_days_add"), "30"))
		if days, err := strconv.Atoi(daysInput); err == nil && days > 0 {
			if err := mgr.UpdateExpiryDays(acc.Username, days); err == nil {
				components.PrintSuccess(fmt.Sprintf(i18n.T("acc_expiry_updated"), acc.Username))
			} else {
				components.PrintError(err.Error())
			}
		}
		components.Pause()
	case "2":
		if err := mgr.UpdateExpiryDays(acc.Username, -1); err == nil {
			components.PrintSuccess(fmt.Sprintf(i18n.T("acc_expiry_updated"), acc.Username))
		} else {
			components.PrintError(err.Error())
		}
		components.Pause()
	case "3":
		if err := mgr.UpdateExpiryDays(acc.Username, 0); err == nil {
			components.PrintSuccess(fmt.Sprintf(i18n.T("acc_expiry_updated"), acc.Username))
		} else {
			components.PrintError(err.Error())
		}
		components.Pause()
	}
}

func changeLimitWizard(mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}

	curLimitStr := strconv.Itoa(acc.Limit)
	newLimitStr := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_limit"), curLimitStr))
	if val, err := strconv.Atoi(newLimitStr); err == nil && val >= 0 {
		if err := mgr.UpdateLimit(acc.Username, val); err == nil {
			components.PrintSuccess(fmt.Sprintf(i18n.T("acc_limit_updated"), acc.Username, val))
		} else {
			components.PrintError(err.Error())
		}
	}
	components.Pause()
}

func manageUUIDWizard(mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}

	if !acc.HasUUID {
		if components.Confirm(i18n.T("acc_confirm_upgrade_uuid"), true) {
			newUUID := system.GenerateUUIDv4()
			if err := mgr.SetUUID(acc.Username, newUUID); err == nil {
				components.PrintSuccess(fmt.Sprintf(i18n.T("acc_uuid_updated"), acc.Username, newUUID))
			} else {
				components.PrintError(err.Error())
			}
			components.Pause()
		}
		return
	}

	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("acc_manage_uuid_title"), theme.Cyan, w)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s", theme.Gray, i18n.T("acc_label_user"), theme.Reset, acc.Username), w)
	components.PrintBoxLine(fmt.Sprintf("%sUUID atual:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, acc.UUID, theme.Reset), w)
	components.PrintBoxDivider(w)
	components.PrintBoxLine(menuItem("1", i18n.T("acc_opt_uuid_rotate"), ""), w)
	components.PrintBoxLine(menuItem("2", i18n.T("acc_opt_uuid_custom"), ""), w)
	components.PrintBoxLine(menuItem("3", i18n.T("acc_opt_uuid_remove"), ""), w)
	printMenuBack(w)

	switch readMenuOption("0-3") {
	case "1":
		newUUID := system.GenerateUUIDv4()
		if err := mgr.SetUUID(acc.Username, newUUID); err == nil {
			components.PrintSuccess(fmt.Sprintf(i18n.T("acc_uuid_updated"), acc.Username, newUUID))
		} else {
			components.PrintError(err.Error())
		}
		components.Pause()
	case "2":
		custom := strings.TrimSpace(components.Prompt(i18n.T("acc_prompt_uuid"), acc.UUID))
		if norm, ok := system.NormalizeUUID(custom); ok {
			if err := mgr.SetUUID(acc.Username, norm); err == nil {
				components.PrintSuccess(fmt.Sprintf(i18n.T("acc_uuid_updated"), acc.Username, norm))
			} else {
				components.PrintError(err.Error())
			}
		} else {
			components.PrintError(i18n.T("acc_err_invalid_uuid"))
		}
		components.Pause()
	case "3":
		if components.Confirm(i18n.T("acc_confirm_uuid_remove"), false) {
			if err := mgr.RemoveUUID(acc.Username); err == nil {
				components.PrintSuccess(fmt.Sprintf(i18n.T("acc_uuid_removed"), acc.Username))
			} else {
				components.PrintError(err.Error())
			}
			components.Pause()
		}
	}
}

func toggleLockWizard(mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}

	if acc.Status == system.StatusLocked {
		if components.Confirm(fmt.Sprintf(i18n.T("acc_confirm_unlock"), acc.Username), true) {
			if err := mgr.UnlockAccount(acc.Username); err == nil {
				components.PrintSuccess(fmt.Sprintf(i18n.T("acc_unlocked_done"), acc.Username))
			} else {
				components.PrintError(err.Error())
			}
			components.Pause()
		}
	} else {
		if components.Confirm(fmt.Sprintf(i18n.T("acc_confirm_lock"), acc.Username), true) {
			if err := mgr.LockAccount(acc.Username); err == nil {
				components.PrintSuccess(fmt.Sprintf(i18n.T("acc_locked_done"), acc.Username))
			} else {
				components.PrintError(err.Error())
			}
			components.Pause()
		}
	}
}

func deleteAccountWizard(mgr *system.AccountManager) {
	acc := selectAccountPrompt(mgr)
	if acc == nil {
		return
	}

	if components.Confirm(fmt.Sprintf(i18n.T("acc_confirm_delete"), acc.Username), false) {
		if err := mgr.DeleteAccount(acc.Username); err == nil {
			components.PrintSuccess(fmt.Sprintf(i18n.T("acc_deleted_done"), acc.Username))
		} else {
			components.PrintError(err.Error())
		}
		components.Pause()
	}
}

func purgeExpiredWizard(mgr *system.AccountManager) {
	accounts, err := mgr.ListAccounts()
	if err != nil {
		components.PrintError(err.Error())
		components.Pause()
		return
	}

	expiredList := make([]string, 0)
	for _, a := range accounts {
		if a.Status == system.StatusExpired {
			expiredList = append(expiredList, a.Username)
		}
	}

	if len(expiredList) == 0 {
		components.PrintSuccess(i18n.T("acc_purge_none"))
		components.Pause()
		return
	}

	components.PrintWarning(fmt.Sprintf(i18n.T("acc_purge_found"), len(expiredList), strings.Join(expiredList, ", ")))
	if components.Confirm(fmt.Sprintf(i18n.T("acc_confirm_purge"), len(expiredList)), false) {
		count, err := mgr.PurgeExpiredAccounts()
		if err != nil {
			components.PrintError(err.Error())
		} else {
			components.PrintSuccess(fmt.Sprintf(i18n.T("acc_purge_done"), count))
		}
		components.Pause()
	}
}

func selectAccountPrompt(mgr *system.AccountManager) *system.Account {
	for {
		username := strings.TrimSpace(components.Prompt(i18n.T("acc_select_user"), ""))
		if username == "" {
			return nil
		}
		acc, err := mgr.GetAccount(username)
		if err != nil {
			components.PrintError(fmt.Sprintf(i18n.T("acc_err_not_found"), username))
			continue
		}
		return acc
	}
}

func generateXrayShareForAccount(acc *system.Account, cfg *config.Config) {
	w := components.GetBoxWidth()
	components.ClearScreen()
	components.PrintBoxHeader(i18n.T("xray_share_title"), theme.Cyan, w)
	components.PrintBoxLine(fmt.Sprintf("%s%s:%s %s%s%s", theme.Gray, i18n.T("acc_label_user"), theme.Reset, theme.White, acc.Username, theme.Reset), w)
	components.PrintBoxLine(fmt.Sprintf("%sUUID:%s %s%s%s", theme.Gray, theme.Reset, theme.Cyan, acc.UUID, theme.Reset), w)
	components.PrintBoxFooter(w)

	proxyAddr := strings.TrimSpace(components.Prompt(i18n.T("xray_share_proxy"), ""))
	if proxyAddr == "" {
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

	transports := cfg.Xray.Transports
	if len(cfg.Xray.Transports) > 1 {
		resp := components.Prompt(i18n.T("xray_share_transport"), config.ShareTransportPrompt(cfg.Xray.Transports))
		picked := intersectXrayList(splitCSV(resp), cfg.Xray.Transports, cfg.Xray.AllowsTransport)
		if len(picked) > 0 {
			transports = picked
		}
	}

	links, err := config.BuildXrayShareLinks(config.XrayShareParams{
		UUID:        acc.UUID,
		Address:     proxyAddr,
		Host:        host,
		SNI:         sni,
		Port:        port,
		Path:        cfg.Xray.Path,
		Remark:      "Veltrix-" + acc.Username,
		TLS:         useTLS,
		PCS:         pcs,
		Protocols:   []string{proto},
		Transports:  transports,
		GRPCService: cfg.Xray.GRPCService,
	})
	if err != nil {
		components.PrintError(err.Error())
		components.Pause()
		return
	}

	fmt.Println()
	summary := fmt.Sprintf("%s: %s:%d   %s: %s", i18n.T("xray_share_label_proxy"), proxyAddr, port, i18n.T("xray_share_label_host"), host)
	if useTLS {
		summary += fmt.Sprintf("   SNI: %s", sni)
	}
	fmt.Printf("%s%s%s\n\n", theme.Gray, summary, theme.Reset)
	for _, link := range links {
		fmt.Printf("%s%s%s\n%s\n\n", theme.Cyan, link.Label, theme.Reset, link.URI)
	}
	components.Pause()
}


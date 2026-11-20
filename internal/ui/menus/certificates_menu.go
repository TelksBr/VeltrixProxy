package menus

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/i18n"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/components"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

func showManagedSSLMenu(mgr *config.Manager) {
	for {
		cfg, ok := loadConfigOrWarn(mgr)
		if !ok {
			return
		}
		w := components.GetBoxWidth()
		components.ClearScreen()
		components.PrintBoxHeader(i18n.T("acme_title"), theme.Cyan, w)
		components.PrintBoxLine(i18n.T("acme_domain")+": "+displayOrEmpty(cfg.SSL.Domain), w)
		components.PrintBoxLine(menuItem("1", i18n.T("acme_check"), ""), w)
		components.PrintBoxLine(menuItem("2", i18n.T("acme_issue"), ""), w)
		components.PrintBoxLine(menuItem("3", i18n.T("acme_staging"), ""), w)
		components.PrintBoxLine(menuItem("4", i18n.T("acme_status"), ""), w)
		components.PrintBoxLine(menuItem("5", i18n.T("acme_renew"), ""), w)
		components.PrintBoxLine(menuItem("6", i18n.T("acme_auto"), featureBadge(cfg.SSL.RenewEnabled())), w)
		components.PrintBoxLine(menuItem("7", i18n.T("acme_disable"), ""), w)
		printMenuBack(w)
		choice := readMenuOption("0-7")
		switch choice {
		case "1":
			if ensureACMEPort(mgr, cfg) {
				runCertificateAction(mgr, cfg, "check", false)
			}
		case "2", "3":
			if ensureACMEPort(mgr, cfg) {
				issueCertificateInteractive(mgr, cfg, choice == "3")
			}
		case "4":
			runCertificateAction(mgr, cfg, "status", false)
		case "5":
			if ensureACMEPort(mgr, cfg) {
				runCertificateAction(mgr, cfg, "renew", false)
			}
		case "6":
			v := !cfg.SSL.RenewEnabled()
			cfg.SSL.AutoRenew = &v
			saveField(mgr, cfg, "ssl.auto_renew")
			components.Pause()
		case "7":
			if components.Confirm(i18n.T("acme_disable_confirm"), false) {
				cfg.SSL.Domain = ""
				cfg.Cert, cfg.CertInternal = "", true
				saveField(mgr, cfg, "ssl.domain")
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

func ensureACMEPort(mgr *config.Manager, cfg *config.Config) bool {
	has80 := false
	for _, port := range cfg.Ports {
		if entry, err := config.ParsePortEntry(port); err == nil && entry.Port == 80 {
			has80 = true
		}
	}
	if !has80 {
		if !components.Confirm(i18n.T("acme_add80"), false) {
			return false
		}
		if busy, _ := system.IsPortInUseByOther("tcp", 80); busy {
			components.PrintError(i18n.T("acme_port_busy"))
			components.Pause()
			return false
		}
		previous := *cfg
		cfg.Ports = append(append(config.PortList(nil), cfg.Ports...), "80")
		if err := mgr.Save(cfg); err != nil {
			*cfg = previous
			components.PrintError(err.Error())
			components.Pause()
			return false
		}
		if err := system.RestartService(system.ProxyServiceName); err != nil {
			*cfg = previous
			if rollbackErr := mgr.Save(cfg); rollbackErr != nil {
				components.PrintError(rollbackErr.Error())
			} else {
				_ = system.RestartService(system.ProxyServiceName)
			}
			components.PrintError(err.Error())
			components.Pause()
			return false
		}
	} else if !system.IsServiceActive(system.ProxyServiceName) {
		if !components.Confirm(i18n.T("acme_start_proxy"), false) {
			return false
		}
		if err := system.StartService(system.ProxyServiceName); err != nil {
			components.PrintError(err.Error())
			components.Pause()
			return false
		}
	}
	return true
}

func issueCertificateInteractive(mgr *config.Manager, cfg *config.Config, staging bool) {
	components.PrintInfo(i18n.T("acme_requirements"))
	domain := strings.TrimSpace(components.Prompt(i18n.T("acme_domain"), cfg.SSL.Domain))
	email := strings.TrimSpace(components.Prompt(i18n.T("acme_email"), ""))
	if !components.Confirm(i18n.T("acme_terms"), false) {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	components.PrintInfo(i18n.T("acme_working"))
	result, err := system.CertificateCommand(ctx, mgr.Path(), "issue", domain, email, staging, true)
	if err != nil {
		components.PrintError(err.Error())
		components.Pause()
		return
	}
	if staging {
		components.PrintWarning(i18n.T("acme_staging_done"))
		components.Pause()
		return
	}
	if result.Certificate.Staging || result.Certificate.NotAfter.Before(time.Now()) {
		components.PrintError(i18n.T("acme_invalid"))
		components.Pause()
		return
	}
	previous := *cfg
	cfg.SSL.Domain, cfg.Cert = result.Certificate.Domain, ""
	v := true
	cfg.SSL.AutoRenew = &v
	if err := mgr.Save(cfg); err != nil {
		*cfg = previous
		components.PrintError(err.Error())
	} else {
		components.PrintSuccess(i18n.T("acme_saved"))
	}
	components.Pause()
}

func runCertificateAction(mgr *config.Manager, cfg *config.Config, action string, staging bool) {
	domain := cfg.SSL.Domain
	if action == "check" || domain == "" {
		domain = strings.TrimSpace(components.Prompt(i18n.T("acme_domain"), domain))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	components.PrintInfo(i18n.T("acme_working"))
	result, err := system.CertificateCommand(ctx, mgr.Path(), action, domain, "", staging, false)
	if err != nil {
		components.PrintError(err.Error())
		components.Pause()
		return
	}
	if action == "check" {
		components.PrintSuccess(i18n.T("acme_check_done"))
	} else {
		cert := result.Certificate
		fmt.Printf("\n%s: %s\n%s: %s\nSHA-256: %s\n", i18n.T("acme_domain"), cert.Domain, i18n.T("acme_expiry"), cert.NotAfter.Local().Format("2006-01-02 15:04 MST"), cert.Fingerprint)
		if cert.LastError != "" {
			components.PrintWarning(cert.LastError)
		}
		if !cert.NextAttempt.IsZero() {
			fmt.Println(cert.NextAttempt.Local().Format(time.RFC3339))
		}
		components.PrintInfo(i18n.T("acme_reload_hint"))
	}
	components.Pause()
}

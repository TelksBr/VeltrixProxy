package system

import (
	"os"
	"os/exec"
	"path/filepath"
)

// UninstallStep representa um passo de desinstalação
type UninstallStep struct {
	Name        string
	Description string
	Action      func() error
}

// GetUninstallSteps retorna a lista ordenada de passos necessários para desinstalar completamente o VTProxy
func GetUninstallSteps() []UninstallStep {
	return []UninstallStep{
		{
			Name:        "Serviços Systemd",
			Description: "Parando e desabilitando serviços do proxy e udpgw...",
			Action:      stopAndDisableServices,
		},
		{
			Name:        "Arquivos Systemd",
			Description: "Removendo units e drop-ins do systemd...",
			Action:      removeSystemdUnits,
		},
		{
			Name:        "Otimizações de Kernel & Sysctl",
			Description: "Removendo configurações de sysctl e restaurando parâmetros...",
			Action:      removeKernelAndSysctlConfigs,
		},
		{
			Name:        "Limites de Segurança & Conexões",
			Description: "Removendo limites customizados (limits.d e profile.d)...",
			Action:      removeSecurityLimitsConfigs,
		},
		{
			Name:        "Drop-ins SSH",
			Description: "Removendo configurações drop-in do OpenSSH...",
			Action:      removeSSHDropIns,
		},
		{
			Name:        "Regras & Scripts de Firewall",
			Description: "Removendo scripts do iptables e regras de redirecionamento...",
			Action:      removeFirewallRules,
		},
		{
			Name:        "Configurações, Tokens e Logs",
			Description: "Removendo /etc/proxyvt, /etc/vtproxy, /etc/proxy, /etc/udpgw e logs...",
			Action:      removeConfigFilesAndLogs,
		},
		{
			Name:        "Binários do Sistema",
			Description: "Removendo binários (proxy-server, udpgw, vt-iptables e vt)...",
			Action:      removeInstalledBinaries,
		},
	}
}

func stopAndDisableServices() error {
	// Lista de serviços do VTProxy e UDPGW
	services := []string{"vtproxy"}

	// Busca serviços dinâmicos de udpgw e proxy legados
	if matches, err := filepath.Glob("/etc/systemd/system/udpgw*.service"); err == nil {
		for _, m := range matches {
			services = append(services, filepath.Base(m))
		}
	}
	if matches, err := filepath.Glob("/etc/systemd/system/proxy-*.service"); err == nil {
		for _, m := range matches {
			services = append(services, filepath.Base(m))
		}
	}

	for _, svc := range services {
		_ = exec.Command("systemctl", "stop", svc).Run()
		_ = exec.Command("systemctl", "disable", svc).Run()
	}
	return nil
}

func removeSystemdUnits() error {
	patterns := []string{
		"/etc/systemd/system/vtproxy.service",
		"/etc/systemd/system/proxy-*.service",
		"/etc/systemd/system/udpgw.service",
		"/etc/systemd/system/udpgw-*.service",
		"/etc/systemd/system/ssh.service.d/99-limits.conf",
		"/etc/systemd/system/sshd.service.d/99-limits.conf",
	}

	for _, p := range patterns {
		matches, err := filepath.Glob(p)
		if err == nil {
			for _, f := range matches {
				_ = os.Remove(f)
			}
		}
	}

	// Limpa diretórios vazios de drop-in caso tenham sido criados
	_ = os.Remove("/etc/systemd/system/ssh.service.d")
	_ = os.Remove("/etc/systemd/system/sshd.service.d")

	_ = exec.Command("systemctl", "daemon-reload").Run()
	_ = exec.Command("systemctl", "reset-failed").Run()
	return nil
}

func removeKernelAndSysctlConfigs() error {
	sysctlFiles := []string{
		"/etc/sysctl.d/99-proxy.conf",
		"/etc/sysctl.d/99-vtproxy.conf",
		"/etc/sysctl.d/99-veltrix-proxy.conf",
		"/etc/sysctl.d/zz-custom-network.conf",
	}

	for _, f := range sysctlFiles {
		_ = os.Remove(f)
	}

	// Recarrega parâmetros nativos do sistema se o comando existir
	if _, err := exec.LookPath("sysctl"); err == nil {
		_ = exec.Command("sysctl", "--system").Run()
	}
	return nil
}

func removeSecurityLimitsConfigs() error {
	limitsFiles := []string{
		"/etc/security/limits.d/99-proxy.conf",
		"/etc/security/limits.d/99-veltrix-proxy.conf",
		"/etc/profile.d/99-proxy-limits.sh",
	}

	for _, f := range limitsFiles {
		_ = os.Remove(f)
	}
	return nil
}

func removeSSHDropIns() error {
	dropInFiles := []string{
		"/etc/ssh/sshd_config.d/99-vtproxy.conf",
		"/etc/ssh/sshd_config.d/99-veltrix-proxy.conf",
	}

	for _, f := range dropInFiles {
		_ = os.Remove(f)
	}

	// Reinicia serviço de SSH para restaurar as configurações nativas
	if _, err := exec.LookPath("systemctl"); err == nil {
		_ = exec.Command("systemctl", "restart", "ssh").Run()
		_ = exec.Command("systemctl", "restart", "sshd").Run()
	}
	return nil
}

func removeFirewallRules() error {
	_ = os.Remove("/usr/local/bin/vt-iptables")

	// Flush básico em regras de redirecionamento ou interfaces tun caso iptables exista
	if _, err := exec.LookPath("iptables"); err == nil {
		_ = exec.Command("iptables", "-D", "INPUT", "-i", "tun+", "-j", "ACCEPT").Run()
		_ = exec.Command("iptables", "-D", "FORWARD", "-i", "tun+", "-j", "ACCEPT").Run()
		_ = exec.Command("iptables", "-D", "FORWARD", "-o", "tun+", "-j", "ACCEPT").Run()
	}
	return nil
}

func removeConfigFilesAndLogs() error {
	dirs := []string{
		"/etc/proxyvt",
		"/etc/vtproxy",
		"/etc/proxy",
		"/etc/udpgw",
		"/etc/btun",
		"/var/log/proxy",
	}

	for _, d := range dirs {
		_ = os.RemoveAll(d)
	}

	// Arquivos avulsos de versão, estado e tokens
	files := []string{
		"/etc/vt-menu-revision",
		"/etc/proxy-version",
		"/etc/udpgw-version",
		"/etc/proxyvt-version",
		"/tmp/.vt_update_check.json",
		"/root/.proxy_token",
	}

	if home := os.Getenv("HOME"); home != "" {
		files = append(files, filepath.Join(home, ".proxy_token"))
	}

	for _, f := range files {
		_ = os.Remove(f)
	}

	return nil
}

func removeInstalledBinaries() error {
	binaries := []string{
		"/usr/local/bin/proxy-server",
		"/usr/local/bin/udpgw",
		"/usr/local/bin/vt-iptables",
		"/usr/local/bin/vt.sh",
		"/usr/local/bin/vt",
	}

	// Se o binário em execução estiver em outro local, remove também
	if exe, err := os.Executable(); err == nil && exe != "" {
		binaries = append(binaries, exe)
	}

	for _, b := range binaries {
		_ = os.Remove(b)
	}

	return nil
}

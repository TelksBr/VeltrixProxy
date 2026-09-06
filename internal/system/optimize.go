package system

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// ApplyFileDescriptorLimits configura limites de sockets e descritores (65536)
func ApplyFileDescriptorLimits() error {
	limitsContent := `# VeltrixProxy - File Descriptors & Sockets Limits (65536)
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
* soft nproc 65536
* hard nproc 65536
root soft nproc 65536
root hard nproc 65536
`
	_ = os.MkdirAll("/etc/security/limits.d", 0755)
	if err := os.WriteFile("/etc/security/limits.d/99-proxy.conf", []byte(limitsContent), 0644); err != nil {
		return fmt.Errorf("falha ao gravar /etc/security/limits.d/99-proxy.conf: %w", err)
	}

	profileScript := "ulimit -n 65536 2>/dev/null || true\n"
	_ = os.MkdirAll("/etc/profile.d", 0755)
	_ = os.WriteFile("/etc/profile.d/99-proxy-limits.sh", []byte(profileScript), 0644)

	// systemd limits overrides
	svcDir := "/etc/systemd/system/vtproxy.service.d"
	_ = os.MkdirAll(svcDir, 0755)
	sysdLimits := "[Service]\nLimitNOFILE=65536\nLimitNPROC=65536\n"
	_ = os.WriteFile(filepath.Join(svcDir, "99-limits.conf"), []byte(sysdLimits), 0644)

	_ = DaemonReload()
	return nil
}

// ApplyKernelOptimizations aplica ajustes de rede de alta performance (BBR, buffers TCP, queues)
func ApplyKernelOptimizations() error {
	sysctlContent := `# VeltrixProxy - Otimizacoes de Rede de Alta Performance & TCP BBR
fs.file-max = 2097152
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
`
	_ = os.MkdirAll("/etc/sysctl.d", 0755)
	filePath := "/etc/sysctl.d/99-proxy.conf"
	if err := os.WriteFile(filePath, []byte(sysctlContent), 0644); err != nil {
		return fmt.Errorf("falha ao gravar %s: %w", filePath, err)
	}

	cmd := exec.Command("sysctl", "-p", filePath)
	_ = cmd.Run()

	return nil
}

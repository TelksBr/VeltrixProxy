package system

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"strings"
	"time"
)

var (
	ssUserRegex = regexp.MustCompile(`users:\(\("([^"]+)",(?:pid=)?(\d+)`)
)

// CheckTCPPortAvailable verifica se uma porta TCP está livre para escuta (bind).
// Retorna available = true se estiver livre. Caso ocupada, retorna available = false e
// tenta identificar o processo conflitante (ex: "nginx (PID: 1234)").
func CheckTCPPortAvailable(port int) (available bool, processInfo string) {
	if port <= 0 || port > 65535 {
		return false, "número de porta inválido"
	}

	// 1. Tenta escutar na porta IPv4
	addr := fmt.Sprintf("0.0.0.0:%d", port)
	ln, err := net.Listen("tcp4", addr)
	if err == nil {
		_ = ln.Close()
		// Também testa dual-stack se aplicável
		lnDual, errDual := net.Listen("tcp", fmt.Sprintf(":%d", port))
		if errDual == nil {
			_ = lnDual.Close()
			return true, ""
		}
	}

	// Porta ocupada, busca detalhes do processo
	procInfo := findProcessUsingPort("tcp", port)
	if procInfo == "" {
		procInfo = "processo desconhecido (porta em uso)"
	}
	return false, procInfo
}

// CheckUDPPortAvailable verifica se uma porta UDP está livre para bind.
// Retorna available = true se estiver livre. Caso ocupada, retorna available = false e
// o nome/PID do processo conflitante.
func CheckUDPPortAvailable(port int) (available bool, processInfo string) {
	if port <= 0 || port > 65535 {
		return false, "número de porta inválido"
	}

	addr := fmt.Sprintf("0.0.0.0:%d", port)
	pc, err := net.ListenPacket("udp4", addr)
	if err == nil {
		_ = pc.Close()
		pcDual, errDual := net.ListenPacket("udp", fmt.Sprintf(":%d", port))
		if errDual == nil {
			_ = pcDual.Close()
			return true, ""
		}
	}

	procInfo := findProcessUsingPort("udp", port)
	if procInfo == "" {
		procInfo = "processo desconhecido (porta em uso)"
	}
	return false, procInfo
}

// findProcessUsingPort tenta identificar qual programa está escutando na porta especificada.
func findProcessUsingPort(proto string, port int) string {
	if runtime.GOOS == "windows" {
		return findProcessWindows(proto, port)
	}
	return findProcessLinux(proto, port)
}

func findProcessLinux(proto string, port int) string {
	// 1. Tenta via 'ss'
	ssFlag := "-tlpn"
	if proto == "udp" {
		ssFlag = "-ulpn"
	}

	cmdSS := exec.Command("ss", ssFlag, "sport", "=", fmt.Sprintf(":%d", port))
	out, err := cmdSS.Output()
	if err != nil || len(out) == 0 {
		// Tenta formato de argumento único
		cmdSS = exec.Command("ss", ssFlag, fmt.Sprintf("sport = :%d", port))
		out, _ = cmdSS.Output()
	}
	if len(out) > 0 {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			if strings.Contains(line, "users:") {
				matches := ssUserRegex.FindStringSubmatch(line)
				if len(matches) >= 3 {
					return fmt.Sprintf("%s (PID: %s)", matches[1], matches[2])
				}
			}
		}
	}

	// 2. Fallback via 'lsof'
	lsofProto := fmt.Sprintf("-iTCP:%d", port)
	if proto == "udp" {
		lsofProto = fmt.Sprintf("-iUDP:%d", port)
	}
	cmdLsof := exec.Command("lsof", "-nP", lsofProto)
	if out, err := cmdLsof.Output(); err == nil && len(out) > 0 {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) > 1 {
			// Primeira linha de cabeçalho, segunda linha é o processo
			fields := strings.Fields(lines[1])
			if len(fields) >= 2 {
				return fmt.Sprintf("%s (PID: %s)", fields[0], fields[1])
			}
		}
	}

	// 3. Fallback via 'fuser'
	cmdFuser := exec.Command("fuser", fmt.Sprintf("%d/%s", port, proto))
	if out, err := cmdFuser.Output(); err == nil {
		pids := strings.Fields(strings.TrimSpace(string(out)))
		if len(pids) > 0 {
			pid := pids[0]
			// Tenta obter o nome do processo via /proc/<pid>/comm
			if commBytes, errComm := os.ReadFile(fmt.Sprintf("/proc/%s/comm", pid)); errComm == nil {
				comm := strings.TrimSpace(string(commBytes))
				if comm != "" {
					return fmt.Sprintf("%s (PID: %s)", comm, pid)
				}
			}
			return fmt.Sprintf("PID %s", pid)
		}
	}

	return ""
}

func findProcessWindows(proto string, port int) string {
	// No Windows, usa netstat
	cmd := exec.Command("netstat", "-ano")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}

	portTarget := fmt.Sprintf(":%d", port)
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) >= 4 && strings.EqualFold(fields[0], proto) {
			if strings.HasSuffix(fields[1], portTarget) {
				pid := fields[len(fields)-1]
				return fmt.Sprintf("PID %s", pid)
			}
		}
	}

	return ""
}

// IsOwnProxyProcess verifica se o processo identificado pertence ao próprio VTProxy / proxy-server
func IsOwnProxyProcess(procInfo string) bool {
	clean := strings.ToLower(procInfo)
	return strings.Contains(clean, "proxy-server") || strings.Contains(clean, "vtproxy")
}

// IsOwnServiceProcess verifica se o processo pertence ao VTProxy ou ao BadVPN / UDPGW
func IsOwnServiceProcess(procInfo string) bool {
	clean := strings.ToLower(procInfo)
	return strings.Contains(clean, "proxy-server") ||
		strings.Contains(clean, "vtproxy") ||
		strings.Contains(clean, "udpgw")
}

// IsPortInUseByOther verifica se a porta especificada está ocupada por um processo ESTRANHO (não pertencente ao VTProxy/UDPGW).
// Retorna inUse = true apenas se houver conflito real com processos de terceiros (ex: nginx, apache, systemd-resolved).
func IsPortInUseByOther(proto string, port int) (inUse bool, processInfo string) {
	var avail bool
	var proc string

	if strings.ToLower(proto) == "udp" {
		avail, proc = CheckUDPPortAvailable(port)
	} else {
		avail, proc = CheckTCPPortAvailable(port)
	}

	if avail {
		return false, ""
	}

	if IsOwnServiceProcess(proc) {
		// Ocupado pelo próprio VTProxy ou UDPGW: não é conflito impeditivo
		return false, proc
	}

	return true, proc
}

// EnsurePortNotBusy testa a porta e retorna erro descritivo caso esteja ocupada por processo estranho
func EnsurePortNotBusy(proto string, port int) error {
	inUse, procInfo := IsPortInUseByOther(proto, port)
	if inUse {
		return fmt.Errorf("porta %s/%d já está em uso por %s", strings.ToUpper(proto), port, procInfo)
	}
	return nil
}

// CheckConfiguredPortsConflict verifica se alguma das portas configuradas está ocupada por processos externos.
// Retorna uma lista com a descrição de cada conflito detectado.
func CheckConfiguredPortsConflict(ports []string, internalPort int, dnsttEnabled bool, dnsttUDP string) []string {
	var conflicts []string

	// 1. Portas TCP do Proxy
	for _, p := range ports {
		clean := strings.TrimSpace(p)
		if clean == "" {
			continue
		}
		if idx := strings.Index(clean, ":"); idx >= 0 {
			clean = clean[:idx]
		}
		var portNum int
		if _, err := fmt.Sscanf(clean, "%d", &portNum); err == nil && portNum > 0 {
			inUse, procInfo := IsPortInUseByOther("tcp", portNum)
			if inUse {
				conflicts = append(conflicts, fmt.Sprintf("Porta TCP %d (%s) em uso por '%s'", portNum, p, procInfo))
			}
		}
	}

	// 2. Porta TCP do SSH Interno
	if internalPort > 0 {
		inUse, procInfo := IsPortInUseByOther("tcp", internalPort)
		if inUse {
			conflicts = append(conflicts, fmt.Sprintf("Porta TCP SSH Interno %d em uso por '%s'", internalPort, procInfo))
		}
	}

	// 3. Porta UDP do DNSTT (se ativado)
	if dnsttEnabled && strings.TrimSpace(dnsttUDP) != "" {
		udpPort := 53
		udpClean := strings.TrimSpace(dnsttUDP)
		if idx := strings.LastIndex(udpClean, ":"); idx >= 0 {
			_, _ = fmt.Sscanf(udpClean[idx+1:], "%d", &udpPort)
		} else {
			_, _ = fmt.Sscanf(udpClean, "%d", &udpPort)
		}
		if udpPort > 0 {
			inUse, procInfo := IsPortInUseByOther("udp", udpPort)
			if inUse {
				conflicts = append(conflicts, fmt.Sprintf("Porta UDP %d (DNSTT) em uso por '%s'", udpPort, procInfo))
			}
		}
	}

	return conflicts
}

// ReleasePort53FromSystemdResolved libera a porta 53 UDP no Ubuntu/Debian desativando
// o DNSStubListener do systemd-resolved, ajustando /etc/resolv.conf e abrindo o firewall.
func ReleasePort53FromSystemdResolved() error {
	if runtime.GOOS == "windows" {
		return fmt.Errorf("a liberação do systemd-resolved só é aplicável em sistemas Linux")
	}

	resolvedConfPath := "/etc/systemd/resolved.conf"
	data, err := os.ReadFile(resolvedConfPath)
	if err == nil {
		content := string(data)
		if strings.Contains(content, "#DNSStubListener=yes") {
			content = strings.ReplaceAll(content, "#DNSStubListener=yes", "DNSStubListener=no")
		} else if strings.Contains(content, "DNSStubListener=yes") {
			content = strings.ReplaceAll(content, "DNSStubListener=yes", "DNSStubListener=no")
		} else if !strings.Contains(content, "DNSStubListener=no") {
			if strings.Contains(content, "[Resolve]") {
				content = strings.Replace(content, "[Resolve]", "[Resolve]\nDNSStubListener=no", 1)
			} else {
				content += "\n[Resolve]\nDNSStubListener=no\n"
			}
		}
		_ = os.WriteFile(resolvedConfPath, []byte(content), 0644)
	}

	// 2. Reinicia o resolvedor
	_ = exec.Command("systemctl", "restart", "systemd-resolved").Run()

	// 3. Aponta o resolv.conf real do systemd para o resolv.conf do sistema
	if _, err := os.Stat("/run/systemd/resolve/resolv.conf"); err == nil {
		_ = exec.Command("ln", "-sf", "/run/systemd/resolve/resolv.conf", "/etc/resolv.conf").Run()
	}

	// 4. Libera a porta 53 UDP no firewall (UFW e iptables)
	if _, err := exec.LookPath("ufw"); err == nil {
		_ = exec.Command("ufw", "allow", "53/udp").Run()
	}
	_ = exec.Command("iptables", "-I", "INPUT", "-p", "udp", "--dport", "53", "-j", "ACCEPT").Run()

	// Aguarda liberação do socket
	time.Sleep(300 * time.Millisecond)

	// Valida se a porta 53 UDP foi realmente liberada do resolvedor (ignora se for o próprio proxy-server)
	inUse, procInfo := IsPortInUseByOther("udp", 53)
	if inUse {
		return fmt.Errorf("a porta 53 ainda está em uso por '%s'. Verifique outros serviços de DNS locais como dnsmasq ou named", procInfo)
	}

	return nil
}

// SleepShort espera brevemente para liberação de portas em testes ou restarts
func SleepShort(ms int) {
	time.Sleep(time.Duration(ms) * time.Millisecond)
}


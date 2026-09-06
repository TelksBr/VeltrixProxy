package system

import (
	"fmt"
	"net"
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

	cmdSS := exec.Command("ss", ssFlag, fmt.Sprintf("sport = :%d", port))
	if out, err := cmdSS.Output(); err == nil && len(out) > 0 {
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
			return fmt.Sprintf("PID %s", pids[0])
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

// EnsurePortNotBusy testa a porta e retorna erro descritivo caso esteja ocupada
func EnsurePortNotBusy(proto string, port int) error {
	var available bool
	var procInfo string

	if strings.ToLower(proto) == "udp" {
		available, procInfo = CheckUDPPortAvailable(port)
	} else {
		available, procInfo = CheckTCPPortAvailable(port)
	}

	if !available {
		return fmt.Errorf("porta %s/%d já está em uso por %s", strings.ToUpper(proto), port, procInfo)
	}
	return nil
}

// SleepShort espera brevemente para liberação de portas em testes ou restarts
func SleepShort(ms int) {
	time.Sleep(time.Duration(ms) * time.Millisecond)
}

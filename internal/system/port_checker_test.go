package system

import (
	"fmt"
	"net"
	"testing"
)

func TestPortCheckerTCP(t *testing.T) {
	// Cria listener efêmero em todas as interfaces
	ln, err := net.Listen("tcp", ":0")
	if err != nil {
		t.Fatalf("falha ao criar listener de teste: %v", err)
	}
	defer ln.Close()

	port := ln.Addr().(*net.TCPAddr).Port

	// Com listener aberto, a porta não deve estar disponível para bind
	avail, info := CheckTCPPortAvailable(port)
	if avail {
		t.Fatalf("esperado avail=false para porta %d com listener ativo", port)
	}
	if info == "" {
		t.Fatalf("esperado detalhes do processo ou motivo da ocupação")
	}

	// Fecha listener
	_ = ln.Close()

	// Agora deve estar disponível
	availAfter, _ := CheckTCPPortAvailable(port)
	if !availAfter {
		t.Logf("aviso: porta %d pode estar em TIME_WAIT, mas teste de bind passou", port)
	}
}

func TestPortCheckerUDP(t *testing.T) {
	pc, err := net.ListenPacket("udp", ":0")
	if err != nil {
		t.Fatalf("falha ao criar socket udp de teste: %v", err)
	}
	defer pc.Close()

	port := pc.LocalAddr().(*net.UDPAddr).Port

	avail, info := CheckUDPPortAvailable(port)
	if avail {
		t.Fatalf("esperado avail=false para porta udp %d com socket ativo", port)
	}
	if info == "" {
		t.Fatalf("esperado detalhes para porta ocupada")
	}

	_ = pc.Close()

	availAfter, _ := CheckUDPPortAvailable(port)
	if !availAfter {
		t.Logf("aviso: porta udp %d ainda ocupada", port)
	}
}

func TestPortCheckerInvalid(t *testing.T) {
	avail, _ := CheckTCPPortAvailable(0)
	if avail {
		t.Fatalf("esperado avail=false para porta 0")
	}
	avail, _ = CheckTCPPortAvailable(70000)
	if avail {
		t.Fatalf("esperado avail=false para porta 70000")
	}

	avail, _ = CheckUDPPortAvailable(0)
	if avail {
		t.Fatalf("esperado avail=false para porta 0")
	}
	avail, _ = CheckUDPPortAvailable(70000)
	if avail {
		t.Fatalf("esperado avail=false para porta 70000")
	}
}

func TestRegexSS(t *testing.T) {
	line := `users:(("systemd-resolve",pid=514,fd=13))`
	matches := ssUserRegex.FindStringSubmatch(line)
	if len(matches) < 3 {
		t.Fatalf("esperado capturar processo e pid, obtido: %v", matches)
	}
	if matches[1] != "systemd-resolve" || matches[2] != "514" {
		t.Fatalf("captura incorreta: %s, %s", matches[1], matches[2])
	}
}

func TestCheckConfiguredPortsConflict(t *testing.T) {
	// Listener TCP ativo
	ln, err := net.Listen("tcp", ":0")
	if err != nil {
		t.Fatalf("falha ao criar listener: %v", err)
	}
	defer ln.Close()

	port := ln.Addr().(*net.TCPAddr).Port
	ports := []string{fmt.Sprintf("%d:ssl", port)}

	conflicts := CheckConfiguredPortsConflict(ports, 0, false, "")
	if len(conflicts) != 1 {
		t.Fatalf("esperado 1 conflito para porta %d, obtido %d (%v)", port, len(conflicts), conflicts)
	}

	// Porta interna conflitando
	conflictsInternal := CheckConfiguredPortsConflict([]string{}, port, false, "")
	if len(conflictsInternal) != 1 {
		t.Fatalf("esperado 1 conflito para internalPort %d", port)
	}

	_ = ln.Close()
}

func TestIsOwnServiceProcess(t *testing.T) {
	cases := []struct {
		proc     string
		expected bool
	}{
		{"proxy-server (PID: 72898)", true},
		{"vtproxy (PID: 1234)", true},
		{"udpgw (PID: 4321)", true},
		{"/usr/local/bin/proxy-server (PID: 555)", true},
		{"nginx (PID: 8080)", false},
		{"systemd-resolve (PID: 514)", false},
		{"named (PID: 111)", false},
		{"dnsmasq (PID: 222)", false},
		{"unknown", false},
	}
	for _, c := range cases {
		got := IsOwnServiceProcess(c.proc)
		if got != c.expected {
			t.Errorf("IsOwnServiceProcess(%q) = %v; want %v", c.proc, got, c.expected)
		}
	}
}

func TestIsOwnProxyProcess(t *testing.T) {
	if !IsOwnProxyProcess("proxy-server (PID: 72898)") {
		t.Errorf("esperado true para proxy-server")
	}
	if !IsOwnProxyProcess("vtproxy (PID: 123)") {
		t.Errorf("esperado true para vtproxy")
	}
	if IsOwnProxyProcess("nginx (PID: 123)") {
		t.Errorf("esperado false para nginx")
	}
}


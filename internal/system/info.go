package system

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

var (
	cachedIP     string
	cachedIPTime time.Time
	ipMu         sync.Mutex
)

// RAMInfo armazena dados de memória RAM em megabytes
type RAMInfo struct {
	TotalMB int
	UsedMB  int
	FreeMB  int
	Percent int
}

// GetCPUUsage calcula a porcentagem de uso de CPU no Linux
func GetCPUUsage() int {
	if runtime.GOOS != "linux" {
		return 5 // Simulação em ambientes de desenvolvimento não-Linux
	}

	readStat := func() (idle, total uint64, err error) {
		f, err := os.Open("/proc/stat")
		if err != nil {
			return 0, 0, err
		}
		defer f.Close()

		scanner := bufio.NewScanner(f)
		if scanner.Scan() {
			fields := strings.Fields(scanner.Text())
			if len(fields) >= 5 && fields[0] == "cpu" {
				var sum uint64
				for i := 1; i < len(fields); i++ {
					val, _ := strconv.ParseUint(fields[i], 10, 64)
					sum += val
					if i == 4 { // idle
						idle = val
					}
				}
				total = sum
				return idle, total, nil
			}
		}
		return 0, 0, fmt.Errorf("formato inválido")
	}

	idle1, total1, err := readStat()
	if err != nil {
		return 0
	}

	time.Sleep(150 * time.Millisecond)

	idle2, total2, err := readStat()
	if err != nil {
		return 0
	}

	deltaTotal := total2 - total1
	deltaIdle := idle2 - idle1
	if deltaTotal == 0 {
		return 0
	}

	usage := int(100 * (deltaTotal - deltaIdle) / deltaTotal)
	if usage < 0 {
		usage = 0
	}
	if usage > 100 {
		usage = 100
	}
	return usage
}

// GetRAMInfo obtém dados de memória RAM do /proc/meminfo
func GetRAMInfo() RAMInfo {
	if runtime.GOOS != "linux" {
		return RAMInfo{TotalMB: 4096, UsedMB: 1024, FreeMB: 3072, Percent: 25}
	}

	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return RAMInfo{}
	}
	defer f.Close()

	var totalKB, freeKB, buffersKB, cachedKB int
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Split(line, ":")
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		valFields := strings.Fields(parts[1])
		if len(valFields) == 0 {
			continue
		}
		val, _ := strconv.Atoi(valFields[0])

		switch key {
		case "MemTotal":
			totalKB = val
		case "MemFree":
			freeKB = val
		case "Buffers":
			buffersKB = val
		case "Cached":
			cachedKB = val
		}
	}

	totalMB := totalKB / 1024
	usedMB := (totalKB - freeKB - buffersKB - cachedKB) / 1024
	if usedMB < 0 {
		usedMB = 0
	}
	percent := 0
	if totalMB > 0 {
		percent = (usedMB * 100) / totalMB
	}

	return RAMInfo{
		TotalMB: totalMB,
		UsedMB:  usedMB,
		FreeMB:  totalMB - usedMB,
		Percent: percent,
	}
}

// GetPublicIP obtém o IP público da VPS com cache de 5 minutos
func GetPublicIP() string {
	ipMu.Lock()
	defer ipMu.Unlock()

	if cachedIP != "" && time.Since(cachedIPTime) < 5*time.Minute {
		return cachedIP
	}

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("https://api.ipify.org")
	if err != nil {
		if cachedIP != "" {
			return cachedIP
		}
		return "127.0.0.1"
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil || len(data) == 0 {
		return "127.0.0.1"
	}

	cachedIP = strings.TrimSpace(string(data))
	cachedIPTime = time.Now()
	return cachedIP
}

// GetOSName retorna o nome amigável da distribuição Linux
func GetOSName() string {
	if runtime.GOOS != "linux" {
		return runtime.GOOS
	}

	f, err := os.Open("/etc/os-release")
	if err != nil {
		return "Linux"
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			val := strings.TrimPrefix(line, "PRETTY_NAME=")
			return strings.Trim(val, "\"")
		}
	}
	return "Linux"
}

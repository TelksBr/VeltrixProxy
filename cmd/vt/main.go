package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/TelksBr/VeltrixProxy/internal/config"
	"github.com/TelksBr/VeltrixProxy/internal/system"
	"github.com/TelksBr/VeltrixProxy/internal/ui/menus"
	"github.com/TelksBr/VeltrixProxy/internal/ui/theme"
)

var Version = system.CurrentMenuVersion

func main() {
	configFlag := flag.String("config", "", "Caminho do arquivo config.json (padrão: /etc/proxyvt/config.json)")
	versionFlag := flag.Bool("version", false, "Exibe a versão do utilitário")
	flag.BoolVar(versionFlag, "v", false, "Exibe a versão do utilitário (abreviação)")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("%sVT CLI Manager%s v%s (Go nativo)\n", theme.Cyan, theme.Reset, Version)
		fmt.Printf("%sDev: %s@telks13 %s│ Telegram: %s@VeltrixPanelGroup%s\n", theme.DarkGray, theme.Cyan, theme.DarkGray, theme.Cyan, theme.Reset)
		os.Exit(0)
	}

	cfgMgr := config.NewManager(*configFlag)
	// Força a verificação de atualizações sempre que o menu for iniciado
	system.CheckUpdates(true)
	menus.ShowMainMenu(cfgMgr)
}

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
	migrateFlag := flag.Bool("migrate", false, "Carrega, migra e normaliza o config.json e encerra")
	versionFlag := flag.Bool("version", false, "Exibe a versão do utilitário")
	flag.BoolVar(versionFlag, "v", false, "Exibe a versão do utilitário (abreviação)")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("%sVT CLI Manager%s v%s (Go nativo)\n", theme.Cyan, theme.Reset, Version)
		fmt.Printf("%sDev: %s@telks13 %s│ Telegram: %s@VeltrixPanelGroup%s\n", theme.DarkGray, theme.Cyan, theme.DarkGray, theme.Cyan, theme.Reset)
		os.Exit(0)
	}

	cfgMgr := config.NewManager(*configFlag)
	if *migrateFlag {
		cfg, err := cfgMgr.Load()
		if err != nil {
			fmt.Fprintf(os.Stderr, "vt migrate: %v\n", err)
			os.Exit(1)
		}
		if err := cfgMgr.Save(cfg); err != nil {
			fmt.Fprintf(os.Stderr, "vt migrate save: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}
	// Força a verificação de atualizações sempre que o menu for iniciado
	system.CheckUpdates(true)
	menus.ShowMainMenu(cfgMgr)
}

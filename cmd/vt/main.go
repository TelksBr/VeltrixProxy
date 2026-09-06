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

const Version = system.CurrentMenuVersion

func main() {
	configFlag := flag.String("config", "", "Caminho do arquivo config.json (padrão: /etc/proxyvt/config.json)")
	versionFlag := flag.Bool("version", false, "Exibe a versão do utilitário")
	flag.BoolVar(versionFlag, "v", false, "Exibe a versão do utilitário (abreviação)")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("%sVT CLI Manager%s v%s (Go nativo)\n", theme.Cyan, theme.Reset, Version)
		os.Exit(0)
	}

	cfgMgr := config.NewManager(*configFlag)
	system.CheckInBackground()
	menus.ShowMainMenu(cfgMgr)
}

package i18n

var dictPT = map[string]string{
	// Menu Principal
	"app_title":                  "GERENCIADOR VELTRIX PROXY",
	"menu_opt_proxy":             "Menu Proxy (Portas & JSON)",
	"menu_opt_udpgw":             "Menu BadVPN / UDPGW",
	"menu_opt_tokens":            "Gerenciar Tokens de Licença",
	"menu_opt_optimization":      "Otimização de Rede & Kernel",
	"menu_opt_connected_users":   "Usuários Conectados (Online)",
	"menu_opt_update":            "Atualizar Sistema & Binários",
	"menu_opt_change_language":   "Mudar Idioma (Change Language)",
	"menu_opt_exit":              "Sair do Menu",

	// Menu Proxy
	"proxy_menu_title":           "GERENCIADOR DO PROXY VT",
	"proxy_opt_start_specific":   "Abrir / Ativar porta específica",
	"proxy_opt_start_all":        "Ativar todas as portas configuradas",
	"proxy_opt_pause":            "Pausar serviço do proxy",
	"proxy_opt_edit":             "Gerenciar portas (Ativar / Desativar)",
	"proxy_opt_remove":           "Remover porta do proxy",
	"proxy_opt_restart":          "Reiniciar serviço do proxy",
	"proxy_opt_adv":              "Opções avançadas (config.json)",
	"proxy_opt_http":             "Alterar resposta HTTP global",
	"proxy_opt_details":          "Detalhes e status das portas",
	"proxy_opt_logs":             "Visualizar logs do serviço",
	"proxy_opt_back":             "Voltar ao menu principal",

	// Menu Avançado
	"adv_menu_title":             "OPÇÕES AVANÇADAS DO PROXY (JSON)",
	"adv_opt_perf":               "Desempenho & Timeouts (Buffer, Conexões, Ulimit)",
	"adv_opt_http_logs":          "Resposta HTTP, Banner & Logs",
	"adv_opt_ssl":                "Certificados TLS / SSL (Interno / Externo)",
	"adv_opt_ssh":                "Servidor SSH Nativo Embutido (Zero-Fork)",
	"adv_opt_btun":               "Servidor BTUN / UDP DT-Proto",
	"adv_opt_limits":             "Limites de Conexão e Expiração (Limiter)",
	"adv_opt_connectors":         "Conectores Backends (OpenVPN, V2Ray) & XHTTP",
	"adv_opt_view_json":          "Visualizar arquivo config.json",
	"adv_opt_finish":             "Concluir / Voltar",

	// Limiter
	"limits_menu_title":          "LIMITES DE CONEXÕES & EXPIRAÇÃO (LIMITER)",
	"limits_opt_enable":          "Habilitar Limiter (limits.enable)",
	"limits_opt_default_limit":   "Limite Padrão por Conta (0=ilimitado)",
	"limits_opt_expire_check":    "Varredura Automática de Expirados",
	"limits_opt_passwd_file":     "Arquivo de Limites / Senhas (/etc/passwd)",

	// Status & Indicadores
	"status_online":              "ONLINE",
	"status_offline":             "OFFLINE",
	"status_active":              "ATIVO",
	"status_inactive":            "INATIVO",
	"service_running":            "Em execução",
	"service_stopped":            "Parado",

	// Prompts e mensagens
	"prompt_select_option":       "Selecione uma opção",
	"prompt_press_enter":         "Pressione [Enter] para continuar...",
	"invalid_option":             "Opção inválida!",
	"operation_success":          "Operação realizada com sucesso.",
	"operation_failed":           "Falha ao executar operação.",
	"confirm_action":             "Deseja confirmar esta ação? (s/n)",
	"back":                       "Voltar",

	// Atualizações
	"update_title":               "ATUALIZAÇÃO DO SISTEMA & BINÁRIOS",
	"update_badge_available":     "NOVO UPDATE!",
	"update_badge_current":       "ATUALIZADO",
	"update_opt_apply":           "Atualizar agora (Binários e Menu)",
	"update_opt_check_again":     "Forçar verificação no GitHub",
	"update_preserve_notice":     "Configurações e portas serão 100% preservadas.",
	"update_running":             "Baixando e aplicando atualização oficial...",
	"update_success":             "Atualização concluída com sucesso!",
	"update_canceled":            "Atualização cancelada.",
}

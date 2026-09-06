package i18n

var dictES = map[string]string{
	// Menu Principal
	"app_title":                  "ADMINISTRADOR VELTRIX PROXY",
	"menu_opt_proxy":             "Menú Proxy (Puertos & JSON)",
	"menu_opt_udpgw":             "Menú BadVPN / UDPGW",
	"menu_opt_tokens":            "Gestionar Tokens de Licencia",
	"menu_opt_optimization":      "Optimización de Red & Kernel",
	"menu_opt_connected_users":   "Usuarios Conectados (Online)",
	"menu_opt_update":            "Actualizar Sistema & Binarios",
	"menu_opt_change_language":   "Cambiar Idioma",
	"menu_opt_exit":              "Salir del Menú",

	// Menu Proxy
	"proxy_menu_title":           "ADMINISTRADOR DEL PROXY VT",
	"proxy_opt_add":              "Agregar puerto al proxy",
	"proxy_opt_remove":           "Eliminar puerto del proxy",
	"proxy_opt_start":            "Iniciar servicio del proxy (Encender)",
	"proxy_opt_stop":             "Detener servicio del proxy (Apagar)",
	"proxy_opt_restart":          "Reiniciar servicio del proxy",
	"proxy_opt_adv":              "Opciones avanzadas (config.json)",
	"proxy_opt_http":             "Cambiar respuesta HTTP global",
	"proxy_opt_details":          "Detalles y estado de los puertos",
	"proxy_opt_logs":             "Ver registros (logs) del servicio",
	"proxy_opt_back":             "Volver al menú principal",

	// Submenus
	"udpgw_menu_title":           "ADMINISTRADOR BADVPN / UDPGW",
	"tokens_menu_title":          "GESTIONAR TOKENS DE LICENCIA",
	"optimize_menu_title":        "OPTIMIZACIONES DE RED & KERNEL",
	"onlines_menu_title":         "USUARIOS CONECTADOS (ONLINE)",

	// Menu Avanzado
	"adv_menu_title":             "OPCIONES AVANZADAS DEL PROXY (JSON)",
	"adv_opt_perf":               "Rendimiento & Timeouts (Buffer, Conexiones, Ulimit)",
	"adv_opt_http_logs":          "Respuesta HTTP, Banner & Logs",
	"adv_opt_ssl":                "Certificados TLS / SSL (Interno / Externo)",
	"adv_opt_ssh":                "Servidor SSH Nativo Embebido (Zero-Fork)",
	"adv_opt_btun":               "Servidor BTUN / UDP DT-Proto",
	"adv_opt_limits":             "Límites de Conexión y Expiración (Limiter)",
	"adv_opt_connectors":         "Conectores Backends (OpenVPN, V2Ray) & XHTTP",
	"adv_opt_view_json":          "Ver archivo config.json",
	"adv_opt_finish":             "Finalizar / Volver",

	// Limiter
	"limits_menu_title":          "LÍMITES DE CONEXIÓN & EXPIRACIÓN (LIMITER)",
	"limits_opt_enable":          "Habilitar Limiter (limits.enable)",
	"limits_opt_default_limit":   "Límite Predeterminado por Cuenta (0=ilimitado)",
	"limits_opt_expire_check":    "Verificación Automática de Expirados",
	"limits_opt_passwd_file":     "Archivo de Límites / Contraseñas (/etc/passwd)",

	// Status
	"status_online":              "ONLINE",
	"status_offline":             "OFFLINE",
	"status_active":              "ACTIVO",
	"status_inactive":            "INACTIVO",
	"service_running":            "En ejecución",
	"service_stopped":            "Detenido",

	// Prompts
	"prompt_select_option":       "Seleccione una opción",
	"prompt_press_enter":         "Presione [Enter] para continuar...",
	"invalid_option":             "¡Opción inválida!",
	"operation_success":          "Operación completada con éxito.",
	"operation_failed":           "Error al ejecutar la operación.",
	"confirm_action":             "¿Desea confirmar esta acción? (s/n)",
	"back":                       "Volver",

	// Actualizaciones
	"update_title":               "ACTUALIZACIÓN DEL SISTEMA & BINARIOS",
	"update_badge_available":     "¡NUEVO UPDATE!",
	"update_badge_current":       "ACTUALIZADO",
	"update_opt_apply":           "Actualizar ahora (Binarios y Menú)",
	"update_opt_check_again":     "Forzar comprobación en GitHub",
	"update_preserve_notice":     "Las configuraciones y puertos se preservarán al 100%.",
	"update_running":             "Descargando y aplicando actualización oficial...",
	"update_success":             "¡Actualización completada con éxito!",
	"update_canceled":            "Actualización cancelada.",
}

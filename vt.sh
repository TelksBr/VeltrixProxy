#!/bin/bash

readonly PROJECT_NAME="VTProxy"
readonly MENU_BOX_MIN=34
readonly MENU_BOX_MAX=56
readonly MENU_REV="57"
readonly DEFAULT_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
readonly PROXY_REPO="TelksBr/VeltrixProxy"
readonly UDPGW_REPO="TelksBr/VeltrixUPGW"
readonly INSTALL_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh"
readonly LICENSE_API_URL="${LICENSE_API_URL:-https://proxyvt.sshtproject.com}"
readonly MENU_BIN="/usr/local/bin/vt"
readonly PROXY_VERSION_FILE="/etc/proxy-version"
readonly UDPGW_VERSION_FILE="/etc/udpgw-version"
readonly UPDATE_CACHE_FILE="/tmp/.vt_update_check.cache"
readonly UPDATE_CACHE_TTL=300
readonly QUICK_SETUP_MARKER="/etc/vtproxy/.quick-setup-done"
readonly QUICK_SETUP_ASKED_MARKER="/etc/vtproxy/.quick-setup-asked"

# Largura interna da caixa (sem as bordas ║). Recalculada por refresh_menu_layout.
MENU_BOX_WIDTH=$MENU_BOX_MAX

UDPGW_BIN="/usr/local/bin/udpgw"
UDPGW_CONFIG_DIR="/etc/udpgw/conf.d"
UDPGW_CONFIG_FILE="/etc/udpgw/config.conf"
UDPGW_SERVICE_PREFIX="udpgw"
UDPGW_SERVICE_NAME="udpgw"
UDPGW_DEFAULT_PORT=7400
UDPGW_DEFAULT_LISTEN="0.0.0.0:7400"
UDPGW_METRICS_BASE=9091

PROXY_DIR="/etc/proxy"
PROXY_TOKEN_VTPROXY="/etc/vtproxy/proxy.token"
PROXY_TOKEN_FILE="$PROXY_DIR/token"
PROXY_TOKEN_HOME="${HOME:-/root}/.proxy_token"
PROXY_CONFIG_DIR="$PROXY_DIR/conf.d"
PROXY_LOG_DIR="/var/log/proxy"
PROXY_SERVICE_PREFIX="proxy"
readonly PROXY_UNIFIED_SERVICE_NAME="vtproxy"
readonly PROXY_JSON_DIR="/etc/proxyvt"
readonly PROXY_JSON_FILE="/etc/proxyvt/config.json"
readonly PROXY_CONFIG_JSON="/etc/proxyvt/config.json"

resolve_proxy_executable() {
    if [[ -x "/usr/local/bin/proxy-server" ]]; then
        echo "/usr/local/bin/proxy-server"
    elif [[ -x "/usr/local/bin/proxy" ]]; then
        echo "/usr/local/bin/proxy"
    else
        echo "/usr/local/bin/proxy-server"
    fi
}

PROXY_EXECUTABLE="$(resolve_proxy_executable)"

DEFAULT_BUFFER_SIZE=32768
DEFAULT_HTTP_RESPONSE="$PROJECT_NAME"
DEFAULT_WRITE_TIMEOUT=60
DEFAULT_IDLE_TIMEOUT=60
DEFAULT_MAX_CONNECTIONS=0
DEFAULT_LOG_LEVEL="info"
DEFAULT_SSH_PORT=22
DEFAULT_OPENVPN_PORT=1194
DEFAULT_V2RAY_PORT=1080
MIN_PORT=1
MAX_PORT=65535

RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'
PURPLE=$'\033[1;35m'
CYAN=$'\033[1;36m'
WHITE=$'\033[1;37m'
GRAY=$'\033[1;90m'
BG_BLUE=$'\033[44m'
BG_GREEN=$'\033[42m'
BG_RED=$'\033[41m'
BG_GRAY=$'\033[100m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

LANG_FILE="/etc/vtproxy/lang"
LANG_ACTIVE="pt"

declare -A I18N_PT
declare -A I18N_EN
declare -A I18N_ES

# --- Português (PT) ---
I18N_PT[header_sub_narrow]="Proxy + UDP Gateway"
I18N_PT[header_sub_wide]="Proxy + UDP Gateway integrados"
I18N_PT[status_proxy]="Proxy:"
I18N_PT[status_token]="Token:"
I18N_PT[status_token_proxy]="Token proxy:"
I18N_PT[status_none]="nenhuma"
I18N_PT[status_ip]="IP:"
I18N_PT[status_ssh_onlines]="SSH Online:"
I18N_PT[status_udpgw]="UDP Gateway:"
I18N_PT[status_ports]="Portas:"
I18N_PT[status_cpu]="CPU:"
I18N_PT[status_ram]="RAM:"

I18N_PT[menu_main_title]="MENU INICIAL"
I18N_PT[menu_proxy]="Proxy / Portas"
I18N_PT[menu_online_users]="Usuários Online (SSH:%s)"
I18N_PT[menu_tokens]="Gerenciar Tokens"
I18N_PT[menu_update]="Atualizar Sistema"
I18N_PT[menu_udpgw]="UDP Gateway (udpgw)"
I18N_PT[menu_lang]="Idioma / Language"
I18N_PT[menu_uninstall]="Remover Instalação"
I18N_PT[menu_exit]="Sair"
I18N_PT[prompt_select_option]="Selecione uma opção [%s]:"
I18N_PT[invalid_option]="Opção inválida: %s"
I18N_PT[press_enter]="Pressione Enter para continuar..."
I18N_PT[exiting]="Saindo..."
I18N_PT[root_required]="Este script requer privilégios de root."
I18N_PT[run_with_sudo]="Execute com: sudo %s"

I18N_PT[lang_menu_title]="SELECIONAR IDIOMA"
I18N_PT[lang_current]="Idioma atual:"
I18N_PT[lang_opt_pt]="Português (PT)"
I18N_PT[lang_opt_en]="English (EN)"
I18N_PT[lang_opt_es]="Español (ES)"
I18N_PT[lang_back]="Voltar"
I18N_PT[lang_saved]="Idioma alterado para %s!"

I18N_PT[proxy_menu_title]="%s — PROXY"
I18N_PT[proxy_menu_ports]="Portas: %s"
I18N_PT[proxy_opt_open]="Abrir / criar nova porta"
I18N_PT[proxy_opt_start]="Ativar porta configurada"
I18N_PT[proxy_opt_stop]="Pausar porta (mantém config)"
I18N_PT[proxy_opt_edit]="Editar porta (SSL)"
I18N_PT[proxy_opt_remove]="Remover porta"
I18N_PT[proxy_opt_restart]="Reiniciar serviço proxy"
I18N_PT[proxy_opt_adv]="Opções avançadas (config.json)"
I18N_PT[proxy_opt_http]="Alterar resposta HTTP"
I18N_PT[proxy_opt_details]="Detalhes do serviço proxy"
I18N_PT[proxy_opt_logs]="Ver logs do VTProxy"
I18N_PT[proxy_opt_back]="Voltar ao Menu Inicial"

I18N_PT[udpgw_menu_title]="UDP GATEWAY (udpgw)"
I18N_PT[udpgw_menu_ports]="Portas: %s"
I18N_PT[udpgw_opt_open]="Abrir / criar porta"
I18N_PT[udpgw_opt_start]="Iniciar porta"
I18N_PT[udpgw_opt_stop]="Parar porta"
I18N_PT[udpgw_opt_restart]="Reiniciar porta"
I18N_PT[udpgw_opt_status]="Status & ExecStart"
I18N_PT[udpgw_opt_metrics]="Painel de metricas"
I18N_PT[udpgw_opt_logs]="Visualizar logs"
I18N_PT[udpgw_opt_adv]="Opcoes avancadas (flags)"
I18N_PT[udpgw_opt_install]="Instalar/atualizar binario"
I18N_PT[udpgw_opt_remove]="Remover porta"
I18N_PT[udpgw_opt_back]="Voltar ao Menu Inicial"

I18N_PT[token_menu_title]="GERENCIAR TOKENS"
I18N_PT[token_menu_proxy_lic]="Proxy (licença):"
I18N_PT[token_opt_config]="Configurar token Proxy"
I18N_PT[token_opt_back]="Voltar"
I18N_PT[token_prompt_input]="Insira o token proxy (licença %s):"
I18N_PT[token_empty_error]="Token não pode ser vazio."
I18N_PT[token_saved_success]="Token proxy salvo!"
I18N_PT[token_syncing]="Sincronizando token nos serviços proxy..."
I18N_PT[token_applied_ports]="Token aplicado em %s porta(s) proxy."
I18N_PT[token_invalid_retry]="Token proxy inválido. Tente novamente."

I18N_PT[ssh_menu_title]="USUARIOS ONLINE SSH (%s)"
I18N_PT[ssh_opt_list]="Listar usuarios SSH online"
I18N_PT[ssh_opt_back]="Voltar"
I18N_PT[ssh_no_users]="Nenhum usuario SSH online (excluindo root)."
I18N_PT[ssh_user_row]="Usuario: %s | PID: %s | Tempo: %s"

I18N_PT[update_menu_title]="ATUALIZAR SISTEMA"
I18N_PT[update_installed_proxy]="Proxy instalado: %s"
I18N_PT[update_installed_udpgw]="UDPgw instalado: %s"
I18N_PT[update_confirm_prompt]="Atualizar binários (proxy/udpgw) e o menu vt agora?"
I18N_PT[update_canceled]="Atualização cancelada."
I18N_PT[update_downloading]="Baixando e executando instalador oficial..."
I18N_PT[update_failed]="Falha na atualização."
I18N_PT[update_success]="Atualização concluída (binários + menu)."
I18N_PT[update_reloading]="Recarregando o novo menu vt..."
I18N_PT[update_notice_title]="ATUALIZAÇÃO DISPONÍVEL!"
I18N_PT[update_notice_prompt]="Selecione a Opção [4] para atualizar o sistema."
I18N_PT[update_badge_available]="NOVO UPDATE!"
I18N_PT[update_badge_current]="ATUALIZADO"
I18N_PT[update_component_proxy]="Proxy Server:"
I18N_PT[update_component_udpgw]="UDP Gateway:"
I18N_PT[update_component_menu]="Menu Core:"

I18N_PT[remove_title]="REMOÇÃO COMPLETA"
I18N_PT[remove_warning_banner]="Esta ação irá remover TODOS os dados e serviços"
I18N_PT[remove_confirm_sure]="TEM CERTEZA que deseja remover completamente?"
I18N_PT[remove_canceled]="Remoção cancelada."
I18N_PT[remove_success]="Remoção completa concluída!"
I18N_PT[remove_clean]="O sistema está limpo."

# --- English (EN) ---
I18N_EN[header_sub_narrow]="Proxy + UDP Gateway"
I18N_EN[header_sub_wide]="Integrated Proxy + UDP Gateway"
I18N_EN[status_proxy]="Proxy:"
I18N_EN[status_token]="Token:"
I18N_EN[status_token_proxy]="Proxy token:"
I18N_EN[status_none]="none"
I18N_EN[status_ip]="IP:"
I18N_EN[status_ssh_onlines]="SSH Online:"
I18N_EN[status_udpgw]="UDP Gateway:"
I18N_EN[status_ports]="Ports:"
I18N_EN[status_cpu]="CPU:"
I18N_EN[status_ram]="RAM:"

I18N_EN[menu_main_title]="MAIN MENU"
I18N_EN[menu_proxy]="Proxy / Ports"
I18N_EN[menu_online_users]="Online Users (SSH:%s)"
I18N_EN[menu_tokens]="Manage Tokens"
I18N_EN[menu_update]="Update System"
I18N_EN[menu_udpgw]="UDP Gateway (udpgw)"
I18N_EN[menu_lang]="Language"
I18N_EN[menu_uninstall]="Uninstall"
I18N_EN[menu_exit]="Exit"
I18N_EN[prompt_select_option]="Select an option [%s]:"
I18N_EN[invalid_option]="Invalid option: %s"
I18N_EN[press_enter]="Press Enter to continue..."
I18N_EN[exiting]="Exiting..."
I18N_EN[root_required]="This script requires root privileges."
I18N_EN[run_with_sudo]="Run with: sudo %s"

I18N_EN[lang_menu_title]="SELECT LANGUAGE"
I18N_EN[lang_current]="Current language:"
I18N_EN[lang_opt_pt]="Português (PT)"
I18N_EN[lang_opt_en]="English (EN)"
I18N_EN[lang_opt_es]="Español (ES)"
I18N_EN[lang_back]="Back"
I18N_EN[proxy_menu_title]="%s — PROXY"
I18N_EN[proxy_menu_ports]="Ports: %s"
I18N_EN[proxy_opt_open]="Open / create port"
I18N_EN[proxy_opt_start]="Activate configured port"
I18N_EN[proxy_opt_stop]="Pause port (keep config)"
I18N_EN[proxy_opt_edit]="Edit port (SSL)"
I18N_EN[proxy_opt_remove]="Remove port"
I18N_EN[proxy_opt_restart]="Restart proxy service"
I18N_EN[proxy_opt_adv]="Advanced options (config.json)"
I18N_EN[proxy_opt_http]="Change HTTP response"
I18N_EN[proxy_opt_details]="Proxy service details"
I18N_EN[proxy_opt_logs]="View VTProxy logs"
I18N_EN[proxy_opt_back]="Back to Main Menu"

I18N_EN[udpgw_menu_title]="UDP GATEWAY (udpgw)"
I18N_EN[udpgw_menu_ports]="Ports: %s"
I18N_EN[udpgw_opt_open]="Open / create port"
I18N_EN[udpgw_opt_start]="Start port"
I18N_EN[udpgw_opt_stop]="Stop port"
I18N_EN[udpgw_opt_restart]="Restart port"
I18N_EN[udpgw_opt_status]="Status & ExecStart"
I18N_EN[udpgw_opt_metrics]="Metrics panel"
I18N_EN[udpgw_opt_logs]="View udpgw logs"
I18N_EN[udpgw_opt_adv]="Advanced options"
I18N_EN[udpgw_opt_install]="Install / update udpgw binary"
I18N_EN[udpgw_opt_remove]="Remove port"
I18N_EN[udpgw_opt_back]="Back to Main Menu"

I18N_EN[token_menu_title]="MANAGE TOKENS"
I18N_EN[token_menu_proxy_lic]="Proxy (license):"
I18N_EN[token_opt_config]="Configure Proxy token"
I18N_EN[token_opt_back]="Back"
I18N_EN[token_prompt_input]="Enter proxy token (license %s):"
I18N_EN[token_empty_error]="Token cannot be empty."
I18N_EN[token_saved_success]="Proxy token saved!"
I18N_EN[token_syncing]="Syncing token across proxy services..."
I18N_EN[token_applied_ports]="Token applied to %s proxy port(s)."
I18N_EN[token_invalid_retry]="Invalid proxy token. Try again."

I18N_EN[ssh_menu_title]="ONLINE SSH USERS (%s)"
I18N_EN[ssh_opt_list]="List online SSH users"
I18N_EN[ssh_opt_back]="Back"
I18N_EN[ssh_no_users]="No online SSH users (excluding root)."
I18N_EN[ssh_user_row]="User: %s | PID: %s | Time: %s"

I18N_EN[update_menu_title]="UPDATE SYSTEM"
I18N_EN[update_installed_proxy]="Installed Proxy: %s"
I18N_EN[update_installed_udpgw]="Installed UDPgw: %s"
I18N_EN[update_confirm_prompt]="Update binaries (proxy/udpgw) and vt menu now?"
I18N_EN[update_canceled]="Update canceled."
I18N_EN[update_downloading]="Downloading and running official installer..."
I18N_EN[update_failed]="Update failed."
I18N_EN[update_success]="Update completed (binaries + menu)."
I18N_EN[update_reloading]="Reloading new vt menu..."
I18N_EN[update_notice_title]="UPDATE AVAILABLE!"
I18N_EN[update_notice_prompt]="Select Option [4] to update the system."
I18N_EN[update_badge_available]="NEW UPDATE!"
I18N_EN[update_badge_current]="UP TO DATE"
I18N_EN[update_component_proxy]="Proxy Server:"
I18N_EN[update_component_udpgw]="UDP Gateway:"
I18N_EN[update_component_menu]="Menu Core:"

I18N_EN[remove_title]="COMPLETE UNINSTALL"
I18N_EN[remove_warning_banner]="This action will remove ALL data and services"
I18N_EN[remove_confirm_sure]="ARE YOU SURE you want to completely remove everything?"
I18N_EN[remove_canceled]="Uninstall canceled."
I18N_EN[remove_success]="Complete uninstall finished!"
I18N_EN[remove_clean]="The system is clean."

# --- Español (ES) ---
I18N_ES[header_sub_narrow]="Proxy + UDP Gateway"
I18N_ES[header_sub_wide]="Proxy + UDP Gateway integrados"
I18N_ES[status_proxy]="Proxy:"
I18N_ES[status_token]="Token:"
I18N_ES[status_token_proxy]="Token proxy:"
I18N_ES[status_none]="ninguna"
I18N_ES[status_ip]="IP:"
I18N_ES[status_ssh_onlines]="SSH Online:"
I18N_ES[status_udpgw]="UDP Gateway:"
I18N_ES[status_ports]="Puertos:"
I18N_ES[status_cpu]="CPU:"
I18N_ES[status_ram]="RAM:"

I18N_ES[menu_main_title]="MENÚ PRINCIPAL"
I18N_ES[menu_proxy]="Proxy / Puertos"
I18N_ES[menu_online_users]="Usuarios Online (SSH:%s)"
I18N_ES[menu_tokens]="Gestionar Tokens"
I18N_ES[menu_update]="Actualizar Sistema"
I18N_ES[menu_udpgw]="UDP Gateway (udpgw)"
I18N_ES[menu_lang]="Idioma"
I18N_ES[menu_uninstall]="Desinstalar"
I18N_ES[menu_exit]="Salir"
I18N_ES[prompt_select_option]="Seleccione una opción [%s]:"
I18N_ES[invalid_option]="Opción no válida: %s"
I18N_ES[press_enter]="Presione Enter para continuar..."
I18N_ES[exiting]="Saliendo..."
I18N_ES[root_required]="Este script requiere privilegios de root."
I18N_ES[run_with_sudo]="Ejecute con: sudo %s"

I18N_ES[lang_menu_title]="SELECCIONAR IDIOMA"
I18N_ES[lang_current]="Idioma actual:"
I18N_ES[lang_opt_pt]="Português (PT)"
I18N_ES[lang_opt_en]="English (EN)"
I18N_ES[lang_opt_es]="Español (ES)"
I18N_ES[lang_back]="Volver"
I18N_ES[lang_saved]="¡Idioma cambiado a %s!"

I18N_ES[proxy_menu_title]="%s — PROXY"
I18N_ES[proxy_menu_ports]="Puertos: %s"
I18N_ES[proxy_opt_open]="Abrir / crear nuevo puerto"
I18N_ES[proxy_opt_start]="Activar puerto configurado"
I18N_ES[proxy_opt_stop]="Pausar puerto (mantiene config)"
I18N_ES[proxy_opt_edit]="Editar puerto (SSL)"
I18N_ES[proxy_opt_remove]="Eliminar puerto"
I18N_ES[proxy_opt_restart]="Reiniciar servicio proxy"
I18N_ES[proxy_opt_adv]="Opciones avanzadas (config.json)"
I18N_ES[proxy_opt_http]="Cambiar respuesta HTTP"
I18N_ES[proxy_opt_details]="Detalles del servicio proxy"
I18N_ES[proxy_opt_logs]="Ver registros de VTProxy"
I18N_ES[proxy_opt_back]="Volver al Menú Principal"

I18N_ES[udpgw_menu_title]="UDP GATEWAY (udpgw)"
I18N_ES[udpgw_menu_ports]="Puertos: %s"
I18N_ES[udpgw_opt_open]="Abrir / crear puerto"
I18N_ES[udpgw_opt_start]="Iniciar puerto"
I18N_ES[udpgw_opt_stop]="Detener puerto"
I18N_ES[udpgw_opt_restart]="Reiniciar puerto"
I18N_ES[udpgw_opt_status]="Estado & ExecStart"
I18N_ES[udpgw_opt_metrics]="Panel de métricas"
I18N_ES[udpgw_opt_logs]="Ver registros"
I18N_ES[udpgw_opt_adv]="Opciones avanzadas (flags)"
I18N_ES[udpgw_opt_install]="Instalar/actualizar binario"
I18N_ES[udpgw_opt_remove]="Eliminar puerto"
I18N_ES[udpgw_opt_back]="Volver al Menú Principal"

I18N_ES[token_menu_title]="GESTIONAR TOKENS"
I18N_ES[token_menu_proxy_lic]="Proxy (licencia):"
I18N_ES[token_opt_config]="Configurar token Proxy"
I18N_ES[token_opt_back]="Volver"
I18N_ES[token_prompt_input]="Ingrese el token proxy (licencia %s):"
I18N_ES[token_empty_error]="El token no puede estar vacío."
I18N_ES[token_saved_success]="¡Token proxy guardado!"
I18N_ES[token_syncing]="Sincronizando token en los servicios proxy..."
I18N_ES[token_applied_ports]="Token aplicado a %s puerto(s) proxy."
I18N_ES[token_invalid_retry]="Token proxy no válido. Intente de nuevo."

I18N_ES[ssh_menu_title]="USUARIOS ONLINE SSH (%s)"
I18N_ES[ssh_opt_list]="Listar usuarios SSH online"
I18N_ES[ssh_opt_back]="Volver"
I18N_ES[ssh_no_users]="Ningún usuario SSH online (excluyendo root)."
I18N_ES[ssh_user_row]="Usuario: %s | PID: %s | Tiempo: %s"

I18N_ES[update_menu_title]="ACTUALIZAR SISTEMA"
I18N_ES[update_installed_proxy]="Proxy instalado: %s"
I18N_ES[update_installed_udpgw]="UDPgw instalado: %s"
I18N_ES[update_confirm_prompt]="¿Actualizar binarios (proxy/udpgw) y el menú vt ahora?"
I18N_ES[update_canceled]="Actualización cancelada."
I18N_ES[update_downloading]="Descargando y ejecutando instalador oficial..."
I18N_ES[update_failed]="Fallo en la actualización."
I18N_ES[update_success]="Actualización completada (binarios + menú)."
I18N_ES[update_reloading]="Recargando nuevo menú vt..."
I18N_ES[update_notice_title]="¡ACTUALIZACIÓN DISPONIBLE!"
I18N_ES[update_notice_prompt]="Seleccione la Opción [4] para actualizar el sistema."
I18N_ES[update_badge_available]="¡NUEVO UPDATE!"
I18N_ES[update_badge_current]="ACTUALIZADO"
I18N_ES[update_component_proxy]="Proxy Server:"
I18N_ES[update_component_udpgw]="UDP Gateway:"
I18N_ES[update_component_menu]="Menú Core:"

I18N_ES[remove_title]="DESINSTALACIÓN COMPLETA"
I18N_ES[remove_warning_banner]="Esta acción eliminará TODOS los datos y servicios"
I18N_ES[remove_confirm_sure]="¿ESTÁ SEGURO de que desea eliminar completamente todo?"
I18N_ES[remove_canceled]="Desinstalación cancelada."
I18N_ES[remove_success]="¡Desinstalación completa finalizada!"
I18N_ES[remove_clean]="El sistema está limpio."

load_language() {
    if [[ -f "$LANG_FILE" ]]; then
        LANG_ACTIVE=$(cat "$LANG_FILE" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    else
        local sys_lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
        case "$sys_lang" in
            es*|ES*) LANG_ACTIVE="es" ;;
            en*|EN*) LANG_ACTIVE="en" ;;
            *)       LANG_ACTIVE="pt" ;;
        esac
    fi
    [[ "$LANG_ACTIVE" =~ ^(pt|en|es)$ ]] || LANG_ACTIVE="pt"
}

set_language() {
    local lang="$1"
    [[ "$lang" =~ ^(pt|en|es)$ ]] || return 1
    LANG_ACTIVE="$lang"
    sudo mkdir -p "$(dirname "$LANG_FILE")" 2>/dev/null || true
    printf '%s\n' "$lang" | sudo tee "$LANG_FILE" >/dev/null
}

t() {
    local key="$1"
    shift
    local msg=""

    case "$LANG_ACTIVE" in
        en) msg="${I18N_EN[$key]:-${I18N_PT[$key]:-$key}}" ;;
        es) msg="${I18N_ES[$key]:-${I18N_PT[$key]:-$key}}" ;;
        *)  msg="${I18N_PT[$key]:-$key}" ;;
    esac

    if [[ $# -gt 0 ]]; then
        # shellcheck disable=SC2059
        printf "$msg" "$@"
    else
        printf '%s' "$msg"
    fi
}

language_menu() {
    while true; do
        print_header
        print_box_open
        print_box_heading "$(t lang_menu_title)" "$CYAN"
        print_box_divider
        local current_name="Português"
        [[ "$LANG_ACTIVE" == "en" ]] && current_name="English"
        [[ "$LANG_ACTIVE" == "es" ]] && current_name="Español"
        print_box_line "${WHITE}  $(t lang_current) ${CYAN}${current_name} [${LANG_ACTIVE^^}]${RESET}"
        print_box_divider
        render_menu_option "1 • $(t lang_opt_pt)"
        render_menu_option "2 • $(t lang_opt_en)"
        render_menu_option "3 • $(t lang_opt_es)"
        render_menu_option "0 • $(t lang_back)" "red"
        print_box_close
        echo

        local option
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-3"):${RESET} ")" option
        case "$option" in
            1)
                set_language "pt"
                print_success "$(t lang_saved "Português")"
                pause
                return 0
                ;;
            2)
                set_language "en"
                print_success "$(t lang_saved "English")"
                pause
                return 0
                ;;
            3)
                set_language "es"
                print_success "$(t lang_saved "Español")"
                pause
                return 0
                ;;
            0) return 0 ;;
            *)
                print_error "$(t invalid_option "$option")"
                pause
                ;;
        esac
    done
}

strip_ansi() {
    # Remove códigos ANSI reais (\x1b) e literais \\033 — sem depender de python3.
    printf '%s' "$1" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\\033\[[0-9;]*[a-zA-Z]//g'
}

visible_len() {
    local plain
    plain=$(strip_ansi "$1")
    printf '%s' "${#plain}"
}

detect_term_cols() {
    local cols="${COLUMNS:-}"
    if [[ -z "$cols" || ! "$cols" =~ ^[0-9]+$ ]]; then
        cols=$(stty size 2>/dev/null | awk '{print $2}')
    fi
    if [[ -z "$cols" || ! "$cols" =~ ^[0-9]+$ ]] && command -v tput >/dev/null 2>&1; then
        cols=$(tput cols 2>/dev/null || true)
    fi
    if [[ -z "$cols" || ! "$cols" =~ ^[0-9]+$ ]]; then
        cols=80
    fi
    printf '%s' "$cols"
}

# Ajusta a caixa ao terminal (mobile ~40 cols; desktop até MENU_BOX_MAX).
refresh_menu_layout() {
    local cols inner
    cols=$(detect_term_cols)
    # 2 chars das bordas ║ … ║; 1 de folga evita wrap em alguns clientes SSH
    inner=$((cols - 3))
    if ((inner > MENU_BOX_MAX)); then
        inner=$MENU_BOX_MAX
    elif ((inner < MENU_BOX_MIN)); then
        # Em telas bem estreitas, espreme até o mínimo absoluto
        if ((cols - 2 >= 28)); then
            inner=$((cols - 2))
        else
            inner=28
        fi
    fi
    MENU_BOX_WIDTH=$inner
}

is_narrow_menu() {
    ((MENU_BOX_WIDTH < 46))
}

# Emojis (✅❌) viram "?" no Termius/mobile — usar ASCII colorido.
mark_ok() { printf '%s' "${GREEN}OK${RESET}"; }
mark_fail() { printf '%s' "${RED}X${RESET}"; }
mark_online() { printf '%s' "${GREEN}ON${RESET}"; }
mark_offline() { printf '%s' "${RED}OFF${RESET}"; }

truncate_visible() {
    local text="$1"
    local max="$2"
    local plain cut
    plain=$(strip_ansi "$text")
    if ((${#plain} <= max)); then
        printf '%s' "$text"
        return
    fi
    cut=$((max - 3))
    ((cut < 1)) && cut=1
    printf '%s...' "${plain:0:cut}"
}

# Caixas em ASCII puro — bordas Unicode (═║╔╗) viram "?" em Termius/mobile.
print_box_rule() {
    local left="$1"
    local right="$2"
    local fill
    fill=$(printf '%*s' "$MENU_BOX_WIDTH" "" | tr ' ' '-')
    printf '%b%s%b\n' "${BLUE}${left}" "$fill" "${right}${RESET}"
}

print_box_open() {
    print_box_rule "+" "+"
}

print_box_divider() {
    print_box_rule "+" "+"
}

print_box_close() {
    print_box_rule "+" "+"
}

print_box_line() {
    local content="$1"
    local inner_width="${2:-$MENU_BOX_WIDTH}"
    local len pad
    len=$(visible_len "$content")
    [[ "$len" =~ ^[0-9]+$ ]] || len=0
    if ((len > inner_width)); then
        content=$(truncate_visible "$content" "$inner_width")
        len=$(visible_len "$content")
    fi
    pad=$((inner_width - len))
    ((pad < 0)) && pad=0
    printf '%b' "${BLUE}|${RESET}${content}"
    printf '%*s' "$pad" ""
    printf '%b\n' "${BLUE}|${RESET}"
}

print_box_heading() {
    local text="$1"
    local color="${2:-$WHITE}"
    local plain len left right
    plain=$(strip_ansi "$text")
    if ((${#plain} > MENU_BOX_WIDTH)); then
        text=$(truncate_visible "$plain" "$MENU_BOX_WIDTH")
        plain=$(strip_ansi "$text")
    fi
    len=${#plain}
    left=$(( (MENU_BOX_WIDTH - len) / 2 ))
    right=$((MENU_BOX_WIDTH - len - left))
    ((left < 0)) && left=0
    ((right < 0)) && right=0
    print_box_line "${color}$(printf '%*s%s%*s' "$left" "" "$plain" "$right")${RESET}"
}

render_menu_option() {
    local item="$1"
    local emphasis="${2:-normal}"
    local num="${item%% *}"
    local label="${item#"$num"}"
    label=$(echo "$label" | sed -E 's/^[[:space:]]*[^[:alnum:]]+[[:space:]]*//')
    local content

    if is_narrow_menu; then
        if [[ "$emphasis" == "red" ]]; then
            content="${RED}[${num}] ${label}${RESET}"
        else
            content="${WHITE}[${CYAN}${num}${WHITE}] ${WHITE}${label}${RESET}"
        fi
    else
        if [[ "$emphasis" == "red" ]]; then
            content="${RED}  [${num}] ${label}${RESET}"
        else
            content="${WHITE}  [${CYAN}${num}${WHITE}] ${WHITE}${label}${RESET}"
        fi
    fi
    print_box_line "$content"
}

print_header() {
    clear
    refresh_menu_layout
    print_box_open
    local title="${PROJECT_NAME} Manager"
    local title_len=${#title}
    local title_left=$(( (MENU_BOX_WIDTH - title_len) / 2 ))
    local title_right=$((MENU_BOX_WIDTH - title_len - title_left))
    ((title_left < 0)) && title_left=0
    ((title_right < 0)) && title_right=0
    print_box_line "${BG_BLUE}${WHITE}$(printf '%*s%s%*s' "$title_left" "" "$title" "$title_right")${RESET}"
    if is_narrow_menu; then
        print_box_heading "$(t header_sub_narrow)"
    else
        print_box_heading "$(t header_sub_wide)"
    fi
    print_box_close
    echo
}

# Medição de uso da CPU (%) via /proc/stat
get_cpu_usage() {
    if [[ -f /proc/stat ]]; then
        local cpu1 cpu2
        cpu1=($(grep '^cpu ' /proc/stat 2>/dev/null))
        sleep 0.1
        cpu2=($(grep '^cpu ' /proc/stat 2>/dev/null))
        
        if [[ ${#cpu1[@]} -ge 8 && ${#cpu2[@]} -ge 8 ]]; then
            local user1=${cpu1[1]} nice1=${cpu1[2]} sys1=${cpu1[3]} idle1=${cpu1[4]} iowait1=${cpu1[5]} irq1=${cpu1[6]} softirq1=${cpu1[7]}
            local user2=${cpu2[1]} nice2=${cpu2[2]} sys2=${cpu2[3]} idle2=${cpu2[4]} iowait2=${cpu2[5]} irq2=${cpu2[6]} softirq2=${cpu2[7]}
            
            local total1=$((user1 + nice1 + sys1 + idle1 + iowait1 + irq1 + softirq1))
            local total2=$((user2 + nice2 + sys2 + idle2 + iowait2 + irq2 + softirq2))
            
            local total_diff=$((total2 - total1))
            local idle_diff=$((idle2 - idle1))
            
            if ((total_diff > 0)); then
                local usage=$(( (total_diff - idle_diff) * 100 / total_diff ))
                printf '%d' "$usage"
                return 0
            fi
        fi
    fi
    echo "0"
}

# Medição de uso de RAM (usado_mb, total_mb, pct_usado) via /proc/meminfo
get_ram_info() {
    local total_mb=0 avail_mb=0 used_mb=0 used_pct=0
    if [[ -f /proc/meminfo ]]; then
        local total_kb avail_kb free_kb buffers_kb cached_kb
        total_kb=$(grep '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')
        avail_kb=$(grep '^MemAvailable:' /proc/meminfo 2>/dev/null | awk '{print $2}')
        
        if [[ -z "$avail_kb" ]]; then
            free_kb=$(grep '^MemFree:' /proc/meminfo 2>/dev/null | awk '{print $2}')
            buffers_kb=$(grep '^Buffers:' /proc/meminfo 2>/dev/null | awk '{print $2}')
            cached_kb=$(grep '^Cached:' /proc/meminfo 2>/dev/null | awk '{print $2}')
            avail_kb=$(( free_kb + buffers_kb + cached_kb ))
        fi
        
        if [[ -n "$total_kb" && "$total_kb" =~ ^[0-9]+$ && -n "$avail_kb" && "$avail_kb" =~ ^[0-9]+$ ]]; then
            total_mb=$(( total_kb / 1024 ))
            local used_kb=$(( total_kb - avail_kb ))
            ((used_kb < 0)) && used_kb=0
            used_mb=$(( used_kb / 1024 ))
            if ((total_mb > 0)); then
                used_pct=$(( used_mb * 100 / total_mb ))
            fi
        fi
    fi
    printf '%d %d %d' "$used_mb" "$total_mb" "$used_pct"
}

format_stat_color() {
    local val="$1"
    if ((val >= 90)); then
        printf '%s%d%%%s' "${RED}" "$val" "${RESET}"
    elif ((val >= 70)); then
        printf '%s%d%%%s' "${YELLOW}" "$val" "${RESET}"
    else
        printf '%s%d%%%s' "${GREEN}" "$val" "${RESET}"
    fi
}

# Usuários SSH únicos com sessão sshd (filhos sshd:), excluindo root.
get_ssh_online_users_count() {
    local count=""
    # 1. Se o servico proxy unificado estiver ativo, consulta a CLI nativa de conexoes
    if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null && [[ -x "$PROXY_EXECUTABLE" ]]; then
        count=$("$PROXY_EXECUTABLE" --onlines-total 2>/dev/null | tr -d '[:space:]' || true)
        if [[ "$count" =~ ^[0-9]+$ ]]; then
            echo "$count"
            return 0
        fi
    fi

    # 2. Fallback para contagem do OpenSSH externo legado
    count=$(
        pgrep -f 'sshd:' 2>/dev/null \
            | xargs -r ps -o user= 2>/dev/null \
            | grep -v '^root$' \
            | sort -u \
            | wc -l \
        || true
    )
    count=$(printf '%s' "$count" | tr -d '[:space:]')
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    echo "$count"
}

print_status() {
    local proxy_ports proxy_label proxy_tok udpgw_status bound_ip ssh_onlines
    local cpu_usage ram_info ram_used_mb ram_total_mb ram_pct
    local cpu_colored ram_colored

    proxy_ports=$(format_proxy_ports_status)
    proxy_label="${proxy_ports:-$(t status_none)}"
    [[ -n "$(load_proxy_token)" ]] && proxy_tok="$(mark_ok)" || proxy_tok="$(mark_fail)"
    bound_ip=""
    [[ -f /etc/vtproxy/ip ]] && bound_ip=$(cat /etc/vtproxy/ip)
    ssh_onlines=$(get_ssh_online_users_count)

    cpu_usage=$(get_cpu_usage)
    ram_info=($(get_ram_info))
    ram_used_mb="${ram_info[0]:-0}"
    ram_total_mb="${ram_info[1]:-0}"
    ram_pct="${ram_info[2]:-0}"

    cpu_colored=$(format_stat_color "$cpu_usage")
    ram_colored=$(format_stat_color "$ram_pct")

    local udpgw_ports
    udpgw_ports=$(format_udpgw_ports_status)
    if is_udpgw_active; then
        udpgw_status="$(mark_online)"
    else
        udpgw_status="$(mark_offline)"
    fi

    print_box_open

    if is_narrow_menu; then
        print_box_line "${WHITE}$(t status_proxy) ${CYAN}${proxy_label}${RESET}"
        local tok_line="${WHITE}$(t status_token) ${proxy_tok}"
        [[ -n "$bound_ip" ]] && tok_line+=" ${WHITE}| ${CYAN}${bound_ip}${RESET}"
        print_box_line "$tok_line"
        print_box_line "${WHITE}$(t status_ssh_onlines) ${CYAN}${ssh_onlines}${RESET}"
        print_box_line "${WHITE}$(t status_cpu) ${cpu_colored}${WHITE} | $(t status_ram) ${CYAN}${ram_used_mb}/${ram_total_mb}MB${WHITE} (${ram_colored}${WHITE})${RESET}"
        print_box_line "${WHITE}UDPgw: ${udpgw_status}${WHITE} | $(t status_ports) ${CYAN}${udpgw_ports}${RESET}"
    else
        print_box_line "${WHITE} $(t status_proxy) ${CYAN}${proxy_label}${RESET}"
        local tokens_line="${WHITE} $(t status_token_proxy) ${proxy_tok}"
        if [[ -n "$bound_ip" ]]; then
            tokens_line+="${WHITE} | $(t status_ip) ${CYAN}${bound_ip}${RESET}"
        fi
        print_box_line "$tokens_line"
        print_box_line "${WHITE} $(t status_ssh_onlines) ${CYAN}${ssh_onlines}${WHITE} | $(t status_cpu) ${cpu_colored}${WHITE} | $(t status_ram) ${CYAN}${ram_used_mb}/${ram_total_mb}MB${WHITE} (${ram_colored}${WHITE})${RESET}"
        print_box_line "${WHITE} $(t status_udpgw) ${udpgw_status}${WHITE} | $(t status_ports) ${CYAN}${udpgw_ports}${RESET}"
    fi
    print_box_close
    echo
}

print_update_available_notice() {
    check_system_updates false

    if [[ "${HAS_SYSTEM_UPDATE:-0}" -ne 1 ]]; then
        return 0
    fi

    local local_proxy local_udpgw
    local_proxy=$(get_installed_proxy_version_label)
    local_udpgw=$(get_installed_udpgw_version_label)

    print_box_open
    print_box_heading "$(t update_notice_title)" "$YELLOW"
    print_box_divider

    if [[ "${HAS_PROXY_UPDATE:-0}" -eq 1 ]]; then
        print_box_line "${WHITE}  • Proxy:  ${CYAN}v${local_proxy}${RESET} ${WHITE}➜ ${GREEN}v${REMOTE_PROXY_VER}${RESET}"
    fi
    if [[ "${HAS_UDPGW_UPDATE:-0}" -eq 1 ]]; then
        print_box_line "${WHITE}  • UDPgw:  ${CYAN}v${local_udpgw}${RESET} ${WHITE}➜ ${GREEN}v${REMOTE_UDPGW_VER}${RESET}"
    fi
    if [[ "${HAS_MENU_UPDATE:-0}" -eq 1 ]]; then
        print_box_line "${WHITE}  • Menu:   ${CYAN}rev ${MENU_REV}${RESET} ${WHITE}➜ ${GREEN}rev ${REMOTE_MENU_REV}${RESET}"
    fi

    print_box_line "${YELLOW}  $(t update_notice_prompt)${RESET}"
    print_box_close
    echo
}

print_initial_menu() {
    print_update_available_notice

    print_box_open
    print_box_heading "$(t menu_main_title)"
    print_box_divider

    local ssh_onlines
    ssh_onlines=$(get_ssh_online_users_count)
    
    local update_label="$(t menu_update)"
    if [[ "${HAS_SYSTEM_UPDATE:-0}" -eq 1 ]]; then
        update_label+=" ${YELLOW}[$(t update_badge_available)]"
    fi

    local menu_items=(
        "1 • $(t menu_proxy)"
        "2 • $(t menu_online_users "$ssh_onlines")"
        "3 • $(t menu_tokens)"
        "4 • ${update_label}"
        "5 • $(t menu_udpgw)"
        "6 • $(t menu_lang) [${LANG_ACTIVE^^}]"
        "7 • $(t menu_uninstall)"
        "0 • $(t menu_exit)"
    )
    
    for item in "${menu_items[@]}"; do
        if [[ $item == *"$(t menu_uninstall)"* || $item == *"$(t menu_exit)"* || $item == *"Remover"* || $item == *"Uninstall"* || $item == *"Desinstalar"* || $item == *"Sair"* || $item == *"Exit"* || $item == *"Salir"* ]]; then
            render_menu_option "$item" "red"
        elif [[ $item == *"$(t update_badge_available)"* ]]; then
            render_menu_option "$item" "yellow"
        else
            render_menu_option "$item"
        fi
    done
    
    print_box_close
    echo
}

print_success() {
    echo -e "${GREEN}$1${RESET}"
}

print_error() {
    echo -e "${RED}$1${RESET}"
}

print_info() {
    echo -e "${CYAN}$1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}$1${RESET}"
}

prompt_input() {
    echo -e "${BLUE}$1${RESET}"
    read -rp "> " response
    echo "$response"
}

pause() {
    echo
    print_warning "$(t press_enter)"
    read -r
}

init_proxy_dirs() {
    sudo mkdir -p "$PROXY_DIR" "$PROXY_CONFIG_DIR" "$PROXY_LOG_DIR" "$PROXY_JSON_DIR" /var/log/proxy
}

load_proxy_token() {
    local token=""
    if [[ -f "$PROXY_JSON_FILE" ]] && command -v python3 >/dev/null 2>&1; then
        token=$(python3 -c '
import json
try:
    with open("/etc/proxyvt/config.json", "r", encoding="utf-8") as f:
        d = json.load(f)
    tok = str(d.get("token", "")).strip()
    if tok: print(tok)
except Exception:
    pass
' 2>/dev/null || true)
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi

    local file
    for file in "$PROXY_TOKEN_VTPROXY" "$PROXY_TOKEN_FILE" "$PROXY_TOKEN_HOME"; do
        if [[ -f "$file" ]]; then
            cat "$file"
            return 0
        fi
    done
    echo ""
}

save_proxy_token() {
    local token="$1"
    sudo mkdir -p "$(dirname "$PROXY_TOKEN_VTPROXY")" "$PROXY_DIR" "$PROXY_JSON_DIR"
    printf '%s' "$token" | sudo tee "$PROXY_TOKEN_VTPROXY" >/dev/null
    printf '%s' "$token" | sudo tee "$PROXY_TOKEN_FILE" >/dev/null
    printf '%s' "$token" >"$PROXY_TOKEN_HOME"
    sudo chmod 600 "$PROXY_TOKEN_VTPROXY" "$PROXY_TOKEN_FILE" 2>/dev/null || true
    chmod 600 "$PROXY_TOKEN_HOME" 2>/dev/null || true

    ensure_proxy_json_config
    json_set_field "token" "$token" "string"
}

validate_proxy_token() {
    local token="$1"
    [[ -n "$token" ]] || return 1

    if [[ ! -x "$PROXY_EXECUTABLE" ]]; then
        print_error "Binário proxy não encontrado: $PROXY_EXECUTABLE"
        print_info "Execute o instalador ou verifique se proxy-server está instalado."
        return 1
    fi

    "$PROXY_EXECUTABLE" --token "$token" --validate >/dev/null 2>&1
}

ensure_proxy_json_config() {
    sudo mkdir -p "$PROXY_JSON_DIR" "$PROXY_LOG_DIR" 2>/dev/null || true

    if [[ ! -f "$PROXY_JSON_FILE" ]]; then
        if [[ -x "$PROXY_EXECUTABLE" ]] && "$PROXY_EXECUTABLE" --dump-config >/dev/null 2>&1; then
            "$PROXY_EXECUTABLE" --dump-config 2>/dev/null | sudo tee "$PROXY_JSON_FILE" >/dev/null || true
        fi
    fi

    local current_token
    current_token=$(load_proxy_token)

    if [[ ! -s "$PROXY_JSON_FILE" ]] && command -v python3 >/dev/null 2>&1; then
        sudo python3 -c '
import json, os, sys
path = "/etc/proxyvt/config.json"
token = sys.argv[1] if len(sys.argv) > 1 else ""
default_cfg = {
  "token": token,
  "ports": ["80", "443:ssl"],
  "disabled_ports": [],
  "log_level": "info",
  "log_file": "",
  "buffer_size": 32768,
  "max_connections": 0,
  "idle_timeout": 0,
  "write_timeout": 0,
  "cert": "",
  "cert_internal": True,
  "display_banner": True,
  "response": "VeltrixProxy",
  "ssh_only": False,
  "ulimit": 65536,
  "ssh": {
    "internal": True,
    "internal_port": 0,
    "port": 22,
    "auth": "shadow",
    "auth_file": "",
    "allow_root": True,
    "banner": "SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3"
  },
  "btun": {
    "enable": True,
    "tun": "btun0",
    "subnet": "10.77.0.0/16",
    "auth": "shadow",
    "auth_file": "/etc/btun/users",
    "udp_port": 0
  },
  "limits": {
    "default_user_limit": 0,
    "passwd_file": "/etc/passwd",
    "expire_check_interval": "1m"
  },
  "connectors": {
    "openvpn_port": 1194,
    "v2ray_port": 1080
  },
  "xhttp": {
    "path": "/ssh",
    "grace": 120,
    "idle": 120
  }
}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(default_cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
' "$current_token" 2>/dev/null || true
    fi

    if [[ -f "$PROXY_JSON_FILE" ]] && command -v python3 >/dev/null 2>&1; then
        sudo python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
try:
    with open(p, "r", encoding="utf-8") as f:
        d = json.load(f)
    changed = False
    if "limits" in d and isinstance(d["limits"], dict) and "kill_expired" in d["limits"]:
        d["limits"].pop("kill_expired", None)
        changed = True
    if "kill_expired" in d:
        d.pop("kill_expired", None)
        changed = True
    if sys.argv[1] and (not d.get("token") or d.get("token") != sys.argv[1]):
        d["token"] = sys.argv[1]
        changed = True
    if changed:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(d, f, indent=2, ensure_ascii=False)
            f.write("\n")
except Exception:
    pass
' "$current_token" 2>/dev/null || true
    fi
}

migrate_flags_to_json_if_needed() {
    local token
    token=$(load_proxy_token)

    if ! command -v python3 >/dev/null 2>&1; then
        ensure_proxy_json_config
        return 0
    fi

    sudo python3 -c '
import json, os, re, glob, sys

json_path = "/etc/proxyvt/config.json"
default_token = sys.argv[1] if len(sys.argv) > 1 else ""

config = {
    "token": default_token or "",
    "ports": [],
    "disabled_ports": [],
    "log_level": "info",
    "log_file": "",
    "buffer_size": 32768,
    "max_connections": 0,
    "idle_timeout": 0,
    "write_timeout": 0,
    "cert": "",
    "cert_internal": True,
    "display_banner": True,
    "response": "VeltrixProxy",
    "ssh_only": False,
    "ulimit": 65536,
    "ssh": {
        "internal": True,
        "internal_port": 0,
        "port": 22,
        "auth": "shadow",
        "auth_file": "",
        "allow_root": True,
        "banner": "SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3"
    },
    "btun": {
        "enable": True,
        "tun": "btun0",
        "subnet": "10.77.0.0/16",
        "auth": "shadow",
        "auth_file": "/etc/btun/users",
        "udp_port": 0
    },
    "limits": {
        "default_user_limit": 0,
        "passwd_file": "/etc/passwd",
        "expire_check_interval": "1m"
    },
    "connectors": {
        "openvpn_port": 1194,
        "v2ray_port": 1080
    },
    "xhttp": {
        "path": "/ssh",
        "grace": 120,
        "idle": 120
    }
}

if os.path.exists(json_path):
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            existing = json.load(f)
            for k, v in existing.items():
                if isinstance(v, dict) and k in config and isinstance(config[k], dict):
                    config[k].update(v)
                else:
                    config[k] = v
    except Exception:
        pass

def normalize_port_list(ports_list):
    res = []
    for p in ports_list:
        if isinstance(p, dict):
            p_num = str(p.get("port", "")).strip()
            if p.get("ssl"):
                res.append(f"{p_num}:ssl")
            else:
                res.append(p_num)
        else:
            res.append(str(p).strip())
    return res

found_active = normalize_port_list(config.get("ports", []))
found_disabled = normalize_port_list(config.get("disabled_ports", []))

service_files = glob.glob("/etc/systemd/system/proxy-*.service")
if os.path.isfile("/etc/systemd/system/vtproxy.service"):
    service_files.append("/etc/systemd/system/vtproxy.service")

for sf in service_files:
    try:
        with open(sf, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        continue

    for line in content.splitlines():
        line = line.strip()
        if not line.startswith("ExecStart="):
            continue
        exec_cmd = line[len("ExecStart="):]

        m_tok = re.search(r"--token[= ]([^\s]+)", exec_cmd)
        if m_tok and not config.get("token"):
            config["token"] = m_tok.group(1).strip()

        for m_port in re.finditer(r"--port[= ]([^\s]+)", exec_cmd):
            pval = m_port.group(1).strip()
            if pval and pval not in found_active and pval not in found_disabled:
                found_active.append(pval)

        m_svc_port = re.search(r"proxy-([0-9]+)\.service", os.path.basename(sf))
        if m_svc_port:
            pnum = m_svc_port.group(1)
            is_ssl = ":ssl" in exec_cmd or "--cert=" in exec_cmd
            entry = f"{pnum}:ssl" if is_ssl else pnum
            if entry not in found_active and entry not in found_disabled:
                found_active.append(entry)

        m_buf = re.search(r"--buffer-size[= ]([0-9]+)", exec_cmd)
        if m_buf:
            config["buffer_size"] = int(m_buf.group(1))

        m_resp = re.search(r"--response[= ]([^\s]+)", exec_cmd)
        if m_resp:
            config["response"] = m_resp.group(1).strip()

        m_idle = re.search(r"--idle-timeout[= ]([0-9]+)", exec_cmd)
        if m_idle:
            config["idle_timeout"] = int(m_idle.group(1))
        m_write = re.search(r"--write-timeout[= ]([0-9]+)", exec_cmd)
        if m_write:
            config["write_timeout"] = int(m_write.group(1))

        m_max = re.search(r"--max-connections[= ]([0-9]+)", exec_cmd)
        if m_max:
            config["max_connections"] = int(m_max.group(1))

        m_ll = re.search(r"--log-level[= ]([a-zA-Z]+)", exec_cmd)
        if m_ll:
            config["log_level"] = m_ll.group(1).lower()

        if "--cert-internal=false" in exec_cmd:
            config["cert_internal"] = False
        elif "--cert-internal" in exec_cmd:
            config["cert_internal"] = True

        m_cert = re.search(r"--cert[= ]([^\s]+)", exec_cmd)
        if m_cert:
            config["cert"] = m_cert.group(1)
            if "--cert-internal" not in exec_cmd:
                config["cert_internal"] = False

        if "--ssh-only" in exec_cmd:
            config["ssh_only"] = True
        if "--display-banner=false" in exec_cmd:
            config["display_banner"] = False

        m_sp = re.search(r"--ssh-port[= ]([0-9]+)", exec_cmd)
        if m_sp:
            config["ssh"]["port"] = int(m_sp.group(1))
        m_op = re.search(r"--openvpn-port[= ]([0-9]+)", exec_cmd)
        if m_op:
            config["connectors"]["openvpn_port"] = int(m_op.group(1))
        m_vp = re.search(r"--v2ray-port[= ]([0-9]+)", exec_cmd)
        if m_vp:
            config["connectors"]["v2ray_port"] = int(m_vp.group(1))

        if "--btun-enable=false" in exec_cmd:
            config["btun"]["enable"] = False
        elif "--btun-enable" in exec_cmd:
            config["btun"]["enable"] = True
        m_tun = re.search(r"--btun-tun[= ]([^\s]+)", exec_cmd)
        if m_tun:
            config["btun"]["tun"] = m_tun.group(1)
        m_sub = re.search(r"--btun-subnet[= ]([^\s]+)", exec_cmd)
        if m_sub:
            config["btun"]["subnet"] = m_sub.group(1)

conf_dir = "/etc/proxy/conf.d"
if os.path.isdir(conf_dir):
    for cfile in sorted(glob.glob(os.path.join(conf_dir, "proxy-*.conf"))):
        try:
            kv = {}
            with open(cfile, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        kv[k.strip()] = v.strip()
            p_val = kv.get("PORT")
            if not p_val:
                m_fn = re.search(r"proxy-([0-9]+)\.conf", os.path.basename(cfile))
                if m_fn:
                    p_val = m_fn.group(1)
            if p_val:
                is_ssl = kv.get("SSL_ENABLED", "false").lower() == "true"
                entry = f"{p_val}:ssl" if is_ssl else str(p_val)
                is_en = kv.get("ENABLED", "true").lower() != "false"
                if is_en:
                    if entry not in found_active:
                        found_active.append(entry)
                else:
                    if entry not in found_disabled:
                        found_disabled.append(entry)
            if kv.get("HTTP_RESPONSE") and config["response"] == "VeltrixProxy":
                config["response"] = kv["HTTP_RESPONSE"]
            if kv.get("BUFFER_SIZE") and config["buffer_size"] == 32768:
                try:
                    config["buffer_size"] = int(kv["BUFFER_SIZE"])
                except ValueError:
                    pass
        except Exception:
            pass

seen = set()
cleaned_active = []
for p in found_active:
    p_str = str(p).strip()
    p_num = p_str.split(":")[0]
    if p_num not in seen:
        seen.add(p_num)
        cleaned_active.append(p_str)

cleaned_disabled = []
for p in found_disabled:
    p_str = str(p).strip()
    p_num = p_str.split(":")[0]
    if p_num not in seen:
        seen.add(p_num)
        cleaned_disabled.append(p_str)

config["ports"] = cleaned_active
config["disabled_ports"] = cleaned_disabled

if "limits" in config and isinstance(config["limits"], dict):
    config["limits"].pop("kill_expired", None)
if "kill_expired" in config:
    config.pop("kill_expired", None)

os.makedirs(os.path.dirname(json_path), exist_ok=True)
temp_path = json_path + ".tmp"
with open(temp_path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")
if os.path.exists(json_path):
    os.replace(temp_path, json_path)
else:
    os.rename(temp_path, json_path)
' "$token" 2>/dev/null || true
}

json_get_field() {
    local key_path="$1"
    local default_val="${2:-}"
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
key_path = sys.argv[1]
default = sys.argv[2]
try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    cur = data
    for k in key_path.split("."):
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            print(default)
            sys.exit(0)
    if isinstance(cur, bool):
        print("true" if cur else "false")
    elif cur is None:
        print(default)
    else:
        print(cur)
except Exception:
    print(default)
' "$key_path" "$default_val" 2>/dev/null || echo "$default_val"
    else
        echo "$default_val"
    fi
}

json_set_field() {
    local key_path="$1"
    local val="$2"
    local val_type="${3:-string}"
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        sudo python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
key_path = sys.argv[1]
raw_val = sys.argv[2]
vtype = sys.argv[3] if len(sys.argv) > 3 else "string"

try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

if vtype == "int":
    try:
        val = int(raw_val)
    except ValueError:
        val = 0
elif vtype == "bool":
    val = raw_val.lower() in ("true", "1", "yes", "s")
else:
    val = str(raw_val)

cur = data
keys = key_path.split(".")
for k in keys[:-1]:
    if k not in cur or not isinstance(cur[k], dict):
        cur[k] = {}
    cur = cur[k]
cur[keys[-1]] = val

with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
' "$key_path" "$val" "$val_type" 2>/dev/null || true
    fi
}

json_get_active_ports() {
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        python3 -c '
import json
try:
    with open("/etc/proxyvt/config.json", "r", encoding="utf-8") as f:
        data = json.load(f)
    ports = data.get("ports", [])
    res = []
    for p in ports:
        if isinstance(p, dict):
            pnum = str(p.get("port", ""))
            res.append(f"{pnum}:ssl" if p.get("ssl") else pnum)
        else:
            res.append(str(p).strip())
    print(",".join(res))
except Exception:
    pass
' 2>/dev/null || true
    fi
}

json_get_disabled_ports() {
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        python3 -c '
import json
try:
    with open("/etc/proxyvt/config.json", "r", encoding="utf-8") as f:
        data = json.load(f)
    disabled = data.get("disabled_ports", [])
    res = []
    for p in disabled:
        if isinstance(p, dict):
            pnum = str(p.get("port", ""))
            res.append(f"{pnum}:ssl" if p.get("ssl") else pnum)
        else:
            res.append(str(p).strip())
    print(",".join(res))
except Exception:
    pass
' 2>/dev/null || true
    fi
}

json_add_port() {
    local port="$1"
    local is_ssl="${2:-false}"
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        sudo python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
port_num = str(sys.argv[1]).strip()
is_ssl = sys.argv[2].lower() in ("true", "1", "yes", "s")
entry = f"{port_num}:ssl" if is_ssl else port_num

def pnum(val):
    if isinstance(val, dict): return str(val.get("port", "")).strip()
    return str(val).split(":")[0].strip()

try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    ports = data.get("ports", [])
    disabled = data.get("disabled_ports", [])

    disabled = [x for x in disabled if pnum(x) != port_num]

    new_ports = []
    replaced = False
    for x in ports:
        if pnum(x) == port_num:
            new_ports.append(entry)
            replaced = True
        else:
            new_ports.append(x)
    if not replaced:
        new_ports.append(entry)

    data["ports"] = new_ports
    data["disabled_ports"] = disabled

    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
except Exception:
    pass
' "$port" "$is_ssl" 2>/dev/null || true
    fi
}

json_remove_port() {
    local port="$1"
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        sudo python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
port_num = str(sys.argv[1]).strip()

def pnum(val):
    if isinstance(val, dict): return str(val.get("port", "")).strip()
    return str(val).split(":")[0].strip()

try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    data["ports"] = [x for x in data.get("ports", []) if pnum(x) != port_num]
    data["disabled_ports"] = [x for x in data.get("disabled_ports", []) if pnum(x) != port_num]
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
except Exception:
    pass
' "$port" 2>/dev/null || true
    fi
}

json_toggle_port() {
    local port="$1"
    local enable_flag="$2"
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        sudo python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
port_num = str(sys.argv[1]).strip()
enable = sys.argv[2].lower() in ("true", "1", "yes", "s")

def pnum(val):
    if isinstance(val, dict): return str(val.get("port", "")).strip()
    return str(val).split(":")[0].strip()

try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    ports = list(data.get("ports", []))
    disabled = list(data.get("disabled_ports", []))

    found_item = None
    for x in ports:
        if pnum(x) == port_num:
            found_item = x
            break
    if not found_item:
        for x in disabled:
            if pnum(x) == port_num:
                found_item = x
                break
    if not found_item:
        found_item = port_num

    if enable:
        disabled = [x for x in disabled if pnum(x) != port_num]
        if not any(pnum(x) == port_num for x in ports):
            ports.append(found_item)
    else:
        ports = [x for x in ports if pnum(x) != port_num]
        if not any(pnum(x) == port_num for x in disabled):
            disabled.append(found_item)

    data["ports"] = ports
    data["disabled_ports"] = disabled
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
except Exception:
    pass
' "$port" "$enable_flag" 2>/dev/null || true
    fi
}

json_set_port_ssl() {
    local port="$1"
    local is_ssl="$2"
    ensure_proxy_json_config
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROXY_JSON_FILE" ]]; then
        sudo python3 -c '
import json, sys
p = "/etc/proxyvt/config.json"
port_num = str(sys.argv[1]).strip()
is_ssl = sys.argv[2].lower() in ("true", "1", "yes", "s")
entry = f"{port_num}:ssl" if is_ssl else port_num

def pnum(val):
    if isinstance(val, dict): return str(val.get("port", "")).strip()
    return str(val).split(":")[0].strip()

try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    ports = data.get("ports", [])
    disabled = data.get("disabled_ports", [])

    if any(pnum(x) == port_num for x in ports):
        data["ports"] = [entry if pnum(x) == port_num else x for x in ports]
    elif any(pnum(x) == port_num for x in disabled):
        data["disabled_ports"] = [entry if pnum(x) == port_num else x for x in disabled]
    else:
        data.setdefault("ports", []).append(entry)

    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
except Exception:
    pass
' "$port" "$is_ssl" 2>/dev/null || true
    fi
}

is_proxy_port_ssl() {
    local port="$1"
    local p active disabled
    active=$(json_get_active_ports)
    disabled=$(json_get_disabled_ports)
    for p in ${active//,/ } ${disabled//,/ }; do
        if [[ "$p" == "${port}:ssl" ]]; then
            echo "true"
            return 0
        fi
    done
    echo "false"
}

is_proxy_port_enabled() {
    local port="$1"
    local p active
    active=$(json_get_active_ports)
    for p in ${active//,/ }; do
        local pnum="${p%%:*}"
        if [[ "$pnum" == "$port" ]]; then
            echo "true"
            return 0
        fi
    done
    echo "false"
}

is_proxy_service_configured() {
    local port="$1"
    local p all_ports
    all_ports=$(list_configured_proxy_ports)
    [[ -z "$all_ports" ]] && return 1
    IFS=',' read -ra port_arr <<< "$all_ports"
    for p in "${port_arr[@]}"; do
        [[ "$p" == "$port" ]] && return 0
    done
    return 1
}

list_configured_proxy_ports() {
    local active disabled all_ports=() p pnum
    active=$(json_get_active_ports)
    disabled=$(json_get_disabled_ports)

    for p in ${active//,/ } ${disabled//,/ }; do
        [[ -z "$p" ]] && continue
        pnum="${p%%:*}"
        [[ -n "$pnum" ]] && all_ports+=("$pnum")
    done

    # Fallback legado se JSON ainda nao tiver portas
    if [[ ${#all_ports[@]} -eq 0 ]]; then
        for f in "$PROXY_CONFIG_DIR"/proxy-*.conf; do
            [[ -f "$f" ]] || continue
            pnum=$(basename "$f" .conf | sed -n 's/^proxy-\([0-9]\+\)$/\1/p')
            [[ -n "$pnum" ]] && all_ports+=("$pnum")
        done
    fi

    if [[ ${#all_ports[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%s\n' "${all_ports[@]}" | sort -nu | paste -sd, - 2>/dev/null || true
}

get_global_proxy_setting() {
    local key="$1"
    local default_val="${2:-}"

    case "$key" in
        HTTP_RESPONSE) json_get_field "response" "$default_val" ;;
        BUFFER_SIZE) json_get_field "buffer_size" "$default_val" ;;
        MAX_CONNECTIONS) json_get_field "max_connections" "$default_val" ;;
        WRITE_TIMEOUT) json_get_field "write_timeout" "$default_val" ;;
        IDLE_TIMEOUT) json_get_field "idle_timeout" "$default_val" ;;
        LOG_LEVEL) json_get_field "log_level" "$default_val" ;;
        SSH_PORT) json_get_field "ssh.port" "$default_val" ;;
        OPENVPN_PORT) json_get_field "connectors.openvpn_port" "$default_val" ;;
        V2RAY_PORT) json_get_field "connectors.v2ray_port" "$default_val" ;;
        SSH_ONLY) json_get_field "ssh_only" "$default_val" ;;
        CERT_INTERNAL) json_get_field "cert_internal" "$default_val" ;;
        DISPLAY_BANNER) json_get_field "display_banner" "$default_val" ;;
        SSL_CERT_PATH) json_get_field "cert" "$default_val" ;;
        *) json_get_field "$key" "$default_val" ;;
    esac
}

ensure_proxy_dirs_quiet() {
    sudo mkdir -p "$PROXY_DIR" "$PROXY_CONFIG_DIR" "$PROXY_LOG_DIR" "$PROXY_JSON_DIR" 2>/dev/null || true
}

list_active_proxies() {
    if ! systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
        return 0
    fi
    local active p pnum res=()
    active=$(json_get_active_ports)
    for p in ${active//,/ }; do
        [[ -z "$p" ]] && continue
        pnum="${p%%:*}"
        [[ -n "$pnum" ]] && res+=("$pnum")
    done
    printf '%s' "${res[*]}" | tr ' ' ','
}

format_proxy_port_flags() {
    local port="$1"
    local flags=()
    local ssl cert_internal ssh_only

    ssl=$(is_proxy_port_ssl "$port")
    cert_internal=$(json_get_field "cert_internal" "true")
    ssh_only=$(json_get_field "ssh_only" "false")

    [[ "$ssl" == "true" ]] && flags+=("ssl")
    if [[ "$ssl" == "true" && "$cert_internal" == "true" ]]; then
        flags+=("cert-int")
    elif [[ "$ssl" == "true" ]]; then
        flags+=("cert-ext")
    fi
    [[ "$ssh_only" == "true" ]] && flags+=("ssh-only")

    if [[ ${#flags[@]} -eq 0 ]]; then
        echo ""
        return 0
    fi
    local IFS=,
    echo "${flags[*]}"
}

format_proxy_ports_status() {
    local active disabled status_items=() p pnum

    active=$(json_get_active_ports)
    disabled=$(json_get_disabled_ports)

    if [[ -z "$active" && -z "$disabled" ]]; then
        local leg
        leg=$(list_configured_proxy_ports)
        if [[ -z "$leg" ]]; then
            echo "nenhuma"
            return 0
        fi
    fi

    for p in ${active//,/ }; do
        [[ -z "$p" ]] && continue
        pnum="${p%%:*}"
        if [[ "$p" == *":ssl"* ]]; then
            status_items+=("${pnum} [SSL]")
        else
            status_items+=("${pnum}")
        fi
    done

    for p in ${disabled//,/ }; do
        [[ -z "$p" ]] && continue
        pnum="${p%%:*}"
        if [[ "$p" == *":ssl"* ]]; then
            status_items+=("${pnum} [SSL] (OFF)")
        else
            status_items+=("${pnum} (OFF)")
        fi
    done

    local count=${#status_items[@]}
    if (( count == 0 )); then
        echo "nenhuma"
        return 0
    fi

    if (( count <= 4 )); then
        local IFS=,
        echo "${status_items[*]}" | sed 's/,/, /g'
        local first_four=("${status_items[@]:0:4}")
        local remaining=$(( count - 4 ))
        local IFS=,
        echo "${first_four[*]}" | sed 's/,/, /g' | sed "s/$/ (+${remaining} portas)/"
    fi
}

is_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | grep -qE ":${port}([[:space:]]|$)" && return 0
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln 2>/dev/null | grep -qE ":${port}([[:space:]]|$)" && return 0
    elif command -v lsof >/dev/null 2>&1; then
        lsof -i ":$port" >/dev/null 2>&1 && return 0
    elif command -v fuser >/dev/null 2>&1; then
        fuser "$port/tcp" >/dev/null 2>&1 && return 0
    elif [[ -f /proc/net/tcp ]]; then
        local hex_port
        hex_port=$(printf '%04X' "$port" 2>/dev/null || true)
        if [[ -n "$hex_port" ]]; then
            grep -qE ":${hex_port}[[:space:]]" /proc/net/tcp /proc/net/tcp6 2>/dev/null && return 0
        fi
    fi
    return 1
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\/&|]/\\&/g'
}

prompt_for_proxy_token_if_missing() {
    local current_token
    current_token=$(load_proxy_token)

    if [[ -z "$current_token" ]]; then
        echo
        print_warning "Token proxy (${PROJECT_NAME}) não encontrado!"
        echo -e "${BLUE}Insira seu token de licença (VT-...):${RESET}"
        read -rp "> " new_token

        if [[ -n "$new_token" ]] && validate_proxy_token "$new_token"; then
            save_proxy_token "$new_token"
            print_success "Token proxy configurado!"
        else
            print_error "Token proxy inválido."
            exit 1
        fi
        echo
    fi
}



get_proxy_config_file() {
    local port="$1"
    echo "$PROXY_CONFIG_DIR/proxy-$port.conf"
}

get_proxy_log_file() {
    local port="${1:-}"
    echo "$PROXY_LOG_DIR/proxy.log"
}

get_proxy_service_name() {
    local port="$1"
    echo "$PROXY_SERVICE_PREFIX-$port"
}

validate_port() {
    local port="$1"
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        print_error "Porta deve ser um número!"
        return 1
    fi
    
    if [[ "$port" -lt "$MIN_PORT" || "$port" -gt "$MAX_PORT" ]]; then
        print_error "Porta deve estar entre $MIN_PORT e $MAX_PORT!"
        return 1
    fi
    
    return 0
}

check_port_available() {
    local port="$1"
    local except_port="${2:-}"

    if [[ -n "$except_port" && "$port" == "$except_port" ]]; then
        return 0
    fi

    if is_port_in_use "$port"; then
        print_error "Porta $port já está em uso!"
        return 1
    fi

    return 0
}

is_port_free() {
    local port="$1"
    ! is_port_in_use "$port"
}

confirm_action() {
    local message="$1"
    local default_answer="${2:-n}"
    local prompt_hint="(s/N)"
    [[ "$LANG_ACTIVE" == "en" ]] && prompt_hint="(y/N)"
    # Mensagens em stderr: permite uso futuro em $(...) sem engolir o prompt.
    echo -e "${YELLOW}$message $prompt_hint${RESET}" >&2
    read -rp "> " response
    response=${response:-$default_answer}
    case "${response,,}" in
        s|sim|y|yes|si|sí) return 0 ;;
        *) return 1 ;;
    esac
}

prompt_with_default() {
    local message="$1"
    local default="$2"
    local value
    # Prompt em stderr — o valor retorna em stdout para $(prompt_with_default ...).
    echo -e "${BLUE}${message} ${GRAY}[${default}]${RESET}" >&2
    read -rp "> " value
    value=${value:-$default}
    printf '%s' "$value"
}

calculate_dynamic_gomemlimit() {
    local total_ram_mb=0
    if [[ -f /proc/meminfo ]]; then
        local total_ram_kb
        total_ram_kb=$(grep -E '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')
        if [[ -n "$total_ram_kb" && "$total_ram_kb" =~ ^[0-9]+$ ]]; then
            total_ram_mb=$(( total_ram_kb / 1024 ))
        fi
    fi
    if (( total_ram_mb <= 0 )) && command -v free >/dev/null 2>&1; then
        total_ram_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    fi

    if (( total_ram_mb <= 0 )); then
        echo "620MiB"
        return 0
    fi

    if (( total_ram_mb <= 600 )); then
        echo "280MiB"
    elif (( total_ram_mb <= 1200 )); then
        echo "620MiB"
    elif (( total_ram_mb <= 2200 )); then
        echo "1400MiB"
    elif (( total_ram_mb <= 4500 )); then
        echo "2800MiB"
    else
        local calculated=$(( total_ram_mb * 70 / 100 ))
        echo "${calculated}MiB"
    fi
}

build_unified_proxy_command() {
    echo "${PROXY_EXECUTABLE} --config ${PROXY_CONFIG_JSON}"
}

write_unified_proxy_systemd_unit() {
    local gomemlimit
    gomemlimit=$(calculate_dynamic_gomemlimit)

    sudo mkdir -p /var/log/proxy "$PROXY_JSON_DIR" 2>/dev/null || true

    sudo tee "/etc/systemd/system/${PROXY_UNIFIED_SERVICE_NAME}.service" > /dev/null <<EOF
[Unit]
Description=${PROJECT_NAME} Unified Proxy Server
After=network.target

[Service]
Environment="GOMEMLIMIT=${gomemlimit}"
Environment="GOGC=100"
ExecStartPre=-/bin/mkdir -p /var/log/proxy
ExecStartPre=-/usr/local/bin/vt-iptables
ExecStart=${PROXY_EXECUTABLE} --config ${PROXY_CONFIG_JSON}
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

apply_unified_proxy_service() {
    local do_start="${1:-true}"
    local token active_ports

    sudo mkdir -p /var/log/proxy "$PROXY_JSON_DIR" 2>/dev/null || true
    ensure_proxy_json_config
    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy não configurado. Use Gerenciar Tokens no menu inicial."
        return 1
    fi
    json_set_field "token" "$token" "string"

    active_ports=$(json_get_active_ports)
    if [[ -z "$active_ports" ]]; then
        if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
            print_info "Nenhuma porta ativa restante. Parando serviço unificado..."
            sudo systemctl stop "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null || true
            sudo systemctl disable "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null || true
        fi
        return 0
    fi

    install_vt_iptables_script || true
    sudo /usr/local/bin/vt-iptables >/dev/null 2>&1 || true

    write_unified_proxy_systemd_unit

    sudo systemctl daemon-reload
    sudo systemctl enable "$PROXY_UNIFIED_SERVICE_NAME" > /dev/null 2>&1 || true

    if [[ "$do_start" == "true" ]]; then
        if sudo systemctl restart "$PROXY_UNIFIED_SERVICE_NAME"; then
            return 0
        fi
        return 1
    fi
    return 0
}

apply_proxy_service() {
    local port="${1:-}"
    local do_start="${2:-true}"
    apply_unified_proxy_service "$do_start"
}

migrate_legacy_services_to_unified() {
    local legacy_found=false
    local service_file port

    for service_file in /etc/systemd/system/${PROXY_SERVICE_PREFIX}-*.service; do
        [[ -f "$service_file" ]] || continue
        legacy_found=true
        port=$(basename "$service_file" .service | sed -n "s/^${PROXY_SERVICE_PREFIX}-\([0-9]\+\)$/\1/p")
        if [[ -n "$port" ]]; then
            sudo systemctl stop "${PROXY_SERVICE_PREFIX}-${port}" 2>/dev/null || true
            sudo systemctl disable "${PROXY_SERVICE_PREFIX}-${port}" 2>/dev/null || true
            sudo rm -f "$service_file"
        fi
    done

    local vt_unit="/etc/systemd/system/${PROXY_UNIFIED_SERVICE_NAME}.service"
    if [[ -f "$vt_unit" ]]; then
        if grep -qE '^ExecStart=.*--token' "$vt_unit" 2>/dev/null || ! grep -q -- '--config' "$vt_unit" 2>/dev/null; then
            legacy_found=true
        fi
    fi

    if [[ ! -f "$PROXY_JSON_FILE" && -d "/etc/proxy/conf.d" ]]; then
        if ls /etc/proxy/conf.d/proxy-*.conf >/dev/null 2>&1; then
            legacy_found=true
        fi
    fi

    if [[ "$legacy_found" == "true" ]]; then
        print_info "Migrando serviços e flags do proxy para JSON (/etc/proxyvt/config.json)..."
        migrate_flags_to_json_if_needed
        sudo systemctl daemon-reload
        apply_unified_proxy_service "true" || true
        print_success "Migração para JSON concluída com sucesso!"
    else
        ensure_proxy_json_config
    fi
}

sync_all_proxy_tokens() {
    local token="$1"
    [[ -n "$token" ]] || return 0

    ensure_proxy_json_config
    json_set_field "token" "$token" "string"
    apply_unified_proxy_service "true"
    echo "1"
}

start_proxy_for_port() {
    local port="$1"
    local ssl_enabled="${2:-false}"
    ensure_proxy_json_config
    json_add_port "$port" "$ssl_enabled"
    apply_unified_proxy_service "true"
}

show_proxy_execstart_line() {
    local port="${1:-}"
    echo
    print_info "ExecStart do serviço unificado (${PROXY_UNIFIED_SERVICE_NAME}):"
    local exec_line
    exec_line=$(systemctl cat "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        echo -e "${GRAY}$exec_line${RESET}"
    else
        print_warning "Unit systemd unificada (${PROXY_UNIFIED_SERVICE_NAME}) ainda não criada."
    fi
}

adv_submenu_performance() {
    while true; do
        print_header
        local buf max_conn idle write_t ulim
        buf=$(json_get_field "buffer_size" "32768")
        max_conn=$(json_get_field "max_connections" "0")
        idle=$(json_get_field "idle_timeout" "0")
        write_t=$(json_get_field "write_timeout" "0")
        ulim=$(json_get_field "ulimit" "65536")

        print_box_open
        print_box_heading "DESEMPENHO & TIMEOUTS" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Buffer Size (buffer_size): ${CYAN}${buf} bytes${RESET}"
        print_box_line "${WHITE}  2 • Max Conexões (max_connections): ${CYAN}${max_conn}${WHITE} (0=ilimitado)${RESET}"
        print_box_line "${WHITE}  3 • Idle Timeout (idle_timeout): ${CYAN}${idle}s${WHITE} (0=desativado)${RESET}"
        print_box_line "${WHITE}  4 • Write Timeout (write_timeout): ${CYAN}${write_t}s${WHITE} (0=desativado)${RESET}"
        print_box_line "${WHITE}  5 • Limite NOFILE (ulimit): ${CYAN}${ulim}${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-5]:${RESET} ")" opt
        case "$opt" in
            1)
                local val
                val=$(prompt_with_default "Buffer size em bytes" "$buf")
                if [[ "$val" =~ ^[0-9]+$ ]] && (( val >= 1024 )); then
                    json_set_field "buffer_size" "$val" "int"
                    print_success "Buffer size atualizado para $val."
                else
                    print_error "Valor inválido (mínimo 1024)."
                fi
                pause
                ;;
            2)
                local val
                val=$(prompt_with_default "Máximo de conexões simultâneas (0=ilimitado)" "$max_conn")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "max_connections" "$val" "int"
                    print_success "Max connections atualizado para $val."
                else
                    print_error "Valor inválido."
                fi
                pause
                ;;
            3)
                local val
                val=$(prompt_with_default "Timeout de inatividade em segundos (0=desativado)" "$idle")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "idle_timeout" "$val" "int"
                    print_success "Idle timeout atualizado para ${val}s."
                else
                    print_error "Valor inválido."
                fi
                pause
                ;;
            4)
                local val
                val=$(prompt_with_default "Timeout de escrita em segundos (0=desativado)" "$write_t")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "write_timeout" "$val" "int"
                    print_success "Write timeout atualizado para ${val}s."
                else
                    print_error "Valor inválido."
                fi
                pause
                ;;
            5)
                local val
                val=$(prompt_with_default "Limite de descritores NOFILE (ulimit)" "$ulim")
                if [[ "$val" =~ ^[0-9]+$ ]] && (( val >= 1024 )); then
                    json_set_field "ulimit" "$val" "int"
                    print_success "Ulimit atualizado para $val."
                else
                    print_error "Valor inválido."
                fi
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

adv_submenu_http_logs() {
    while true; do
        print_header
        local resp ssh_only banner log_lvl log_f
        resp=$(json_get_field "response" "VeltrixProxy")
        ssh_only=$(json_get_field "ssh_only" "false")
        banner=$(json_get_field "display_banner" "true")
        log_lvl=$(json_get_field "log_level" "info")
        log_f=$(json_get_field "log_file" "")

        print_box_open
        print_box_heading "HTTP, BANNER & LOGS" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Resposta HTTP (response): ${CYAN}${resp}${RESET}"
        print_box_line "${WHITE}  2 • Modo Somente SSH (ssh_only): ${CYAN}${ssh_only}${RESET}"
        print_box_line "${WHITE}  3 • Exibir Banner (display_banner): ${CYAN}${banner}${RESET}"
        print_box_line "${WHITE}  4 • Nível de Log (log_level): ${CYAN}${log_lvl}${RESET}"
        print_box_line "${WHITE}  5 • Arquivo de Log (log_file): ${CYAN}${log_f:-nenhum}${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-5]:${RESET} ")" opt
        case "$opt" in
            1)
                local val
                val=$(prompt_with_default "Nova resposta HTTP" "$resp")
                val=$(echo "$val" | tr -d '[:space:]')
                if [[ -n "$val" ]]; then
                    json_set_field "response" "$val" "string"
                    print_success "Resposta HTTP atualizada para '$val'."
                fi
                pause
                ;;
            2)
                if confirm_action "Habilitar modo somente SSH (ssh_only)?" "$([[ "$ssh_only" == "true" ]] && echo s || echo n)"; then
                    json_set_field "ssh_only" "true" "bool"
                else
                    json_set_field "ssh_only" "false" "bool"
                fi
                print_success "Configuração de ssh_only atualizada."
                pause
                ;;
            3)
                if confirm_action "Exibir banner informativo na inicialização?" "$([[ "$banner" == "true" ]] && echo s || echo n)"; then
                    json_set_field "display_banner" "true" "bool"
                else
                    json_set_field "display_banner" "false" "bool"
                fi
                print_success "Configuração de display_banner atualizada."
                pause
                ;;
            4)
                echo -e "${BLUE}Escolha o nível de log:${RESET}"
                echo -e "  1 - info (padrão)"
                echo -e "  2 - debug (detalhado)"
                echo -e "  3 - warn (apenas avisos)"
                echo -e "  4 - error (apenas erros)"
                read -rp "> " ll_opt
                case "$ll_opt" in
                    1) json_set_field "log_level" "info" "string" ;;
                    2) json_set_field "log_level" "debug" "string" ;;
                    3) json_set_field "log_level" "warn" "string" ;;
                    4) json_set_field "log_level" "error" "string" ;;
                    *) print_warning "Mantido nível atual." ;;
                esac
                print_success "Nível de log atualizado."
                pause
                ;;
            5)
                local val
                val=$(prompt_with_default "Caminho do arquivo de log (vazio para desligar)" "$log_f")
                json_set_field "log_file" "$val" "string"
                print_success "Arquivo de log atualizado."
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

adv_submenu_ssl() {
    while true; do
        print_header
        local cert_int cert_ext
        cert_int=$(json_get_field "cert_internal" "true")
        cert_ext=$(json_get_field "cert" "")

        print_box_open
        print_box_heading "CERTIFICADOS TLS / SSL" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Certificado Interno Cloudflare (cert_internal): ${CYAN}${cert_int}${RESET}"
        print_box_line "${WHITE}  2 • Certificado Externo .crt/.pem (cert): ${CYAN}${cert_ext:-nenhum}${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-2]:${RESET} ")" opt
        case "$opt" in
            1)
                if confirm_action "Usar certificado TLS Cloudflare embutido?" "$([[ "$cert_int" == "true" ]] && echo s || echo n)"; then
                    json_set_field "cert_internal" "true" "bool"
                    json_set_field "cert" "" "string"
                else
                    json_set_field "cert_internal" "false" "bool"
                fi
                print_success "Configuração cert_internal atualizada."
                pause
                ;;
            2)
                local val
                val=$(prompt_with_default "Caminho do certificado TLS externo (.crt / .pem)" "${cert_ext:-/etc/ssl/cert.pem}")
                if [[ -n "$val" ]]; then
                    json_set_field "cert" "$val" "string"
                    json_set_field "cert_internal" "false" "bool"
                    print_success "Certificado externo configurado para '$val'."
                fi
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

adv_submenu_ssh() {
    while true; do
        print_header
        local s_int s_port s_iport s_root s_banner s_auth
        s_int=$(json_get_field "ssh.internal" "true")
        s_port=$(json_get_field "ssh.port" "22")
        s_iport=$(json_get_field "ssh.internal_port" "0")
        s_root=$(json_get_field "ssh.allow_root" "true")
        s_banner=$(json_get_field "ssh.banner" "SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3")
        s_auth=$(json_get_field "ssh.auth" "shadow")

        print_box_open
        print_box_heading "SERVIDOR SSH NATIVO (ZERO-FORK)" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • SSH Nativo Go (ssh.internal): ${CYAN}${s_int}${WHITE} (Zero-Fork)${RESET}"
        print_box_line "${WHITE}  2 • Porta OpenSSH Externo (ssh.port): ${CYAN}${s_port}${RESET}"
        print_box_line "${WHITE}  3 • Porta TCP Direta SSH Interno (ssh.internal_port): ${CYAN}${s_iport}${WHITE} (0=apenas WS)${RESET}"
        print_box_line "${WHITE}  4 • Permitir Root (ssh.allow_root): ${CYAN}${s_root}${RESET}"
        print_box_line "${WHITE}  5 • Banner SSH (ssh.banner): ${CYAN}${s_banner:0:28}...${RESET}"
        print_box_line "${WHITE}  6 • Mecanismo Autenticação (ssh.auth): ${CYAN}${s_auth}${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-6]:${RESET} ")" opt
        case "$opt" in
            1)
                if confirm_action "Ativar servidor SSH nativo em Go (Zero-Fork)?" "$([[ "$s_int" == "true" ]] && echo s || echo n)"; then
                    json_set_field "ssh.internal" "true" "bool"
                else
                    json_set_field "ssh.internal" "false" "bool"
                fi
                print_success "Configuração ssh.internal atualizada."
                pause
                ;;
            2)
                local val
                val=$(prompt_with_default "Porta do OpenSSH externo legado" "$s_port")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "ssh.port" "$val" "int"
                    print_success "ssh.port atualizada para $val."
                fi
                pause
                ;;
            3)
                local val
                val=$(prompt_with_default "Porta TCP direta para SSH interno (0=apenas via túnel)" "$s_iport")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "ssh.internal_port" "$val" "int"
                    print_success "ssh.internal_port atualizada para $val."
                fi
                pause
                ;;
            4)
                if confirm_action "Permitir login de usuário root no SSH interno?" "$([[ "$s_root" == "true" ]] && echo s || echo n)"; then
                    json_set_field "ssh.allow_root" "true" "bool"
                else
                    json_set_field "ssh.allow_root" "false" "bool"
                fi
                print_success "ssh.allow_root atualizado."
                pause
                ;;
            5)
                local val
                val=$(prompt_with_default "Banner de versão SSH" "$s_banner")
                if [[ -n "$val" ]]; then
                    json_set_field "ssh.banner" "$val" "string"
                    print_success "Banner SSH atualizado."
                fi
                pause
                ;;
            6)
                echo -e "${BLUE}Escolha o método de autenticação SSH:${RESET}"
                echo -e "  1 - shadow (lê /etc/shadow padrão Linux)"
                echo -e "  2 - allow (permite qualquer senha)"
                read -rp "> " a_opt
                case "$a_opt" in
                    1) json_set_field "ssh.auth" "shadow" "string" ;;
                    2) json_set_field "ssh.auth" "allow" "string" ;;
                esac
                print_success "Mecanismo de autenticação SSH atualizado."
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

adv_submenu_btun() {
    while true; do
        print_header
        local b_en b_tun b_sub b_udp
        b_en=$(json_get_field "btun.enable" "true")
        b_tun=$(json_get_field "btun.tun" "btun0")
        b_sub=$(json_get_field "btun.subnet" "10.77.0.0/16")
        b_udp=$(json_get_field "btun.udp_port" "0")

        print_box_open
        print_box_heading "SERVIDOR BTUN (DT-PROTO / UDP NATIVO)" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Habilitar BTUN (btun.enable): ${CYAN}${b_en}${RESET}"
        print_box_line "${WHITE}  2 • Nome Interface TUN (btun.tun): ${CYAN}${b_tun}${RESET}"
        print_box_line "${WHITE}  3 • Sub-rede IPv4 (btun.subnet): ${CYAN}${b_sub}${RESET}"
        print_box_line "${WHITE}  4 • Porta UDP Direta (btun.udp_port): ${CYAN}${b_udp}${WHITE} (0=desativado)${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-4]:${RESET} ")" opt
        case "$opt" in
            1)
                if confirm_action "Habilitar servidor BTUN nativo via TUN?" "$([[ "$b_en" == "true" ]] && echo s || echo n)"; then
                    json_set_field "btun.enable" "true" "bool"
                else
                    json_set_field "btun.enable" "false" "bool"
                fi
                print_success "btun.enable atualizado."
                pause
                ;;
            2)
                local val
                val=$(prompt_with_default "Nome da interface TUN" "$b_tun")
                if [[ -n "$val" ]]; then
                    json_set_field "btun.tun" "$val" "string"
                    print_success "btun.tun atualizado para '$val'."
                fi
                pause
                ;;
            3)
                local val
                val=$(prompt_with_default "Sub-rede IPv4 para clientes BTUN" "$b_sub")
                if [[ -n "$val" ]]; then
                    json_set_field "btun.subnet" "$val" "string"
                    print_success "btun.subnet atualizado para '$val'."
                fi
                pause
                ;;
            4)
                local val
                val=$(prompt_with_default "Porta UDP direta (0=desativado)" "$b_udp")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "btun.udp_port" "$val" "int"
                    print_success "btun.udp_port atualizado para $val."
                fi
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

adv_submenu_limits() {
    while true; do
        print_header
        local d_lim exp_int pw_f
        d_lim=$(json_get_field "limits.default_user_limit" "0")
        exp_int=$(json_get_field "limits.expire_check_interval" "1m")
        pw_f=$(json_get_field "limits.passwd_file" "/etc/passwd")

        print_box_open
        print_box_heading "LIMITES DE CONEXÕES & EXPIRAÇÃO" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Limite Padrão por Conta: ${CYAN}${d_lim}${WHITE} (0=ilimitado)${RESET}"
        print_box_line "${WHITE}  2 • Varredura Automática de Expirados: ${CYAN}${exp_int}${WHITE} (0=desativado, ex: 1m, 5m)${RESET}"
        print_box_line "${WHITE}  3 • Arquivo de Limites / Senhas: ${CYAN}${pw_f}${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-3]:${RESET} ")" opt
        case "$opt" in
            1)
                local val
                val=$(prompt_with_default "Limite padrão de conexões simultâneas (0=ilimitado)" "$d_lim")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "limits.default_user_limit" "$val" "int"
                    print_success "default_user_limit atualizado para $val."
                fi
                pause
                ;;
            2)
                local val
                val=$(prompt_with_default "Intervalo de checagem e desconexão de expirados (ex: 1m, 5m, 0 para desativar)" "$exp_int")
                if [[ -n "$val" ]]; then
                    json_set_field "limits.expire_check_interval" "$val" "string"
                    print_success "expire_check_interval atualizado para '$val'."
                fi
                pause
                ;;
            3)
                local val
                val=$(prompt_with_default "Caminho do arquivo passwd" "$pw_f")
                if [[ -n "$val" ]]; then
                    json_set_field "limits.passwd_file" "$val" "string"
                    print_success "passwd_file atualizado para '$val'."
                fi
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

adv_submenu_connectors() {
    while true; do
        print_header
        local ovpn_p v2ray_p xp xg xi
        ovpn_p=$(json_get_field "connectors.openvpn_port" "1194")
        v2ray_p=$(json_get_field "connectors.v2ray_port" "1080")
        xp=$(json_get_field "xhttp.path" "/ssh")
        xg=$(json_get_field "xhttp.grace" "120")
        xi=$(json_get_field "xhttp.idle" "120")

        print_box_open
        print_box_heading "CONECTORES BACKENDS & XHTTP" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Porta Local OpenVPN: ${CYAN}${ovpn_p}${RESET}"
        print_box_line "${WHITE}  2 • Porta Local V2Ray/Xray: ${CYAN}${v2ray_p}${RESET}"
        print_box_line "${WHITE}  3 • Prefixo de URL XHTTP (xhttp.path): ${CYAN}${xp}${RESET}"
        print_box_line "${WHITE}  4 • Grace Period XHTTP (xhttp.grace): ${CYAN}${xg}s${RESET}"
        print_box_line "${WHITE}  5 • Idle Timeout XHTTP (xhttp.idle): ${CYAN}${xi}s${RESET}"
        print_box_divider
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        local opt
        read -rp "$(echo -e "${BLUE}Opção [0-5]:${RESET} ")" opt
        case "$opt" in
            1)
                local val
                val=$(prompt_with_default "Porta local do OpenVPN" "$ovpn_p")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "connectors.openvpn_port" "$val" "int"
                    print_success "Porta OpenVPN atualizada para $val."
                fi
                pause
                ;;
            2)
                local val
                val=$(prompt_with_default "Porta local do V2Ray / Xray" "$v2ray_p")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "connectors.v2ray_port" "$val" "int"
                    print_success "Porta V2Ray atualizada para $val."
                fi
                pause
                ;;
            3)
                local val
                val=$(prompt_with_default "Prefixo de URL para SplitHTTP" "$xp")
                if [[ -n "$val" ]]; then
                    json_set_field "xhttp.path" "$val" "string"
                    print_success "xhttp.path atualizado para '$val'."
                fi
                pause
                ;;
            4)
                local val
                val=$(prompt_with_default "Grace period em segundos" "$xg")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "xhttp.grace" "$val" "int"
                    print_success "xhttp.grace atualizado para ${val}s."
                fi
                pause
                ;;
            5)
                local val
                val=$(prompt_with_default "Idle timeout em segundos" "$xi")
                if [[ "$val" =~ ^[0-9]+$ ]]; then
                    json_set_field "xhttp.idle" "$val" "int"
                    print_success "xhttp.idle atualizado para ${val}s."
                fi
                pause
                ;;
            0) return 0 ;;
            *) print_error "Opção inválida."; pause ;;
        esac
    done
}

edit_proxy_advanced_service() {
    while true; do
        print_header
        print_box_open
        print_box_heading "OPÇÕES AVANÇADAS DO PROXY (JSON)" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Desempenho & Timeouts (Buffer, Conexões, Timeouts, Ulimit)${RESET}"
        print_box_line "${WHITE}  2 • Resposta HTTP, Banner & Logs (Response, Banner, SSH-Only)${RESET}"
        print_box_line "${WHITE}  3 • Certificados TLS / SSL (Certificado Interno / Externo)${RESET}"
        print_box_line "${WHITE}  4 • Servidor SSH Nativo Embutido (Zero-Fork, Porta Direta, Banner)${RESET}"
        print_box_line "${WHITE}  5 • Servidor BTUN / UDP DT-Proto (Interface, Subnet, Porta UDP)${RESET}"
        print_box_line "${WHITE}  6 • Limites de Conexão e Expiração (Limite por Usuário, Expirados)${RESET}"
        print_box_line "${WHITE}  7 • Conectores Backends (OpenVPN, V2Ray) & XHTTP${RESET}"
        print_box_line "${WHITE}  V • Visualizar arquivo /etc/proxyvt/config.json${RESET}"
        print_box_divider
        render_menu_option "0 • Concluir / Voltar" "red"
        print_box_close
        echo

        local choice
        read -rp "$(echo -e "${BLUE}Selecione a opção desejada [0-7/V]:${RESET} ")" choice
        case "${choice,,}" in
            1) adv_submenu_performance ;;
            2) adv_submenu_http_logs ;;
            3) adv_submenu_ssl ;;
            4) adv_submenu_ssh ;;
            5) adv_submenu_btun ;;
            6) adv_submenu_limits ;;
            7) adv_submenu_connectors ;;
            v)
                echo
                print_info "Conteúdo de /etc/proxyvt/config.json:"
                if [[ -f "$PROXY_JSON_FILE" ]]; then
                    if command -v jq >/dev/null 2>&1; then
                        jq . "$PROXY_JSON_FILE" 2>/dev/null || cat "$PROXY_JSON_FILE"
                    else
                        cat "$PROXY_JSON_FILE"
                    fi
                else
                    print_warning "Arquivo ainda não criado."
                fi
                echo
                pause
                ;;
            0)
                if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
                    if confirm_action "Deseja reiniciar o serviço proxy para aplicar eventuais alterações?" "s"; then
                        apply_unified_proxy_service "true"
                        print_success "Serviço proxy reiniciado com as novas configurações."
                        pause
                    fi
                fi
                return 0
                ;;
            *)
                print_error "Opção inválida."
                pause
                ;;
        esac
    done
}

change_proxy_http_response() {
    print_header

    local current_response
    current_response=$(json_get_field "response" "$DEFAULT_HTTP_RESPONSE")

    echo -e "${BLUE}Resposta HTTP atual do proxy: ${GREEN}$current_response${RESET}"
    local new_response
    new_response=$(prompt_with_default "Nova resposta HTTP" "$current_response")
    new_response=$(echo "$new_response" | tr -d '[:space:]')

    if [[ -z "$new_response" ]]; then
        print_error "Resposta não pode ser vazia."
        pause
        return
    fi

    json_set_field "response" "$new_response" "string"

    if apply_unified_proxy_service "true"; then
        print_success "Resposta HTTP global do proxy atualizada para '$new_response'."
    else
        print_error "Falha ao aplicar alteração de resposta HTTP."
    fi
    pause
}

change_proxy_status() {
    change_proxy_http_response
}

start_proxy_service() {
    print_header

    local port
    echo -e "${BLUE}Digite a porta para abrir:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port"; then
        pause
        return
    fi

    local ssl_enabled="false"
    local default_ssl="n"
    [[ "$port" == "443" || "$port" == "8443" ]] && default_ssl="s"

    if confirm_action "Deseja habilitar SSL nesta porta?" "$default_ssl"; then
        ssl_enabled="true"
    fi

    local token
    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy não configurado. Use Gerenciar Tokens no menu inicial."
        pause
        return
    fi

    if ! check_port_available "$port"; then
        pause
        return
    fi

    print_info "Configurando porta $port no proxy (/etc/proxyvt/config.json)..."

    ensure_proxy_json_config
    json_add_port "$port" "$ssl_enabled"

    if apply_unified_proxy_service "true"; then
        print_success "Porta $port adicionada e ativada com sucesso no proxy!"
    else
        print_error "Falha ao iniciar proxy unificado na porta $port"
    fi

    pause
}

pause_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para PARAR (mantém configuração):${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    print_info "Pausando porta $port (config preservada)..."
    json_toggle_port "$port" "false"
    apply_unified_proxy_service "true"
    print_success "Porta $port pausada. As demais portas continuam ativas."
    pause
}

remove_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para REMOVER (apaga do config.json):${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    if ! confirm_action "Remover definitivamente a porta $port?" "n"; then
        pause
        return
    fi

    print_info "Removendo porta $port do JSON..."
    json_remove_port "$port"
    apply_unified_proxy_service "true"
    print_success "Porta $port removida."
    pause
}

stop_proxy_service() {
    remove_proxy_service
}

start_configured_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta configurada. Use 'Abrir / criar nova porta'."
        pause
        return
    fi

    echo -e "${BLUE}Portas configuradas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta configurada para ativar (padrão ativa: true):${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    if [[ "$(is_proxy_port_enabled "$port")" == "true" ]] && systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
        print_warning "Porta $port já está ativa no serviço proxy."
        pause
        return
    fi

    # Por padrão ativa (true / sim)
    if ! confirm_action "Ativar porta $port no serviço proxy?" "s"; then
        print_info "Operação cancelada."
        pause
        return
    fi

    print_info "Ativando porta $port (enabled: true)..."
    json_toggle_port "$port" "true"
    if apply_unified_proxy_service "true"; then
        print_success "Porta $port ativada com sucesso no serviço proxy!"
    else
        print_error "Falha ao ativar porta $port."
    fi
    pause
}

edit_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta configurada."
        pause
        return
    fi

    echo -e "${BLUE}Portas configuradas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para editar SSL:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    local is_ssl
    is_ssl=$(is_proxy_port_ssl "$port")

    echo -e "${BLUE}Porta $port:${RESET} SSL atualmente $(if [[ "$is_ssl" == "true" ]]; then echo "${GREEN}HABILITADO${RESET}"; else echo "${GRAY}DESABILITADO${RESET}"; fi)"
    if [[ "$is_ssl" == "true" ]]; then
        if confirm_action "Deseja DESABILITAR SSL na porta $port?" "n"; then
            json_set_port_ssl "$port" "false"
            apply_unified_proxy_service "true"
            print_success "SSL desabilitado na porta $port."
        fi
    else
        if confirm_action "Deseja HABILITAR SSL na porta $port?" "s"; then
            json_set_port_ssl "$port" "true"
            apply_unified_proxy_service "true"
            print_success "SSL habilitado na porta $port."
        fi
    fi
    pause
}

show_proxy_port_details() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)

    print_box_open
    print_box_heading "DETALHES DO SERVIÇO PROXY" "$CYAN"
    print_box_divider

    local service_active=false
    if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
        service_active=true
    fi

    if [[ "$service_active" == "true" ]]; then
        print_box_line "${WHITE}  Status do Serviço (${PROXY_UNIFIED_SERVICE_NAME}): ${GREEN}ATIVO${RESET}"
    else
        print_box_line "${WHITE}  Status do Serviço (${PROXY_UNIFIED_SERVICE_NAME}): ${RED}PARADO${RESET}"
    fi

    local token
    token=$(load_proxy_token)
    if [[ -n "$token" ]]; then
        print_box_line "${WHITE}  Token de Licença: ${GREEN}OK${WHITE} (${CYAN}${token:0:8}...${WHITE})${RESET}"
    else
        print_box_line "${WHITE}  Token de Licença: ${RED}NÃO CONFIGURADO${RESET}"
    fi

    print_box_divider
    print_box_line "${WHITE}  --- PORTAS CONFIGURADAS (JSON) ---${RESET}"

    if [[ -z "$configured_ports" ]]; then
        print_box_line "${YELLOW}  Nenhuma porta configurada.${RESET}"
    else
        IFS=',' read -ra port_array <<< "$configured_ports"
        for port in "${port_array[@]}"; do
            [[ -z "$port" ]] && continue
            local is_ssl is_active status_str mode_str
            is_ssl=$(is_proxy_port_ssl "$port")
            is_active=$(is_proxy_port_enabled "$port")

            if [[ "$is_active" == "true" ]]; then
                status_str="${GREEN}Ativa${RESET}"
            else
                status_str="${RED}Pausada${RESET}"
            fi

            if [[ "$is_ssl" == "true" ]]; then
                local cert_int
                cert_int=$(json_get_field "cert_internal" "true")
                if [[ "$cert_int" == "true" ]]; then
                    mode_str="${CYAN}SSL (Cloudflare Interno)${RESET}"
                else
                    local cert_p
                    cert_p=$(json_get_field "cert" "externo")
                    mode_str="${CYAN}SSL (${cert_p})${RESET}"
                fi
            else
                mode_str="${WHITE}HTTP${RESET}"
            fi

            print_box_line "${WHITE}  • Porta ${CYAN}${port}${WHITE}: ${mode_str} | Status: ${status_str}${RESET}"
        done
    fi

    print_box_divider
    print_box_line "${WHITE}  --- PARÂMETROS DO CONFIG.JSON ---${RESET}"
    local buffer_val http_val max_conn write_t idle_t ssh_int btun_en
    buffer_val=$(json_get_field "buffer_size" "32768")
    http_val=$(json_get_field "response" "VeltrixProxy")
    max_conn=$(json_get_field "max_connections" "0")
    write_t=$(json_get_field "write_timeout" "0")
    idle_t=$(json_get_field "idle_timeout" "0")
    ssh_int=$(json_get_field "ssh.internal" "true")
    btun_en=$(json_get_field "btun.enable" "true")

    print_box_line "${WHITE}  Resposta HTTP: ${CYAN}${http_val}${RESET}"
    print_box_line "${WHITE}  Buffer size: ${CYAN}${buffer_val} bytes${RESET}"
    print_box_line "${WHITE}  Max conexões: ${CYAN}${max_conn}${RESET}"
    print_box_line "${WHITE}  Timeouts W/I: ${CYAN}${write_t}s / ${idle_t}s${RESET}"
    print_box_line "${WHITE}  SSH Nativo (Zero-Fork): ${CYAN}${ssh_int}${RESET}"
    print_box_line "${WHITE}  BTUN Nativo: ${CYAN}${btun_en}${RESET}"
    print_box_line "${WHITE}  Arquivo config: ${CYAN}${PROXY_JSON_FILE}${RESET}"

    print_box_divider
    local exec_line
    exec_line=$(systemctl cat "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        print_box_line "${WHITE}  ExecStart (${PROXY_UNIFIED_SERVICE_NAME}):${RESET}"
        echo -e "${GRAY}$exec_line${RESET}"
    else
        print_box_line "${YELLOW}  Unit systemd (${PROXY_UNIFIED_SERVICE_NAME}) ainda não criada${RESET}"
    fi

    print_box_close
    pause
}

restart_proxy_service() {
    print_header

    print_info "Reiniciando servico proxy (${PROXY_UNIFIED_SERVICE_NAME})..."

    if apply_unified_proxy_service "true"; then
        print_success "Servico proxy reiniciado com sucesso!"
        show_proxy_execstart_line
    else
        print_error "Falha ao reiniciar servico proxy"
    fi

    pause
}

toggle_unified_proxy_service() {
    print_header

    if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
        print_warning "O servico proxy ($PROXY_UNIFIED_SERVICE_NAME) esta ATIVO."
        if confirm_action "Deseja PARAR o servico proxy?" "n"; then
            print_info "Parando servico proxy..."
            sudo systemctl stop "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null || true
            print_success "Servico proxy parado."
        fi
    else
        print_info "O servico proxy ($PROXY_UNIFIED_SERVICE_NAME) esta PARADO."
        if confirm_action "Deseja INICIAR o servico proxy?" "s"; then
            print_info "Iniciando servico proxy..."
            if apply_unified_proxy_service "true"; then
                print_success "Servico proxy iniciado com sucesso!"
                show_proxy_execstart_line
            else
                print_error "Falha ao iniciar servico proxy."
            fi
        fi
    fi
    pause
}


show_proxy_logs() {
    local log_file="$PROXY_LOG_DIR/proxy.log"
    local key=""

    tput civis 2>/dev/null || printf '\033[?25l'
    clear

    # Captura Ctrl+C (SIGINT) para retornar ao menu sem encerrar o script vt
    trap 'tput cnorm 2>/dev/null || printf "\033[?25h"; trap - INT; return 0' INT

    while true; do
        printf '\033[H'

        refresh_menu_layout
        print_box_open
        print_box_heading "MONITOR & LOGS EM TEMPO REAL" "$CYAN"
        print_box_close
        echo -e "${GRAY}Pressione qualquer tecla ou Ctrl+C para retornar ao menu...${RESET}"
        echo

        if [[ -f "$log_file" ]]; then
            cat "$log_file" 2>/dev/null || true
        else
            sudo journalctl -u "$PROXY_UNIFIED_SERVICE_NAME" -n 30 --no-pager 2>/dev/null || print_warning "Sem logs disponiveis."
        fi

        printf '\033[J'

        if read -t 0.5 -n 1 key 2>/dev/null; then
            break
        fi
    done

    trap - INT
    tput cnorm 2>/dev/null || printf '\033[?25h'
}

connection_menu() {
    init_proxy_dirs
    prompt_for_proxy_token_if_missing
    
    while true; do
        print_header
        
        local ports_status
        ports_status=$(format_proxy_ports_status)
        
        print_box_open
        print_box_heading "$(t proxy_menu_title "$PROJECT_NAME")" "$CYAN"
        print_box_line "${WHITE}  $(t proxy_menu_ports "$ports_status")${RESET}"
        print_box_divider
        
        local menu_items=(
            "1 — $(t proxy_opt_open)"
            "2 — $(t proxy_opt_start)"
            "3 — $(t proxy_opt_stop)"
            "4 — $(t proxy_opt_edit)"
            "5 — $(t proxy_opt_remove)"
            "6 — $(t proxy_opt_restart)"
            "7 — $(t proxy_opt_adv)"
            "8 — $(t proxy_opt_http)"
            "9 — $(t proxy_opt_details)"
            "L — $(t proxy_opt_logs)"
            "0 — $(t proxy_opt_back)"
        )
        
        for item in "${menu_items[@]}"; do
            if [[ $item == *"$(t proxy_opt_back)"* || $item == *"$(t proxy_opt_remove)"* || $item == *"Voltar"* || $item == *"Remover"* || $item == *"Back"* || $item == *"Remove"* || $item == *"Volver"* || $item == *"Eliminar"* ]]; then
                render_menu_option "$item" "red"
            else
                render_menu_option "$item"
            fi
        done
        
        print_box_close
        echo
        
        local choice
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-9/L"):${RESET} ")" choice
        
        case "${choice,,}" in
            1) start_proxy_service ;;
            2) start_configured_proxy_service ;;
            3) pause_proxy_service ;;
            4) edit_proxy_service ;;
            5) remove_proxy_service ;;
            6) restart_proxy_service ;;
            7) edit_proxy_advanced_service ;;
            8) change_proxy_http_response ;;
            9) show_proxy_port_details ;;
            l|10) show_proxy_logs ;;
            0) return 0 ;;
            *) 
                print_error "$(t invalid_option "$choice")"
                pause 
                ;;
        esac
    done
}

check_token_on_startup() {
    if [[ -z "$(load_proxy_token)" ]]; then
        print_warning "Token proxy (licença) não encontrado!"
        print_info "Obrigatório para o proxy. Configure em: Menu inicial → Gerenciar Tokens [3]"
        echo
    fi
}

run_quick_setup_first_time() {
    if [[ -n "$(load_proxy_token)" ]]; then
        if [[ ! -f "$QUICK_SETUP_MARKER" ]]; then
            sudo mkdir -p "$(dirname "$QUICK_SETUP_MARKER")"
            sudo touch "$QUICK_SETUP_MARKER"
        fi
        return 0
    fi

    if [[ -f "$QUICK_SETUP_MARKER" ]] || [[ -f "$QUICK_SETUP_ASKED_MARKER" ]]; then
        return 0
    fi

    print_header
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${CYAN}                  PRIMEIRA EXECUÇÃO DETECTADA                 ${BLUE}║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BLUE}║${WHITE}  Deseja executar a instalação rápida agora?                  ${BLUE}║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! confirm_action "Executar instalação rápida na primeira execução?" "s"; then
        sudo mkdir -p "$(dirname "$QUICK_SETUP_ASKED_MARKER")"
        sudo touch "$QUICK_SETUP_ASKED_MARKER"
        sudo touch "$QUICK_SETUP_MARKER"
        print_info "Instalação rápida pulada. Indo para o menu inicial..."
        return 0
    fi

    print_header
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${CYAN}                  INSTALAÇÃO RÁPIDA INICIAL                   ${BLUE}║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BLUE}║${WHITE}  Configura proxy nas portas 80 e 443 automaticamente.        ${BLUE}║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    prompt_for_proxy_token_if_missing

    local required_ports=(80 443)
    local all_ports_free="true"

    print_warning "Antes de continuar, as portas abaixo precisam estar livres:"
    echo -e "${WHITE}  • ${CYAN}80${WHITE}   -> ${PROJECT_NAME}${RESET}"
    echo -e "${WHITE}  • ${CYAN}443${WHITE}  -> ${PROJECT_NAME} SSL${RESET}"
    echo -e "${BLUE}Status das portas:${RESET}"
    for port in "${required_ports[@]}"; do
        if is_port_free "$port"; then
            echo -e "${WHITE}  • Porta ${CYAN}$port${WHITE}: ${GREEN}LIVRE${RESET}"
        else
            echo -e "${WHITE}  • Porta ${CYAN}$port${WHITE}: ${RED}OCUPADA${RESET}"
            all_ports_free="false"
        fi
    done
    echo

    if [[ "$all_ports_free" != "true" ]]; then
        print_error "Existem portas ocupadas. Libere todas e execute novamente."
        pause
        return 1
    fi

    if ! confirm_action "Tem certeza que deseja continuar com a instalação rápida automática?" "s"; then
        print_info "Instalação rápida cancelada."
        pause
        return 1
    fi

    for port in "${required_ports[@]}"; do
        if ! is_port_free "$port"; then
            print_error "Porta $port ficou ocupada antes da instalação. Tente novamente."
            pause
        return 1
    fi
    done

    init_proxy_dirs
    print_info "Configurando proxy unificado automático: 80 (sem SSL) e 443 (com SSL)..."

    ensure_proxy_json_config
    json_add_port "80" "false"
    json_add_port "443" "true"

    if apply_unified_proxy_service "true"; then
        print_success "Proxy unificado ativo nas portas 80 (sem SSL) e 443 (com SSL)."
    else
        print_warning "Falha ao ativar proxy unificado."
    fi

    sudo mkdir -p "$(dirname "$QUICK_SETUP_ASKED_MARKER")"
    sudo touch "$QUICK_SETUP_ASKED_MARKER"
    sudo touch "$QUICK_SETUP_MARKER"
    print_success "Instalação rápida inicial concluída!"
    pause
}


is_udpgw_installed() {
    [[ -x "$UDPGW_BIN" ]]
}

detect_udpgw_release_arch() {
    case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    armv7l) echo "armv7" ;;
    i386 | i686) echo "386" ;;
    *) echo "amd64" ;;
    esac
}

get_installed_udpgw_version_label() {
    local ver=""
    if [[ -x "$UDPGW_BIN" ]]; then
        ver=$("$UDPGW_BIN" -version 2>/dev/null | tr -d 'v\r\n' || true)
    fi
    if [[ -z "$ver" && -f "$UDPGW_VERSION_FILE" ]]; then
        ver=$(tr -d '\r\n' <"$UDPGW_VERSION_FILE")
    fi
    echo "${ver:-desconhecida}"
}

fetch_latest_udpgw_release_tag() {
    local json tag redirect_loc

    # 1. API oficial
    json=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 4 --max-time 8 \
        -H "Cache-Control: no-cache" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${UDPGW_REPO}/releases/latest" 2>/dev/null || true)
    tag=$(echo "$json" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')
    if [[ -n "$tag" ]]; then
        echo "$tag"
        return 0
    fi

    # 2. Fallback: redirect 302 da URL web (imune a rate limit)
    redirect_loc=$(curl -sI -A "$DEFAULT_USER_AGENT" --connect-timeout 5 --max-time 10 \
        "https://github.com/${UDPGW_REPO}/releases/latest" 2>/dev/null | grep -i '^location:' | tr -d '\r\n' || true)
    tag=$(echo "$redirect_loc" | sed -E 's/.*\/tag\/([^\/\r\n]+).*/\1/' || true)
    if [[ -n "$tag" ]]; then
        echo "$tag"
        return 0
    fi

    # 3. Fallback: feed Atom
    tag=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 5 --max-time 10 \
        "https://github.com/${UDPGW_REPO}/releases.atom" 2>/dev/null \
        | grep -oE '/releases/tag/[^"'\''<> ]+' | head -n1 | sed 's|/releases/tag/||' || true)
    [[ -n "$tag" ]] && echo "$tag"
}

download_udpgw_binary() {
    local tag="${1:-}"
    local arch filename url tmp http_status sums_url expected actual mirror_url mirrors

    if [[ -z "$tag" ]]; then
        tag=$(fetch_latest_udpgw_release_tag || true)
    fi
    if [[ -z "$tag" ]]; then
        print_error "Não foi possível resolver a versão do UDP Gateway."
        return 1
    fi

    [[ "$tag" == v* ]] || tag="v${tag}"

    arch=$(detect_udpgw_release_arch)
    filename="udpgw-linux-${arch}"
    url="https://github.com/${UDPGW_REPO}/releases/download/${tag}/${filename}"

    tmp=$(mktemp)
    print_info "Baixando ${filename} (${tag})..."
    print_info "URL: ${url}"

    # Tentativa 1: Download direto com User-Agent
    http_status=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --retry 2 --retry-delay 1 --connect-timeout 10 -w "%{http_code}" -o "$tmp" "$url" 2>/dev/null || true)

    # Tentativa 2: Forçar IPv4 se falhou ou retornou 403
    if [[ "$http_status" != "200" || ! -s "$tmp" ]]; then
        rm -f "$tmp" 2>/dev/null || true
        http_status=$(curl -4 -fsSL -A "$DEFAULT_USER_AGENT" --retry 2 --retry-delay 1 --connect-timeout 10 -w "%{http_code}" -o "$tmp" "$url" 2>/dev/null || true)
    fi

    # Tentativa 3: Mirrors de alta disponibilidade caso GitHub retorne 403 / bloqueio de IP
    if [[ "$http_status" != "200" || ! -s "$tmp" ]]; then
        print_warning "Download direto retornou HTTP ${http_status:-000} (possível bloqueio 403). Tentando mirror de alta disponibilidade..."
        rm -f "$tmp" 2>/dev/null || true
        mirrors=(
            "https://ghfast.top/${url}"
            "https://ghproxy.net/${url}"
            "https://mirror.ghproxy.com/${url}"
        )
        for mirror_url in "${mirrors[@]}"; do
            http_status=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 12 --max-time 60 -w "%{http_code}" -o "$tmp" "$mirror_url" 2>/dev/null || true)
            if [[ "$http_status" == "200" && -s "$tmp" ]]; then
                print_success "Download do udpgw concluído via mirror de contingência."
                break
            fi
            rm -f "$tmp" 2>/dev/null || true
        done
    fi

    if [[ "$http_status" != "200" || ! -s "$tmp" ]]; then
        rm -f "$tmp"
        print_error "Falha ao baixar ${filename} (HTTP ${http_status:-000})."
        print_info "Release: https://github.com/${UDPGW_REPO}/releases/tag/${tag}"
        return 1
    fi

    sums_url="https://github.com/${UDPGW_REPO}/releases/download/${tag}/SHA256SUMS"
    http_status=$(curl -fsSL -A "$DEFAULT_USER_AGENT" -w "%{http_code}" -o "${tmp}.sums" "$sums_url" 2>/dev/null || true)
    if [[ "$http_status" != "200" || ! -s "${tmp}.sums" ]]; then
        http_status=$(curl -fsSL -A "$DEFAULT_USER_AGENT" -w "%{http_code}" -o "${tmp}.sums" "https://ghfast.top/${sums_url}" 2>/dev/null || true)
    fi

    if [[ "$http_status" == "200" && -s "${tmp}.sums" ]]; then
        expected=$(grep -E "[[:space:]]${filename}$" "${tmp}.sums" | awk '{print $1}' | head -n1)
        if [[ -n "$expected" ]]; then
            actual=$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')
            if [[ -z "$actual" ]]; then
                actual=$(shasum -a 256 "$tmp" 2>/dev/null | awk '{print $1}')
            fi
            if [[ -n "$actual" && "$actual" != "$expected" ]]; then
                rm -f "$tmp" "${tmp}.sums"
                print_error "Checksum SHA256 inválido para ${filename}."
                return 1
            fi
            print_success "Integridade SHA256 verificada."
        fi
    fi
    rm -f "${tmp}.sums"

    sudo install -m 755 "$tmp" "$UDPGW_BIN"
    rm -f "$tmp"
    echo "${tag#v}" | sudo tee "$UDPGW_VERSION_FILE" >/dev/null
    print_success "Binário udpgw instalado: ${UDPGW_BIN} (${tag})"
    return 0
}

parse_udpgw_metric() {
    local name="$1"
    local body="$2"
    local value

    value=$(printf '%s\n' "$body" | awk -v n="$name" '$1 == n { print $2; exit }')
    [[ -n "$value" ]] || value="-"
    printf '%s' "$value"
}

format_udpgw_metric_line() {
    local label="$1"
    local value="$2"
    local warn="${3:-false}"
    local value_color="$CYAN"

    if [[ "$warn" == "true" && "$value" != "0" && "$value" != "0.0" && "$value" != "-" ]]; then
        value_color="$YELLOW"
    fi

    print_box_line "${WHITE}  ${label}: ${value_color}${value}${RESET}"
}

udpgw_metrics_value_color() {
    local value="$1"
    local warn="${2:-false}"
    if [[ "$warn" == "true" && "$value" != "0" && "$value" != "0.0" && "$value" != "-" ]]; then
        printf '%s' "$YELLOW"
    else
        printf '%s' "$CYAN"
    fi
}

udpgw_metrics_cursor_hide() {
    [[ -t 1 ]] || return 0
    command -v tput >/dev/null 2>&1 && tput civis 2>/dev/null || printf '\033[?25l'
}

udpgw_metrics_cursor_show() {
    [[ -t 1 ]] || return 0
    command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null || printf '\033[?25h'
}

udpgw_metrics_cursor_up() {
    local n="$1"
    [[ -t 1 && "$n" -gt 0 ]] || return 0
    command -v tput >/dev/null 2>&1 && tput cuu "$n" 2>/dev/null || printf '\033[%dA' "$n"
}

udpgw_metrics_dyn_line() {
    print_box_line "$1"
    UDPGW_METRICS_DYN_LINES=$((UDPGW_METRICS_DYN_LINES + 1))
}

udpgw_metrics_dyn_kv() {
    local label="$1"
    local value="$2"
    local warn="${3:-false}"
    local value_color
    value_color=$(udpgw_metrics_value_color "$value" "$warn")
    udpgw_metrics_dyn_line "$(printf "${WHITE}  %-22s${RESET} ${value_color}%s${RESET}" "${label}:" "$value")"
}

udpgw_metrics_render_live_block() {
    local port="$1"
    local svc_active="$2"
    local metrics_ok="$3"
    local body="$4"

    UDPGW_METRICS_DYN_LINES=0

    if [[ "$svc_active" == "true" && "$metrics_ok" == "true" ]]; then
        udpgw_metrics_dyn_line "${WHITE}  Servico:${RESET}             $(mark_online)  ${GRAY}systemd + metrics OK${RESET}"
    elif [[ "$svc_active" == "true" ]]; then
        udpgw_metrics_dyn_line "${WHITE}  Servico:${RESET}             $(mark_online)  ${YELLOW}metricas indisponiveis${RESET}"
    elif [[ "$metrics_ok" == "true" ]]; then
        udpgw_metrics_dyn_line "${WHITE}  Servico:${RESET}             $(mark_offline) ${YELLOW}metricas respondendo${RESET}"
    else
        udpgw_metrics_dyn_line "${WHITE}  Servico:${RESET}             $(mark_offline)"
    fi

    udpgw_metrics_dyn_line "${GRAY}  Atualizado:${RESET}           ${WHITE}$(date +%H:%M:%S)${RESET}"
    print_box_divider
    UDPGW_METRICS_DYN_LINES=$((UDPGW_METRICS_DYN_LINES + 1))

    if [[ "$metrics_ok" != "true" ]]; then
        udpgw_metrics_dyn_kv "Clientes ativos" "-"
        udpgw_metrics_dyn_kv "Total aceitos" "-"
        udpgw_metrics_dyn_kv "Rejeitados" "-"
        udpgw_metrics_dyn_kv "Respostas descartadas" "-"
        udpgw_metrics_dyn_kv "Tamanho do mapa" "-"
        udpgw_metrics_dyn_kv "Panics" "-"
        udpgw_metrics_dyn_kv "Erros TCP" "-"
        udpgw_metrics_dyn_kv "Erros UDP" "-"
    else
        local active total rejected dropped mapping panics read_err udp_err
        active=$(parse_udpgw_metric "udpgw_active_clients" "$body")
        total=$(parse_udpgw_metric "udpgw_clients_total" "$body")
        rejected=$(parse_udpgw_metric "udpgw_clients_rejected_total" "$body")
        dropped=$(parse_udpgw_metric "udpgw_dropped_replies_total" "$body")
        mapping=$(parse_udpgw_metric "udpgw_mapping_size" "$body")
        panics=$(parse_udpgw_metric "udpgw_panics_total" "$body")
        read_err=$(parse_udpgw_metric "udpgw_read_errors_total" "$body")
        udp_err=$(parse_udpgw_metric "udpgw_udp_write_errors_total" "$body")
        udpgw_metrics_dyn_kv "Clientes ativos" "$active" "false"
        udpgw_metrics_dyn_kv "Total aceitos" "$total" "false"
        udpgw_metrics_dyn_kv "Rejeitados" "$rejected" "true"
        udpgw_metrics_dyn_kv "Respostas descartadas" "$dropped" "true"
        udpgw_metrics_dyn_kv "Tamanho do mapa" "$mapping" "false"
        udpgw_metrics_dyn_kv "Panics" "$panics" "true"
        udpgw_metrics_dyn_kv "Erros TCP" "$read_err" "true"
        udpgw_metrics_dyn_kv "Erros UDP" "$udp_err" "true"
    fi

    print_box_close
    UDPGW_METRICS_DYN_LINES=$((UDPGW_METRICS_DYN_LINES + 1))

    printf '\033[2K\r'
    echo -e "${GRAY}  Live refresh 2s | Enter para voltar${RESET}"
    UDPGW_METRICS_DYN_LINES=$((UDPGW_METRICS_DYN_LINES + 1))
}

UDPGW_ADV_PORT=""
UDPGW_MIGRATION_CHECKED=""

ensure_udpgw_dirs() {
    if ! mkdir -p /etc/udpgw "$UDPGW_CONFIG_DIR" 2>/dev/null; then
        if command -v sudo >/dev/null 2>&1; then
            sudo mkdir -p /etc/udpgw "$UDPGW_CONFIG_DIR" || return 1
        else
            print_error "Não foi possível criar ${UDPGW_CONFIG_DIR}"
            return 1
        fi
    fi
    return 0
}

ensure_udpgw_dirs_quiet() {
    [[ -d /etc/udpgw && -d "$UDPGW_CONFIG_DIR" ]] && return 0
    ensure_udpgw_dirs
}

get_udpgw_config_file() {
    local port="$1"
    echo "${UDPGW_CONFIG_DIR}/udpgw-${port}.conf"
}

get_udpgw_service_name() {
    local port="$1"
    echo "${UDPGW_SERVICE_PREFIX}-${port}"
}

get_udpgw_conf_value() {
    local port="$1"
    local key="$2"
    local default="${3:-}"
    local file val

    file=$(get_udpgw_config_file "$port")
    if [[ -f "$file" ]]; then
        val=$(grep -E "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d= -f2-)
        if [[ -n "$val" ]]; then
            printf '%s' "$val"
            return 0
        fi
    fi
    printf '%s' "$default"
}

set_udpgw_conf_key() {
    local port="$1"
    local key="$2"
    local value="$3"
    local file temp_file

    ensure_udpgw_dirs
    file=$(get_udpgw_config_file "$port")
    temp_file=$(mktemp)
    if [[ -f "$file" ]]; then
        grep -v "^${key}=" "$file" >"$temp_file" || true
    fi
    echo "${key}=${value}" >>"$temp_file"
    sudo mv "$temp_file" "$file"
    sudo chmod 644 "$file" 2>/dev/null || true
}

udpgw_metrics_port_from_listen() {
    local listen="$1"
    if [[ "$listen" =~ :([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

suggest_udpgw_metrics_listen() {
    local except_port="${1:-}"
    local try_p="$UDPGW_METRICS_BASE"
    local reserved=() f port listen mport

    for f in "$UDPGW_CONFIG_DIR"/udpgw-*.conf; do
        [[ -f "$f" ]] || continue
        port=$(basename "$f" .conf | sed -n 's/^udpgw-\([0-9]\+\)$/\1/p')
        [[ -z "$port" || "$port" == "$except_port" ]] && continue
        listen=$(grep '^METRICS_LISTEN=' "$f" 2>/dev/null | head -n1 | cut -d= -f2-)
        mport=$(udpgw_metrics_port_from_listen "${listen:-127.0.0.1:9091}")
        [[ -n "$mport" ]] && reserved+=("$mport")
    done

    while true; do
        local taken="false"
        for mport in "${reserved[@]}"; do
            [[ "$mport" == "$try_p" ]] && taken="true" && break
        done
        if [[ "$taken" == true ]] || is_port_in_use "$try_p"; then
            try_p=$((try_p + 1))
            continue
        fi
        break
    done
    echo "127.0.0.1:${try_p}"
}

udpgw_fix_all_metrics_collisions() {
    local ports=() port listen mport try_p
    local -a used=()
    local -a changed=()

    while IFS= read -r port; do
        [[ -n "$port" ]] && ports+=("$port")
    done < <(list_configured_udpgw_ports | tr ',' '\n' | sort -n)

    for port in "${ports[@]}"; do
        listen=$(get_udpgw_conf_value "$port" "METRICS_LISTEN" "")
        [[ -z "$listen" ]] && listen="127.0.0.1:9091"
        mport=$(udpgw_metrics_port_from_listen "$listen")
        [[ -z "$mport" ]] && mport="$UDPGW_METRICS_BASE"

        local collision="false"
        for u in "${used[@]}"; do
            [[ "$u" == "$mport" ]] && collision="true" && break
        done

        if [[ "$collision" == true ]]; then
            try_p="$UDPGW_METRICS_BASE"
            while [[ " ${used[*]} " == *" $try_p "* ]]; do
                try_p=$((try_p + 1))
            done
            listen="127.0.0.1:${try_p}"
            set_udpgw_conf_key "$port" "METRICS_LISTEN" "$listen"
            mport=$try_p
            changed+=("$port")
        fi
        used+=("$mport")
    done

    for port in "${changed[@]}"; do
        local was="false"
        is_udpgw_port_active "$port" && was="true"
        apply_udpgw_service "$port" "$was" || true
    done
}

udpgw_metrics_conflict_with() {
    local port="$1"
    local listen mport other other_listen other_mport

    listen=$(get_udpgw_conf_value "$port" "METRICS_LISTEN" "")
    [[ -z "$listen" ]] && listen="127.0.0.1:9091"
    mport=$(udpgw_metrics_port_from_listen "$listen")

    for other in $(list_configured_udpgw_ports | tr ',' ' '); do
        [[ -z "$other" || "$other" == "$port" ]] && continue
        other_listen=$(get_udpgw_conf_value "$other" "METRICS_LISTEN" "")
        [[ -z "$other_listen" ]] && other_listen="127.0.0.1:9091"
        other_mport=$(udpgw_metrics_port_from_listen "$other_listen")
        if [[ -n "$mport" && "$mport" == "$other_mport" ]]; then
            echo "$other"
            return 0
        fi
    done
    return 1
}

write_udpgw_conf_new() {
    local port="$1"
    local metrics_listen listen config_file

    metrics_listen=$(suggest_udpgw_metrics_listen "$port")
    listen="0.0.0.0:${port}"
    config_file=$(get_udpgw_config_file "$port")

    if ! ensure_udpgw_dirs; then
        print_error "Falha ao preparar diretório de configuração udpgw."
        return 1
    fi

    if ! tee "$config_file" >/dev/null <<EOF
PORT=${port}
LISTEN=${listen}
DEBUG=false
METRICS_LISTEN=${metrics_listen}
MAX_FRAME=
WRITE_CHAN=
UDP_BIND=
UDP_RBUF=
UDP_WBUF=
MAP_TTL=
REAP_EVERY=
IDLE_TIMEOUT=
MAX_CLIENT_CONNS=
MAX_MAP_ENTRIES=
MAX_CLIENTS=
AUTO_RESTART_INTERVAL=
AUTO_RESTART_GRACE=
EOF
    then
        print_error "Falha ao criar config: ${config_file}"
        return 1
    fi

    chmod 644 "$config_file" 2>/dev/null || true
    return 0
}

migrate_legacy_udpgw_if_needed() {
    local port=7400 listen file was_active="false" should_start="false"
    local legacy_service="/etc/systemd/system/${UDPGW_SERVICE_NAME}.service"
    local legacy_config="$UDPGW_CONFIG_FILE"
    local has_legacy_service=false has_legacy_config=false

    [[ -n "$UDPGW_MIGRATION_CHECKED" ]] && return 0
    UDPGW_MIGRATION_CHECKED=1

    if [[ -f /etc/udpgw/.legacy-migrated ]]; then
        return 0
    fi

    [[ -f "$legacy_service" ]] && has_legacy_service=true
    [[ -f "$legacy_config" ]] && has_legacy_config=true
    [[ "$has_legacy_service" != true && "$has_legacy_config" != true ]] && return 0

    ensure_udpgw_dirs

    if systemctl is-active --quiet "$UDPGW_SERVICE_NAME" 2>/dev/null; then
        was_active="true"
    elif systemctl is-enabled --quiet "$UDPGW_SERVICE_NAME" 2>/dev/null; then
        should_start="true"
    fi
    [[ "$was_active" == "true" ]] && should_start="true"
    if [[ "$has_legacy_service" == true && -f "/etc/systemd/system/$(get_udpgw_service_name "$port").service" ]]; then
        should_start="true"
    fi

    if [[ "$has_legacy_config" == true ]]; then
        listen=$(grep '^LISTEN=' "$legacy_config" 2>/dev/null | head -n1 | cut -d= -f2-)
        if [[ "$listen" =~ :([0-9]+)$ ]]; then
            port="${BASH_REMATCH[1]}"
        fi
        file=$(get_udpgw_config_file "$port")
        if [[ ! -f "$file" ]]; then
            sudo cp "$legacy_config" "$file"
            set_udpgw_conf_key "$port" "PORT" "$port"
        fi
    else
        file=$(ls "$UDPGW_CONFIG_DIR"/udpgw-*.conf 2>/dev/null | head -n1 || true)
        if [[ -n "$file" ]]; then
            port=$(basename "$file" .conf | sed -n 's/^udpgw-\([0-9]\+\)$/\1/p')
        fi
        [[ -z "$port" ]] && port="$UDPGW_DEFAULT_PORT"
    fi

    apply_udpgw_service "$port" "$should_start" || true

    if [[ "$has_legacy_service" == true ]]; then
        sudo systemctl disable "$UDPGW_SERVICE_NAME" 2>/dev/null || true
        sudo systemctl stop "$UDPGW_SERVICE_NAME" 2>/dev/null || true
        sudo rm -f "$legacy_service"
        sudo systemctl daemon-reload
    fi

    if [[ "$has_legacy_config" == true ]]; then
        sudo mv "$legacy_config" "${legacy_config}.migrated.bak" 2>/dev/null || sudo rm -f "$legacy_config"
    fi

    echo "1" | sudo tee /etc/udpgw/.legacy-migrated >/dev/null
    return 0
}

list_configured_udpgw_ports() {
    local ports=() f port service_file

    for service_file in /etc/systemd/system/${UDPGW_SERVICE_PREFIX}-*.service; do
        [[ -f "$service_file" ]] || continue
        port=$(basename "$service_file" .service | sed -n "s/^${UDPGW_SERVICE_PREFIX}-\\([0-9]\\+\\)$/\\1/p")
        [[ -n "$port" ]] && ports+=("$port")
    done

    for f in "$UDPGW_CONFIG_DIR"/udpgw-*.conf; do
        [[ -f "$f" ]] || continue
        port=$(basename "$f" .conf | sed -n 's/^udpgw-\([0-9]\+\)$/\1/p')
        [[ -n "$port" ]] && ports+=("$port")
    done

    if [[ ${#ports[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%s\n' "${ports[@]}" | sort -nu | paste -sd, - 2>/dev/null || true
}

is_udpgw_port_active() {
    local port="$1"
    systemctl is-active --quiet "$(get_udpgw_service_name "$port")" 2>/dev/null
}

is_udpgw_active() {
    local ports port
    if systemctl is-active --quiet "$UDPGW_SERVICE_NAME" 2>/dev/null; then
        return 0
    fi
    ports=$(list_configured_udpgw_ports)
    [[ -z "$ports" ]] && return 1
    IFS=',' read -ra pa <<< "$ports"
    for port in "${pa[@]}"; do
        is_udpgw_port_active "$port" && return 0
    done
    return 1
}

format_udpgw_ports_status() {
    local configured items=() port
    configured=$(list_configured_udpgw_ports)

    if [[ -z "$configured" ]]; then
        echo "nenhuma"
        return 0
    fi

    IFS=',' read -ra pa <<< "$configured"
    for port in "${pa[@]}"; do
        [[ -z "$port" ]] && continue
        if is_udpgw_port_active "$port"; then
            items+=("$port")
        else
            items+=("${port} [OFF]")
        fi
    done

    local count=${#items[@]}
    if (( count <= 4 )); then
        local IFS=,
        echo "${items[*]}" | sed 's/,/, /g'
    else
        local first_four=("${items[@]:0:4}")
        local remaining=$(( count - 4 ))
        local IFS=,
        echo "${first_four[*]}" | sed 's/,/, /g' | sed "s/$/ (+${remaining} portas)/"
    fi
}

append_udpgw_flag_if_set() {
    local -n _cmd=$1
    local flag="$2"
    local value="$3"
    [[ -n "$value" && "$value" != "0" ]] && _cmd+=" ${flag} ${value}"
}

build_udpgw_command_from_conf() {
    local port="$1"
    local listen cmd val

    listen=$(get_udpgw_conf_value "$port" "LISTEN" "0.0.0.0:${port}")
    cmd="${UDPGW_BIN} -listen ${listen}"

    if [[ "$(get_udpgw_conf_value "$port" "DEBUG" "false")" == "true" ]]; then
        cmd+=" -debug"
    fi

    val=$(get_udpgw_conf_value "$port" "METRICS_LISTEN" "")
    [[ -n "$val" ]] && cmd+=" -metrics-listen ${val}"

    append_udpgw_flag_if_set cmd "-max-frame" "$(get_udpgw_conf_value "$port" "MAX_FRAME" "")"
    append_udpgw_flag_if_set cmd "-write-chan" "$(get_udpgw_conf_value "$port" "WRITE_CHAN" "")"
    val=$(get_udpgw_conf_value "$port" "UDP_BIND" "")
    [[ -n "$val" ]] && cmd+=" -udp-bind ${val}"
    append_udpgw_flag_if_set cmd "-udp-rbuf" "$(get_udpgw_conf_value "$port" "UDP_RBUF" "")"
    append_udpgw_flag_if_set cmd "-udp-wbuf" "$(get_udpgw_conf_value "$port" "UDP_WBUF" "")"
    val=$(get_udpgw_conf_value "$port" "MAP_TTL" "")
    [[ -n "$val" ]] && cmd+=" -map-ttl ${val}"
    val=$(get_udpgw_conf_value "$port" "REAP_EVERY" "")
    [[ -n "$val" ]] && cmd+=" -reap-every ${val}"
    val=$(get_udpgw_conf_value "$port" "IDLE_TIMEOUT" "")
    [[ -n "$val" ]] && cmd+=" -idle-timeout ${val}"
    append_udpgw_flag_if_set cmd "-max-client-conns" "$(get_udpgw_conf_value "$port" "MAX_CLIENT_CONNS" "")"
    append_udpgw_flag_if_set cmd "-max-map-entries" "$(get_udpgw_conf_value "$port" "MAX_MAP_ENTRIES" "")"
    append_udpgw_flag_if_set cmd "-max-clients" "$(get_udpgw_conf_value "$port" "MAX_CLIENTS" "")"
    val=$(get_udpgw_conf_value "$port" "AUTO_RESTART_INTERVAL" "")
    [[ -n "$val" ]] && cmd+=" -auto-restart-interval ${val}"
    val=$(get_udpgw_conf_value "$port" "AUTO_RESTART_GRACE" "")
    [[ -n "$val" ]] && cmd+=" -auto-restart-grace ${val}"

    printf '%s' "$cmd"
}

apply_udpgw_service() {
    local port="$1"
    local restart="${2:-false}"
    local service_name exec_start listen

    if ! is_udpgw_installed; then
        print_error "Binário udpgw não encontrado."
        return 1
    fi

    service_name=$(get_udpgw_service_name "$port")
    listen=$(get_udpgw_conf_value "$port" "LISTEN" "0.0.0.0:${port}")
    exec_start=$(build_udpgw_command_from_conf "$port")

    sudo tee "/etc/systemd/system/${service_name}.service" >/dev/null <<EOF
[Unit]
Description=${PROJECT_NAME} UDP Gateway port ${port}
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${exec_start}
Restart=always
RestartSec=2
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    if [[ "$restart" == "true" ]]; then
        sudo systemctl enable "$service_name" >/dev/null 2>&1 || true
        sudo systemctl restart "$service_name"
    fi
    return 0
}

is_udpgw_port_configured() {
    local port="$1"
    [[ -f "$(get_udpgw_config_file "$port")" || -f "/etc/systemd/system/$(get_udpgw_service_name "$port").service" ]]
}

select_udpgw_port_interactive() {
    local _result_var="${1:?select_udpgw_port_interactive: variavel de retorno obrigatoria}"
    local prompt="${2:-Digite a porta TCP do gateway}"
    local selected configured

    configured=$(list_configured_udpgw_ports)
    if [[ -z "$configured" ]]; then
        print_error "Nenhuma porta udpgw configurada."
        return 1
    fi

    print_header
    echo -e "${BLUE}Portas: ${GREEN}$(format_udpgw_ports_status)${RESET}"
    echo -e "${BLUE}${prompt}:${RESET}"
    read -rp "> " selected
    selected=$(echo "$selected" | tr -d '[:space:]')

    if [[ -z "$selected" && "$configured" != *","* ]]; then
        selected="$configured"
    fi

    if [[ -z "$selected" ]]; then
        print_error "Informe a porta."
        return 1
    fi

    if ! validate_port "$selected"; then
        return 1
    fi

    if [[ ",${configured}," != *",${selected},"* ]]; then
        print_error "Porta ${selected} nao configurada."
        return 1
    fi

    printf -v "$_result_var" '%s' "$selected"
    return 0
}

show_udpgw_execstart_line() {
    local port="$1"
    local service_name exec_line
    service_name=$(get_udpgw_service_name "$port")
    exec_line=$(systemctl cat "$service_name" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        echo -e "${GRAY}${exec_line}${RESET}"
    else
        print_warning "Unit systemd ainda não existe para porta ${port}."
    fi
}

udpgw_conf_or_default() {
    local port="$1"
    local key="$2"
    local fallback="${3:-}"
    local val

    val=$(get_udpgw_conf_value "$port" "$key" "$fallback")
    if [[ -n "$val" ]]; then
        printf '%s' "$val"
    else
        printf '%s' "(padrao)"
    fi
}

udpgw_apply_advanced_config() {
    local port="$1"
    local was="false"

    is_udpgw_port_active "$port" && was="true"
    apply_udpgw_service "$port" "$was"
    print_success "Configuracao aplicada na porta ${port}."
    show_udpgw_execstart_line "$port"
    pause
}

udpgw_advanced_network_submenu() {
    local port="$1"
    local choice val

    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "REDE - porta ${port}" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  Listen (-listen)${RESET}          ${CYAN}$(get_udpgw_conf_value "$port" LISTEN "0.0.0.0:${port}")${RESET}"
        print_box_line "${WHITE}  Metrics (-metrics-listen)${RESET} ${CYAN}$(udpgw_conf_or_default "$port" METRICS_LISTEN)${RESET}"
        print_box_line "${WHITE}  UDP bind (-udp-bind)${RESET}      ${CYAN}$(udpgw_conf_or_default "$port" UDP_BIND)${RESET}"
        print_box_divider
        render_menu_option "1 • Alterar Listen"
        render_menu_option "2 • Alterar Metrics"
        render_menu_option "3 • Alterar UDP bind"
        render_menu_option "0 • Voltar" "red"
    print_box_close
    echo
    
        read -rp "$(echo -e "${BLUE}Selecione [0-3]:${RESET} ")" choice
        case "$choice" in
        1)
            val=$(prompt_with_default "Listen (-listen)" "$(get_udpgw_conf_value "$port" LISTEN "0.0.0.0:${port}")")
            set_udpgw_conf_key "$port" "LISTEN" "$val"
            ;;
        2)
            val=$(prompt_with_default "Metrics (-metrics-listen, vazio=padrao)" "$(get_udpgw_conf_value "$port" METRICS_LISTEN "")")
            if [[ -z "$val" && "$(list_configured_udpgw_ports)" == *","* ]]; then
                val=$(suggest_udpgw_metrics_listen "$port")
                print_info "Multi-instancia: metrics unico sugerido ${val}"
            fi
            set_udpgw_conf_key "$port" "METRICS_LISTEN" "$val"
            ;;
        3)
            val=$(prompt_with_default "UDP bind IP (-udp-bind, vazio=padrao)" "$(get_udpgw_conf_value "$port" UDP_BIND "")")
            set_udpgw_conf_key "$port" "UDP_BIND" "$val"
            ;;
        0) return 0 ;;
        *) print_error "Opcao invalida: $choice" ;;
        esac
    done
}

udpgw_advanced_perf_submenu() {
    local port="$1"
    local choice val

    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "PERFORMANCE - porta ${port}" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  Max frame (-max-frame)${RESET}    ${CYAN}$(udpgw_conf_or_default "$port" MAX_FRAME)${RESET}"
        print_box_line "${WHITE}  Write chan (-write-chan)${RESET}  ${CYAN}$(udpgw_conf_or_default "$port" WRITE_CHAN)${RESET}"
        print_box_line "${WHITE}  UDP rbuf (-udp-rbuf)${RESET}      ${CYAN}$(udpgw_conf_or_default "$port" UDP_RBUF)${RESET}"
        print_box_line "${WHITE}  UDP wbuf (-udp-wbuf)${RESET}      ${CYAN}$(udpgw_conf_or_default "$port" UDP_WBUF)${RESET}"
        print_box_divider
        render_menu_option "1 • Alterar max frame"
        render_menu_option "2 • Alterar write channel"
        render_menu_option "3 • Alterar UDP read buffer"
        render_menu_option "4 • Alterar UDP write buffer"
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        read -rp "$(echo -e "${BLUE}Selecione [0-4]:${RESET} ")" choice
        case "$choice" in
        1)
            val=$(prompt_with_default "Max frame bytes (-max-frame, vazio=padrao)" "$(get_udpgw_conf_value "$port" MAX_FRAME "")")
            set_udpgw_conf_key "$port" "MAX_FRAME" "$val"
            ;;
        2)
            val=$(prompt_with_default "Write channel (-write-chan, vazio=padrao)" "$(get_udpgw_conf_value "$port" WRITE_CHAN "")")
            set_udpgw_conf_key "$port" "WRITE_CHAN" "$val"
            ;;
        3)
            val=$(prompt_with_default "UDP read buffer (-udp-rbuf, vazio=padrao)" "$(get_udpgw_conf_value "$port" UDP_RBUF "")")
            set_udpgw_conf_key "$port" "UDP_RBUF" "$val"
            ;;
        4)
            val=$(prompt_with_default "UDP write buffer (-udp-wbuf, vazio=padrao)" "$(get_udpgw_conf_value "$port" UDP_WBUF "")")
            set_udpgw_conf_key "$port" "UDP_WBUF" "$val"
            ;;
        0) return 0 ;;
        *) print_error "Opcao invalida: $choice" ;;
        esac
    done
}

udpgw_advanced_limits_submenu() {
    local port="$1"
    local choice val

    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "LIMITES - porta ${port}" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  Max client conns${RESET}  ${CYAN}$(udpgw_conf_or_default "$port" MAX_CLIENT_CONNS)${RESET}"
        print_box_line "${WHITE}  Max map entries${RESET}   ${CYAN}$(udpgw_conf_or_default "$port" MAX_MAP_ENTRIES)${RESET}"
        print_box_line "${WHITE}  Max clients${RESET}       ${CYAN}$(udpgw_conf_or_default "$port" MAX_CLIENTS)${RESET}"
        print_box_divider
        render_menu_option "1 • Alterar max client conns"
        render_menu_option "2 • Alterar max map entries"
        render_menu_option "3 • Alterar max clients"
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        read -rp "$(echo -e "${BLUE}Selecione [0-3]:${RESET} ")" choice
        case "$choice" in
        1)
            val=$(prompt_with_default "Max client conns (-max-client-conns, vazio=padrao)" "$(get_udpgw_conf_value "$port" MAX_CLIENT_CONNS "")")
            set_udpgw_conf_key "$port" "MAX_CLIENT_CONNS" "$val"
            ;;
        2)
            val=$(prompt_with_default "Max map entries (-max-map-entries, vazio=padrao)" "$(get_udpgw_conf_value "$port" MAX_MAP_ENTRIES "")")
            set_udpgw_conf_key "$port" "MAX_MAP_ENTRIES" "$val"
            ;;
        3)
            val=$(prompt_with_default "Max clients (-max-clients, vazio=padrao)" "$(get_udpgw_conf_value "$port" MAX_CLIENTS "")")
            set_udpgw_conf_key "$port" "MAX_CLIENTS" "$val"
            ;;
        0) return 0 ;;
        *) print_error "Opcao invalida: $choice" ;;
        esac
    done
}

udpgw_advanced_timeouts_submenu() {
    local port="$1"
    local choice val

    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "TIMEOUTS - porta ${port}" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  Map TTL (-map-ttl)${RESET}                 ${CYAN}$(udpgw_conf_or_default "$port" MAP_TTL)${RESET}"
        print_box_line "${WHITE}  Reap every (-reap-every)${RESET}           ${CYAN}$(udpgw_conf_or_default "$port" REAP_EVERY)${RESET}"
        print_box_line "${WHITE}  Idle timeout (-idle-timeout)${RESET}       ${CYAN}$(udpgw_conf_or_default "$port" IDLE_TIMEOUT)${RESET}"
        print_box_line "${WHITE}  Auto-restart interval${RESET}                ${CYAN}$(udpgw_conf_or_default "$port" AUTO_RESTART_INTERVAL)${RESET}"
        print_box_line "${WHITE}  Auto-restart grace${RESET}                   ${CYAN}$(udpgw_conf_or_default "$port" AUTO_RESTART_GRACE)${RESET}"
        print_box_divider
        render_menu_option "1 • Alterar map TTL"
        render_menu_option "2 • Alterar reap every"
        render_menu_option "3 • Alterar idle timeout"
        render_menu_option "4 • Alterar auto-restart interval"
        render_menu_option "5 • Alterar auto-restart grace"
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        read -rp "$(echo -e "${BLUE}Selecione [0-5]:${RESET} ")" choice
        case "$choice" in
        1)
            val=$(prompt_with_default "Map TTL (-map-ttl, ex: 90s, vazio=padrao)" "$(get_udpgw_conf_value "$port" MAP_TTL "")")
            set_udpgw_conf_key "$port" "MAP_TTL" "$val"
            ;;
        2)
            val=$(prompt_with_default "Reap every (-reap-every, ex: 10s, vazio=padrao)" "$(get_udpgw_conf_value "$port" REAP_EVERY "")")
            set_udpgw_conf_key "$port" "REAP_EVERY" "$val"
            ;;
        3)
            val=$(prompt_with_default "Idle timeout (-idle-timeout, ex: 2m, vazio=padrao)" "$(get_udpgw_conf_value "$port" IDLE_TIMEOUT "")")
            set_udpgw_conf_key "$port" "IDLE_TIMEOUT" "$val"
            ;;
        4)
            val=$(prompt_with_default "Auto-restart interval (-auto-restart-interval, vazio=padrao)" "$(get_udpgw_conf_value "$port" AUTO_RESTART_INTERVAL "")")
            set_udpgw_conf_key "$port" "AUTO_RESTART_INTERVAL" "$val"
            ;;
        5)
            val=$(prompt_with_default "Auto-restart grace (-auto-restart-grace, vazio=padrao)" "$(get_udpgw_conf_value "$port" AUTO_RESTART_GRACE "")")
            set_udpgw_conf_key "$port" "AUTO_RESTART_GRACE" "$val"
            ;;
        0) return 0 ;;
        *) print_error "Opcao invalida: $choice" ;;
        esac
    done
}

prompt_udpgw_advanced_options() {
    local port="$1"
    local choice debug_val

    UDPGW_ADV_PORT="$port"
    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "UDPGW AVANCADO - porta ${port}" "$CYAN"
        print_box_divider
        print_box_line "${GRAY}  Resumo (vazio no config = padrao do binario)${RESET}"
        print_box_line "${WHITE}  Listen:${RESET}  ${CYAN}$(get_udpgw_conf_value "$port" LISTEN "0.0.0.0:${port}")${RESET}"
        print_box_line "${WHITE}  Metrics:${RESET} ${CYAN}$(udpgw_conf_or_default "$port" METRICS_LISTEN)${RESET}"
        debug_val=$(get_udpgw_conf_value "$port" DEBUG "false")
        print_box_line "${WHITE}  Debug:${RESET}   ${CYAN}${debug_val}${RESET}"
        print_box_divider
        render_menu_option "1 • Rede (listen, metrics, udp-bind)"
        render_menu_option "2 • Performance (frame, buffers)"
        render_menu_option "3 • Limites de clientes"
        render_menu_option "4 • Timeouts e manutencao"
        render_menu_option "5 • Alternar debug (-debug)"
        render_menu_option "6 • Ver ExecStart"
        render_menu_option "7 • Salvar e aplicar systemd"
        render_menu_option "0 • Voltar" "red"
        print_box_close
        echo

        read -rp "$(echo -e "${BLUE}Selecione [0-7]:${RESET} ")" choice
        case "$choice" in
        1) udpgw_advanced_network_submenu "$port" ;;
        2) udpgw_advanced_perf_submenu "$port" ;;
        3) udpgw_advanced_limits_submenu "$port" ;;
        4) udpgw_advanced_timeouts_submenu "$port" ;;
        5)
            if [[ "$debug_val" == "true" ]]; then
                set_udpgw_conf_key "$port" "DEBUG" "false"
                print_success "Debug desativado."
            else
                set_udpgw_conf_key "$port" "DEBUG" "true"
                print_success "Debug ativado."
            fi
            ;;
        6)
            show_udpgw_execstart_line "$port"
            pause
            ;;
        7) udpgw_apply_advanced_config "$port" ;;
        0) return 0 ;;
        *) print_error "Opcao invalida: $choice" ;;
        esac
    done
}

udpgw_create_port() {
    print_header
    if ! is_udpgw_installed; then
        print_warning "Binario nao instalado. Baixando..."
        download_udpgw_binary || { pause; return 1; }
    fi

    local port
    port=$(prompt_with_default "Porta TCP do gateway (-listen)" "$UDPGW_DEFAULT_PORT")
    validate_port "$port" || { pause; return 1; }

    local existing
    existing=$(list_configured_udpgw_ports)
    if [[ ",${existing}," == *",${port},"* ]]; then
        print_warning "Porta ${port} ja configurada."
    else
        if ! check_port_available "$port"; then
            pause
            return 1
        fi
        if ! write_udpgw_conf_new "$port"; then
            pause
            return 1
        fi
        print_success "Config criada: $(get_udpgw_config_file "$port")"
    fi

    if confirm_action "Abrir opcoes avancadas antes de iniciar?" "n"; then
        prompt_udpgw_advanced_options "$port"
    fi

    if apply_udpgw_service "$port" "true"; then
        if is_udpgw_port_active "$port"; then
            print_success "UDP Gateway ativo na porta ${port}."
        else
            print_error "Servico pode nao ter iniciado."
            print_info "Logs: journalctl -u $(get_udpgw_service_name "$port") -n 30 --no-pager"
        fi
    fi
    pause
}

udpgw_start_port() {
    local port was="false"
    select_udpgw_port_interactive port "Porta para iniciar" || { pause; return 1; }
    is_udpgw_port_active "$port" && was="true"
    apply_udpgw_service "$port" "true"
    print_success "Porta ${port} iniciada."
    pause
}

udpgw_stop_port() {
    local port sn
    select_udpgw_port_interactive port "Porta para parar" || { pause; return 1; }
    sn=$(get_udpgw_service_name "$port")
    sudo systemctl stop "$sn" 2>/dev/null || true
    print_success "Porta ${port} parada."
    pause
}

udpgw_restart_port() {
    local port sn
    select_udpgw_port_interactive port "Porta para reiniciar" || { pause; return 1; }
    sn=$(get_udpgw_service_name "$port")
    sudo systemctl restart "$sn"
    print_success "Porta ${port} reiniciada."
    pause
}

udpgw_show_port_status() {
    local port listen metrics debug
    select_udpgw_port_interactive port "Porta para status" || { pause; return 1; }
    listen=$(get_udpgw_conf_value "$port" LISTEN "0.0.0.0:${port}")
    metrics=$(get_udpgw_conf_value "$port" METRICS_LISTEN "")
    debug=$(get_udpgw_conf_value "$port" DEBUG "false")

    print_header
    print_box_open
    print_box_heading "STATUS - porta ${port}" "$CYAN"
    print_box_divider
    if is_udpgw_port_active "$port"; then
        print_box_line "${WHITE}  Status: $(mark_online)${RESET}"
    else
        print_box_line "${WHITE}  Status: $(mark_offline)${RESET}"
    fi
    print_box_line "${WHITE}  Listen: ${BLUE}${listen}${RESET}"
    print_box_line "${WHITE}  Metrics: ${BLUE}${metrics:-padrao binario}${RESET}"
    print_box_line "${WHITE}  Debug: ${BLUE}${debug}${RESET}"
    print_box_line "${WHITE}  Config: ${BLUE}$(get_udpgw_config_file "$port")${RESET}"
    print_box_close
    echo
    show_udpgw_execstart_line "$port"
    pause
}

udpgw_view_port_logs() {
    local port sn
    select_udpgw_port_interactive port "Porta para logs" || { pause; return 1; }
    sn=$(get_udpgw_service_name "$port")
    print_info "Logs ${sn} (Ctrl+C para sair)..."
    sudo journalctl -u "$sn" -f
    pause
}

udpgw_remove_port() {
    local port sn
    select_udpgw_port_interactive port "Porta para remover" || { pause; return 1; }
    if ! confirm_action "Remover porta ${port} (servico + config)?" "n"; then
        pause
        return 0
    fi
    sn=$(get_udpgw_service_name "$port")
    sudo systemctl stop "$sn" 2>/dev/null || true
    sudo systemctl disable "$sn" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/${sn}.service"
    sudo rm -f "$(get_udpgw_config_file "$port")"
    sudo systemctl daemon-reload
    print_success "Porta ${port} removida."
    pause
}

get_udpgw_metrics_base_url_for_port() {
    local port="$1"
    local listen metrics_url
    listen=$(get_udpgw_conf_value "$port" "METRICS_LISTEN" "")
    listen=${listen:-127.0.0.1:9091}
    if [[ "$listen" == *"://"* ]]; then
        metrics_url="${listen%/}"
    else
        metrics_url="http://${listen}"
    fi
    printf '%s' "$metrics_url"
}

udpgw_show_metrics_for_port() {
    local port="$1"
    local metrics_url body svc_active metrics_ok listen_tcp metrics_cfg conflict_port
    local refresh_sec=2
    local static_drawn="false"
    local live_lines=0

    if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
        print_error "Porta invalida para metricas."
        pause
        return 1
    fi

    metrics_url=$(get_udpgw_metrics_base_url_for_port "$port")
    listen_tcp=$(get_udpgw_conf_value "$port" LISTEN "0.0.0.0:${port}")
    metrics_cfg=$(get_udpgw_conf_value "$port" "METRICS_LISTEN" "")
    if [[ -z "$metrics_cfg" ]]; then
        metrics_cfg="127.0.0.1:9091 (padrao binario)"
    fi
    conflict_port=$(udpgw_metrics_conflict_with "$port" 2>/dev/null || true)

    udpgw_metrics_cursor_hide
    clear
    refresh_menu_layout

    print_box_open
    print_box_heading "METRICAS UDPGW ${port}" "$CYAN"
    print_box_divider
    print_box_line "${WHITE}  TCP listen:${RESET}  ${CYAN}${listen_tcp}${RESET}"
    print_box_line "${WHITE}  Metrics cfg:${RESET} ${CYAN}${metrics_cfg}${RESET}"
    print_box_line "${WHITE}  Endpoint:${RESET}    ${BLUE}${metrics_url}/metrics${RESET}"
    if [[ -n "$conflict_port" ]]; then
        print_box_line "${YELLOW}  AVISO: metrics compartilhada com TCP ${conflict_port}${RESET}"
    fi
    print_box_divider
    static_drawn="true"

    while true; do
        svc_active="false"
        is_udpgw_port_active "$port" && svc_active="true"

        body=$(curl -fsSL --connect-timeout 2 --max-time 5 "${metrics_url}/metrics" 2>/dev/null || true)
        metrics_ok="false"
        [[ -n "$body" ]] && metrics_ok="true"

        if [[ "$static_drawn" == "true" ]]; then
            static_drawn="false"
        elif [[ -t 1 ]]; then
            udpgw_metrics_cursor_up "$live_lines"
        else
            udpgw_metrics_cursor_up 0
            clear
            refresh_menu_layout
            print_box_open
            print_box_heading "METRICAS UDPGW ${port}" "$CYAN"
            print_box_divider
            print_box_line "${WHITE}  TCP listen:${RESET}  ${CYAN}${listen_tcp}${RESET}"
            print_box_line "${WHITE}  Metrics cfg:${RESET} ${CYAN}${metrics_cfg}${RESET}"
            print_box_line "${WHITE}  Endpoint:${RESET}    ${BLUE}${metrics_url}/metrics${RESET}"
            if [[ -n "$conflict_port" ]]; then
                print_box_line "${YELLOW}  AVISO: metrics compartilhada com TCP ${conflict_port}${RESET}"
            fi
            print_box_divider
        fi

        udpgw_metrics_render_live_block "$port" "$svc_active" "$metrics_ok" "$body"
        live_lines=$UDPGW_METRICS_DYN_LINES

        if read -r -t "$refresh_sec" -n 1 _key 2>/dev/null; then
            break
        fi
    done

    udpgw_metrics_cursor_show
    echo
}

udpgw_show_metrics_menu() {
    local port
    select_udpgw_port_interactive port "Porta para metricas" || { pause; return 1; }
    udpgw_show_metrics_for_port "$port"
}

udpgw_edit_advanced_menu() {
    local port
    select_udpgw_port_interactive port "Porta para opcoes avancadas" || { pause; return 1; }
    prompt_udpgw_advanced_options "$port"
}

udpgw_install_or_update() {
    print_header
    print_info "Instalando/atualizando binario udpgw..."
    if download_udpgw_binary; then
        local port
        for port in $(list_configured_udpgw_ports | tr ',' ' '); do
            [[ -z "$port" ]] && continue
            local was="false"
            is_udpgw_port_active "$port" && was="true"
            apply_udpgw_service "$port" "$was"
        done
    fi
        pause
}

print_udpgw_menu() {
    local ports_status
    ports_status=$(format_udpgw_ports_status)
    print_box_open
    print_box_heading "$(t udpgw_menu_title)"
    print_box_divider
    print_box_line "${WHITE}  $(t udpgw_menu_ports "$ports_status")${RESET}"
    print_box_divider
    local menu_items=(
        "1 • $(t udpgw_opt_open)"
        "2 • $(t udpgw_opt_start)"
        "3 • $(t udpgw_opt_stop)"
        "4 • $(t udpgw_opt_restart)"
        "5 • $(t udpgw_opt_status)"
        "6 • $(t udpgw_opt_metrics)"
        "7 • $(t udpgw_opt_logs)"
        "8 • $(t udpgw_opt_adv)"
        "9 • $(t udpgw_opt_install)"
        "A • $(t udpgw_opt_remove)"
        "0 • $(t udpgw_opt_back)"
    )
    for item in "${menu_items[@]}"; do
        if [[ $item == *"$(t udpgw_opt_back)"* || $item == *"$(t udpgw_opt_remove)"* || $item == *"Voltar"* || $item == *"Remover"* || $item == *"Back"* || $item == *"Remove"* || $item == *"Volver"* || $item == *"Eliminar"* ]]; then
            render_menu_option "$item" "red"
        else
            render_menu_option "$item"
        fi
    done
    print_box_close
    echo
}

udpgw_main_menu() {
    udpgw_fix_all_metrics_collisions || true
    while true; do
        print_header
        print_status
        print_udpgw_menu
        local option
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-9/A"):${RESET} ")" option
        case "$option" in
        1) udpgw_create_port ;;
        2) udpgw_start_port ;;
        3) udpgw_stop_port ;;
        4) udpgw_restart_port ;;
        5) udpgw_show_port_status ;;
        6) udpgw_show_metrics_menu ;;
        7) udpgw_view_port_logs ;;
        8) udpgw_edit_advanced_menu ;;
        9) udpgw_install_or_update ;;
        a|A) udpgw_remove_port ;;
        0) return 0 ;;
        *) print_error "$(t invalid_option "$option")"; pause ;;
        esac
    done
}
show_ssh_online_users_details() {
    print_header

    local ssh_onlines
    ssh_onlines=$(get_ssh_online_users_count)

    print_box_open
    print_box_heading "$(t ssh_menu_title "$ssh_onlines")" "$CYAN"
    print_box_close
    echo

    if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null && [[ -x "$PROXY_EXECUTABLE" ]]; then
        echo -e "${BLUE}=== Conexões ativas no motor ProxyVT ===${RESET}"
        "$PROXY_EXECUTABLE" --onlines 2>/dev/null || echo "Nenhuma conexão reportada pelo proxy-server."
        echo
    fi

    local sshd_count
    sshd_count=$(pgrep -f 'sshd:' 2>/dev/null | grep -v '^root$' | wc -l || echo 0)
    if (( sshd_count > 0 )); then
        echo -e "${BLUE}=== Sessões OpenSSH externas (sistema Linux) ===${RESET}"
        pgrep -f 'sshd:' 2>/dev/null \
            | xargs -r ps -o user=,pid=,etime= 2>/dev/null \
            | grep -v '^root ' \
            | sort -u \
            | while read -r user pid etime; do
                t ssh_user_row "$user" "$pid" "$etime"
                echo
            done
        echo
    fi

    if [[ "$ssh_onlines" == "0" && $sshd_count -eq 0 ]]; then
        echo "$(t ssh_no_users)"
    fi

    echo
    pause
}

online_users_menu() {
    while true; do
        print_header

        local ssh_onlines
        ssh_onlines=$(get_ssh_online_users_count)

        print_box_open
        print_box_heading "$(t ssh_menu_title "$ssh_onlines")" "$CYAN"
        print_box_divider
        render_menu_option "1 • $(t ssh_opt_list)"
        render_menu_option "2 • Desconectar usuário específico (--kill-user)"
        render_menu_option "3 • Desconectar todos os usuários expirados (--kill-expired)"
        render_menu_option "0 • $(t ssh_opt_back)" "red"
        print_box_close
        echo

        local option
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-3"):${RESET} ")" option
        case "$option" in
            1) show_ssh_online_users_details ;;
            2)
                echo
                echo -e "${BLUE}Digite o nome do usuário para desconectar:${RESET}"
                read -rp "> " target_user
                target_user=$(echo "$target_user" | tr -d '[:space:]')
                if [[ -n "$target_user" && -x "$PROXY_EXECUTABLE" ]]; then
                    print_info "Derrubando conexões do usuário '$target_user'..."
                    if "$PROXY_EXECUTABLE" --kill-user "$target_user" 2>/dev/null; then
                        print_success "Comando de desconexão executado para '$target_user'."
                    else
                        pkill -u "$target_user" 2>/dev/null || true
                        print_success "Processos do usuário '$target_user' finalizados via sistema."
                    fi
                else
                    print_error "Usuário inválido ou binário proxy não encontrado."
                fi
                pause
                ;;
            3)
                echo
                if [[ -x "$PROXY_EXECUTABLE" ]]; then
                    print_info "Derrubando conexões de todos os usuários expirados..."
                    if "$PROXY_EXECUTABLE" --kill-expired 2>/dev/null; then
                        print_success "Varredura e desconexão de usuários expirados concluída."
                    else
                        print_warning "Comando --kill-expired não suportado ou falhou."
                    fi
                else
                    print_error "Binário proxy não encontrado."
                fi
                pause
                ;;
            0) return 0 ;;
            *) 
                print_error "$(t invalid_option "$option")"
                pause 
                ;;
        esac
    done
}

get_installed_proxy_version_label() {
    local ver=""
    if [[ -x "$PROXY_EXECUTABLE" ]]; then
        ver=$("$PROXY_EXECUTABLE" --version 2>/dev/null | awk '{print $NF}' | tr -d 'v' || true)
    fi
    if [[ -z "$ver" && -f "$PROXY_VERSION_FILE" ]]; then
        ver=$(tr -d '\r\n' <"$PROXY_VERSION_FILE")
    fi
    echo "${ver:-desconhecida}"
}

show_update_preserve_notice() {
    echo -e "${WHITE}O que será atualizado / otimizado:${RESET}"
    echo -e "${CYAN}  • Binário proxy-server${RESET}"
    echo -e "${CYAN}  • Binário udpgw (UDP Gateway)${RESET}"
    echo -e "${CYAN}  • Menu vt (este menu)${RESET}"
    echo -e "${CYAN}  • Parâmetros de rede/TCP do Kernel & limites de descritores (sysctl + limits)${RESET}"
    echo
    echo -e "${WHITE}O que é PRESERVADO:${RESET}"
    echo -e "${GREEN}  • Token proxy (licença VT)${RESET}"
    echo -e "${GREEN}  • Units systemd e configs de portas (/etc/proxy/conf.d)${RESET}"
    echo -e "${GREEN}  • Config do udpgw (/etc/udpgw)${RESET}"
    echo
    echo -e "${YELLOW}Serviços ativos serão reiniciados após a troca dos binários.${RESET}"
}

restart_udpgw_configured_ports() {
    local port sn
    for port in $(list_configured_udpgw_ports | tr ',' ' '); do
        [[ -z "$port" ]] && continue
        sn=$(get_udpgw_service_name "$port")
        [[ -f "/etc/systemd/system/${sn}.service" ]] || continue
        sudo systemctl enable "$sn" >/dev/null 2>&1 || true
        sudo systemctl restart "$sn" 2>/dev/null || sudo systemctl start "$sn" 2>/dev/null || true
    done
    if [[ -f /etc/systemd/system/udpgw.service ]]; then
        sudo systemctl disable udpgw 2>/dev/null || true
        sudo systemctl stop udpgw 2>/dev/null || true
        sudo rm -f /etc/systemd/system/udpgw.service
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
}

run_system_update() {
    local args=(--update --yes)

    print_info "Baixando e executando instalador oficial..."
    echo -e "${GRAY}curl -fsSL ${INSTALL_URL} | bash -s -- ${args[*]}${RESET}"
    echo

    if ! curl -fsSL "${INSTALL_URL}?$(date +%s)" | bash -s -- "${args[@]}"; then
        print_error "Falha na atualização."
        print_info "Tente manualmente: curl -fsSL ${INSTALL_URL} | bash -s -- --update --yes"
        pause
        return 1
    fi

    print_success "Atualização concluída (binários + menu)."
    echo
    print_info "Proxy: v$(get_installed_proxy_version_label) | UDPgw: v$(get_installed_udpgw_version_label)"

    restart_udpgw_configured_ports || true
    rm -f "$UPDATE_CACHE_FILE" 2>/dev/null || true

    if [[ -x "$MENU_BIN" ]]; then
        echo
        print_warning "Recarregando o novo menu vt..."
        pause
        exec "$MENU_BIN"
    fi

    pause
    return 0
}

version_is_newer() {
    local remote="${1#v}"
    local local_ver="${2#v}"
    [[ -z "$remote" || -z "$local_ver" || "$local_ver" == "desconhecida" || "$remote" == "desconhecida" ]] && return 1
    [[ "$remote" == "$local_ver" ]] && return 1

    local highest
    highest=$(printf '%s\n%s\n' "$remote" "$local_ver" | sort -V | tail -n1)
    if [[ "$highest" == "$remote" && "$remote" != "$local_ver" ]]; then
        return 0
    fi
    return 1
}

fetch_remote_proxy_version() {
    local json tag redirect_loc
    # 1. API oficial com User-Agent
    json=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 3 --max-time 5 \
        -H "Cache-Control: no-cache" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${PROXY_REPO}/releases/latest" 2>/dev/null || true)
    tag=$(echo "$json" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/' | tr -d 'v\r\n' || true)

    # 2. Contingência para 403 / limite de taxa da API: redirect 302 da URL web
    if [[ -z "$tag" ]]; then
        redirect_loc=$(curl -sI -A "$DEFAULT_USER_AGENT" --connect-timeout 4 --max-time 6 "https://github.com/${PROXY_REPO}/releases/latest" 2>/dev/null | grep -i '^location:' | tr -d '\r\n' || true)
        tag=$(echo "$redirect_loc" | sed -E 's/.*\/tag\/v?([^\/\r\n]+).*/\1/' || true)
    fi

    # 3. Contingência: feed Atom
    if [[ -z "$tag" ]]; then
        tag=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 4 --max-time 6 "https://github.com/${PROXY_REPO}/releases.atom" 2>/dev/null \
            | grep -oE '/releases/tag/[^"'\''<> ]+' | head -n1 | sed -E 's|/releases/tag/v?||' | tr -d '\r\n' || true)
    fi

    echo "$tag"
}

fetch_remote_udpgw_version() {
    local json tag redirect_loc
    # 1. API oficial com User-Agent
    json=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 3 --max-time 5 \
        -H "Cache-Control: no-cache" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${UDPGW_REPO}/releases/latest" 2>/dev/null || true)
    tag=$(echo "$json" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/' | tr -d 'v\r\n' || true)

    # 2. Contingência para 403 / limite de taxa da API: redirect 302 da URL web
    if [[ -z "$tag" ]]; then
        redirect_loc=$(curl -sI -A "$DEFAULT_USER_AGENT" --connect-timeout 4 --max-time 6 "https://github.com/${UDPGW_REPO}/releases/latest" 2>/dev/null | grep -i '^location:' | tr -d '\r\n' || true)
        tag=$(echo "$redirect_loc" | sed -E 's/.*\/tag\/v?([^\/\r\n]+).*/\1/' || true)
    fi

    # 3. Contingência: feed Atom
    if [[ -z "$tag" ]]; then
        tag=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 4 --max-time 6 "https://github.com/${UDPGW_REPO}/releases.atom" 2>/dev/null \
            | grep -oE '/releases/tag/[^"'\''<> ]+' | head -n1 | sed -E 's|/releases/tag/v?||' | tr -d '\r\n' || true)
    fi

    echo "$tag"
}

fetch_remote_menu_revision() {
    local content rev
    content=$(curl -fsSL -A "$DEFAULT_USER_AGENT" --connect-timeout 3 --max-time 5 "${INSTALL_URL}?$(date +%s)" 2>/dev/null || true)
    rev=$(echo "$content" | grep -E '^(MENU_REV_EXPECTED|MENU_REV)=' | head -n1 | cut -d'"' -f2 | tr -d '\r\n' || true)
    if [[ -z "$rev" ]]; then
        rev=$(echo "$content" | grep -E '^INSTALLER_REV=' | head -n1 | cut -d'"' -f2 | tr -d '\r\n' || true)
    fi
    echo "$rev"
}

check_system_updates() {
    local force="${1:-false}"
    local now
    now=$(date +%s)

    if [[ "$force" != "true" && -f "$UPDATE_CACHE_FILE" ]]; then
        local cache_time
        cache_time=$(sed -n '1p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo 0)
        if [[ "$cache_time" =~ ^[0-9]+$ ]] && (( now - cache_time < UPDATE_CACHE_TTL )); then
            REMOTE_PROXY_VER=$(sed -n '2p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo "")
            REMOTE_UDPGW_VER=$(sed -n '3p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo "")
            REMOTE_MENU_REV=$(sed -n '4p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo "")
            HAS_PROXY_UPDATE=$(sed -n '5p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo 0)
            HAS_UDPGW_UPDATE=$(sed -n '6p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo 0)
            HAS_MENU_UPDATE=$(sed -n '7p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo 0)
            HAS_SYSTEM_UPDATE=$(sed -n '8p' "$UPDATE_CACHE_FILE" 2>/dev/null || echo 0)
            return 0
        fi
    fi

    REMOTE_PROXY_VER=$(fetch_remote_proxy_version)
    REMOTE_UDPGW_VER=$(fetch_remote_udpgw_version)
    REMOTE_MENU_REV=$(fetch_remote_menu_revision)

    local local_proxy local_udpgw local_menu_rev
    local_proxy=$(get_installed_proxy_version_label)
    local_udpgw=$(get_installed_udpgw_version_label)
    local_menu_rev="$MENU_REV"

    HAS_PROXY_UPDATE=0
    HAS_UDPGW_UPDATE=0
    HAS_MENU_UPDATE=0
    HAS_SYSTEM_UPDATE=0

    if [[ -n "$REMOTE_PROXY_VER" ]] && version_is_newer "$REMOTE_PROXY_VER" "$local_proxy"; then
        HAS_PROXY_UPDATE=1
    fi

    if [[ -n "$REMOTE_UDPGW_VER" ]] && version_is_newer "$REMOTE_UDPGW_VER" "$local_udpgw"; then
        HAS_UDPGW_UPDATE=1
    fi

    if [[ -n "$REMOTE_MENU_REV" && "$REMOTE_MENU_REV" =~ ^[0-9]+$ && "$local_menu_rev" =~ ^[0-9]+$ ]]; then
        if (( REMOTE_MENU_REV > local_menu_rev )); then
            HAS_MENU_UPDATE=1
        fi
    fi

    if (( HAS_PROXY_UPDATE || HAS_UDPGW_UPDATE || HAS_MENU_UPDATE )); then
        HAS_SYSTEM_UPDATE=1
    fi

    cat << EOF > "$UPDATE_CACHE_FILE" 2>/dev/null || true
$now
$REMOTE_PROXY_VER
$REMOTE_UDPGW_VER
$REMOTE_MENU_REV
$HAS_PROXY_UPDATE
$HAS_UDPGW_UPDATE
$HAS_MENU_UPDATE
$HAS_SYSTEM_UPDATE
EOF
    chmod 666 "$UPDATE_CACHE_FILE" 2>/dev/null || true
}

update_system_menu() {
    print_header

    check_system_updates true

    local proxy_ver udpgw_ver
    proxy_ver=$(get_installed_proxy_version_label)
    udpgw_ver=$(get_installed_udpgw_version_label)

    local proxy_badge="${GREEN}[$(t update_badge_current)]${RESET}"
    local udpgw_badge="${GREEN}[$(t update_badge_current)]${RESET}"
    local menu_badge="${GREEN}[$(t update_badge_current)]${RESET}"

    [[ "${HAS_PROXY_UPDATE:-0}" -eq 1 ]] && proxy_badge="${YELLOW}[➜ v${REMOTE_PROXY_VER}]${RESET}"
    [[ "${HAS_UDPGW_UPDATE:-0}" -eq 1 ]] && udpgw_badge="${YELLOW}[➜ v${REMOTE_UDPGW_VER}]${RESET}"
    [[ "${HAS_MENU_UPDATE:-0}" -eq 1 ]] && menu_badge="${YELLOW}[➜ rev ${REMOTE_MENU_REV}]${RESET}"

    print_box_open
    print_box_heading "$(t update_menu_title)" "$CYAN"
    print_box_divider
    print_box_line "${WHITE}  • $(t update_component_proxy) ${CYAN}v${proxy_ver}${RESET} ${proxy_badge}"
    print_box_line "${WHITE}  • $(t update_component_udpgw) ${CYAN}v${udpgw_ver}${RESET} ${udpgw_badge}"
    print_box_line "${WHITE}  • $(t update_component_menu)  ${CYAN}rev ${MENU_REV}${RESET} ${menu_badge}"
    print_box_close
    echo

    show_update_preserve_notice
    echo

    if ! confirm_action "$(t update_confirm_prompt)" "s"; then
        print_info "$(t update_canceled)"
        pause
        return 0
    fi

    run_system_update
}

remove_completely() {
    print_header
    
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}                   ⚠️  $(t remove_title) ⚠️                    ${RED}║${RESET}"
    echo -e "${RED}║${WHITE}        $(t remove_warning_banner)       ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${YELLOW}Itens que serão removidos:${RESET}"
    echo -e "${WHITE}  • Serviço UDP Gateway (udpgw)${RESET}"
    echo -e "${WHITE}  • Todos os serviços Proxy ativos${RESET}"
    echo -e "${WHITE}  • Serviço SSH Auth API${RESET}"
    echo -e "${WHITE}  • Ambiente virtual SSH Auth${RESET}"
    echo -e "${WHITE}  • Binários do sistema${RESET}"
    echo -e "${WHITE}  • Arquivos de configuração${RESET}"
    echo -e "${WHITE}  • Arquivos de dados e logs${RESET}"
    echo -e "${WHITE}  • Script de gerenciamento${RESET}"
    echo
    
    if ! confirm_action "${RED}$(t remove_confirm_sure)${RESET}" "n"; then
        print_info "$(t remove_canceled)"
        pause
        return
    fi
    
    print_info "Iniciando remoção completa..."

    if systemctl is-active --quiet "$UDPGW_SERVICE_NAME" 2>/dev/null; then
        print_info "Parando serviço legado $UDPGW_SERVICE_NAME..."
        sudo systemctl stop "$UDPGW_SERVICE_NAME"
        sudo systemctl disable "$UDPGW_SERVICE_NAME" 2>/dev/null
    fi

    print_info "Parando serviços UDP Gateway..."
    for service in /etc/systemd/system/${UDPGW_SERVICE_PREFIX}-*.service; do
        [[ -f "$service" ]] || continue
        local sn
        sn=$(basename "$service")
        sudo systemctl stop "$sn" 2>/dev/null || true
        sudo systemctl disable "$sn" 2>/dev/null || true
        sudo rm -f "$service"
    done

    print_info "Parando serviço SSH Auth API..."
    if systemctl is-active --quiet ssh-auth-api; then
        sudo systemctl stop ssh-auth-api
        sudo systemctl disable ssh-auth-api 2>/dev/null
        sudo rm -f "/etc/systemd/system/ssh-auth-api.service"
    fi

    print_info "Removendo arquivos SSH Auth API..."
    sudo rm -f "/usr/local/bin/ssh_auth.py"
    sudo rm -rf "/usr/local/bin/ssh_auth_venv"
    
    print_info "Parando todos os serviços proxy..."
    for service in $(systemctl list-units --type=service --no-legend | grep "$PROXY_SERVICE_PREFIX" | awk '{print $1}'); do
        if systemctl is-active --quiet "$service"; then
            sudo systemctl stop "$service"
        fi
        sudo systemctl disable "$service" 2>/dev/null
        sudo rm -f "/etc/systemd/system/$service.service"
    done
    
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    
    sudo rm -f "/etc/systemd/system/${UDPGW_SERVICE_NAME}.service"
    
    print_info "Removendo binários..."
    sudo rm -f "$UDPGW_BIN"
    sudo rm -f "$PROXY_EXECUTABLE"
    sudo rm -f "/usr/local/bin/vt"
    sudo rm -f "/usr/local/bin/main"
    sudo rm -f "/usr/local/bin/vt-iptables"
    print_info "Removendo configurações e dados..."
    sudo rm -rf /etc/udpgw
    sudo rm -f "$UDPGW_VERSION_FILE"
    sudo rm -rf "$(dirname "$PROXY_TOKEN_VTPROXY")"
    sudo rm -rf "$PROXY_DIR"
    sudo rm -rf "$PROXY_LOG_DIR"
    sudo rm -f "$PROXY_TOKEN_HOME"
    print_success "$(t remove_success)"
    echo
    echo -e "${GREEN}$(t remove_clean)${RESET}"
    echo
    
    pause
    exit 0
}

change_proxy_token_menu() {
    print_header

    local new_token
    while true; do
        echo -e "${BLUE}$(t token_prompt_input "$PROJECT_NAME")${RESET}"
        read -rp "> " new_token
        new_token=$(echo "$new_token" | tr -d '\000-\037')

        if [[ -z "$new_token" ]]; then
            print_error "$(t token_empty_error)"
            continue
        fi

        if validate_proxy_token "$new_token"; then
            save_proxy_token "$new_token"
            print_success "$(t token_saved_success)"
            print_info "$(t token_syncing)"
            local updated
            updated=$(sync_all_proxy_tokens "$new_token")
            print_success "$(t token_applied_ports "$updated")"
            break
        else
            print_error "$(t token_invalid_retry)"
        fi
    done
    pause
}

tokens_menu() {
    while true; do
        print_header
        local proxy_status
        if [[ -n "$(load_proxy_token)" ]]; then
            proxy_status="$(mark_ok)"
        else
            proxy_status="$(mark_fail)"
        fi

        print_box_open
        print_box_heading "$(t token_menu_title)"
        print_box_divider
        print_box_line "${WHITE}  $(t token_menu_proxy_lic) ${proxy_status}${RESET}"
        print_box_divider
        render_menu_option "1 • $(t token_opt_config)"
        render_menu_option "0 • $(t token_opt_back)" "red"
        print_box_close
        echo

        local option
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-1"):${RESET} ")" option
        case "$option" in
            1) change_proxy_token_menu ;;
            0) return 0 ;;
            *) print_error "$(t invalid_option "$option")"; pause ;;
        esac
    done
}

initial_menu() {
    while true; do
        print_header
        print_status
        print_initial_menu
        
        local option
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-7"):${RESET} ")" option
        
        case "$option" in
            1) connection_menu ;;
            2) online_users_menu ;;
            3) tokens_menu ;;
            4) update_system_menu ;;
            5) udpgw_main_menu ;;
            6) language_menu ;;
            7) remove_completely ;;
            0)
                print_info "$(t exiting)"
                exit 0
                ;;
            *)
                print_error "$(t invalid_option "$option")"
                pause
                ;;
        esac
    done
}

vt_set_limit_entry() {
    local file="$1"
    local domain="$2"
    local type="$3"
    local item="$4"
    local val="$5"

    [[ -f "$file" ]] || return 0

    local pattern="^[[:space:]]*${domain//\*/\\*}[[:space:]]+${type}[[:space:]]+${item}[[:space:]]+"
    local current_line
    current_line=$(grep -E "$pattern" "$file" 2>/dev/null | tail -n1 || true)

    if [[ -n "$current_line" ]]; then
        local current_val
        current_val=$(echo "$current_line" | awk '{print $4}')
        if [[ "$current_val" == "$val" ]]; then
            return 0
        fi
        local esc_domain="${domain}"
        [[ "$esc_domain" == "*" ]] && esc_domain="\*"
        sudo sed -i -E "s|^([[:space:]]*)${esc_domain}([[:space:]]+)${type}([[:space:]]+)${item}([[:space:]]+)[0-9]+|\1${domain}\2${type}\3${item}\4${val}|g" "$file" 2>/dev/null || true
    else
        printf '%s\t%s\t%s\t%s\n' "$domain" "$type" "$item" "$val" | sudo tee -a "$file" >/dev/null
    fi
}

install_vt_iptables_script() {
    local target="/usr/local/bin/vt-iptables"
    cat << 'EOF' | sudo tee "$target" >/dev/null
#!/usr/bin/env bash
# ==============================================================================
# VTProxy / VeltrixProxy - Auto-configurador inteligente de iptables para BTUN
# ==============================================================================
set -u

TUN_SUBNET="${BTUN_SUBNET:-}"
if [[ -z "$TUN_SUBNET" && -f "/etc/proxyvt/config.json" ]]; then
  TUN_SUBNET=$(grep -oE '"subnet"[[:space:]]*:[[:space:]]*"[^"]+"' /etc/proxyvt/config.json 2>/dev/null | head -n1 | cut -d'"' -f4 || true)
fi
TUN_SUBNET="${TUN_SUBNET:-10.77.0.0/16}"

# Carregar modulos de rede e NAT do kernel se disponiveis
for mod in ip_tables iptable_filter iptable_nat iptable_mangle nf_nat nf_conntrack xt_conntrack xt_state xt_MASQUERADE xt_tcp_flags xt_TCPMSS; do
  modprobe "$mod" 2>/dev/null || true
done

detect_tun_interface() {
  local iface=""
  # 1. Procura interface btun ativa
  iface=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^btun[0-9]*' | head -n1)
  if [[ -n "$iface" ]]; then
    echo "$iface"
    return 0
  fi

  # 2. Procura configuracao tun no /etc/proxyvt/config.json
  if [[ -f "/etc/proxyvt/config.json" ]]; then
    iface=$(grep -oE '"tun"[[:space:]]*:[[:space:]]*"[^"]+"' /etc/proxyvt/config.json 2>/dev/null | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$iface" ]]; then
      echo "$iface"
      return 0
    fi
  fi

  # 3. Procura flag --btun-tun nos servicos systemd legados
  for svc in /etc/systemd/system/vtproxy.service /etc/systemd/system/proxy-*.service; do
    [[ -f "$svc" ]] || continue
    iface=$(grep -oE '--btun-tun[= ][^ ]+' "$svc" 2>/dev/null | tr '=' ' ' | awk '{print $2}' | head -n1)
    if [[ -n "$iface" ]]; then
      echo "$iface"
      return 0
    fi
  done

  # 4. Procura interface com IP na faixa 10.77.
  iface=$(ip -4 addr show 2>/dev/null | grep -B2 '10\.77\.' | awk -F': ' '/^[0-9]+: / {print $2}' | head -n1)
  if [[ -n "$iface" ]]; then
    echo "$iface"
    return 0
  fi

  # 5. Fallback padrao oficial
  echo "btun0"
}

detect_wan_interface() {
  local iface=""
  # 1. Rota padrao IPv4 (captura dinamicamente o campo apos 'dev')
  iface=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
  if [[ -n "$iface" ]]; then
    echo "$iface"
    return 0
  fi

  # 2. Sondagem de rota publica (8.8.8.8)
  iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
  if [[ -n "$iface" ]]; then
    echo "$iface"
    return 0
  fi

  # 3. Rota padrao IPv6
  iface=$(ip -6 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
  if [[ -n "$iface" ]]; then
    echo "$iface"
    return 0
  fi

  # 4. Primeira interface fisica ativa que nao seja loopback/virtual/tun
  iface=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -vE '^(lo|btun|tun|tap|docker|veth|br-|wg|virbr)' | head -n1)
  if [[ -n "$iface" ]]; then
    echo "$iface"
    return 0
  fi

  echo "eth0"
}

persist_rules() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
  fi
  mkdir -p /etc/iptables 2>/dev/null || true
  if command -v iptables-save >/dev/null 2>&1; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    if [[ -d /etc/sysconfig ]]; then
      iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
    fi
  fi
}

TUN_IFACE=$(detect_tun_interface)
WAN_IFACE=$(detect_wan_interface)

echo "[VT-IPTABLES] Configurando roteamento: TUN=$TUN_IFACE | WAN=$WAN_IFACE | Subnet=$TUN_SUBNET"

# 1. Habilitar encaminhamento de pacotes IPv4 no Kernel
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

if ! command -v iptables >/dev/null 2>&1; then
  echo "[VT-IPTABLES] Aviso: comando iptables nao encontrado." >&2
  exit 0
fi

# Deteccao do modulo de conexao: prefere conntrack moderno, fallback para state
state_match="-m conntrack --ctstate RELATED,ESTABLISHED"
if ! iptables -m conntrack --help >/dev/null 2>&1; then
  state_match="-m state --state RELATED,ESTABLISHED"
fi

err_count=0

# 2. NAT (MASQUERADE)
if [[ -n "$WAN_IFACE" ]]; then
  iptables -t nat -C POSTROUTING -s "$TUN_SUBNET" -o "$WAN_IFACE" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$TUN_SUBNET" -o "$WAN_IFACE" -j MASQUERADE 2>/dev/null || ((err_count++))
fi

iptables -t nat -C POSTROUTING -s "$TUN_SUBNET" ! -o "$TUN_IFACE" -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s "$TUN_SUBNET" ! -o "$TUN_IFACE" -j MASQUERADE 2>/dev/null || ((err_count++))

# 3. FORWARD - Inserir no inicio para ter prioridade sobre regras DROP (ex: Docker, UFW)
iptables -C FORWARD -s "$TUN_SUBNET" -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 1 -s "$TUN_SUBNET" -j ACCEPT 2>/dev/null || ((err_count++))

iptables -C FORWARD -d "$TUN_SUBNET" $state_match -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 2 -d "$TUN_SUBNET" $state_match -j ACCEPT 2>/dev/null || ((err_count++))

# 4. FORWARD - Interface TUN
if [[ -n "$TUN_IFACE" ]]; then
  iptables -C FORWARD -i "$TUN_IFACE" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i "$TUN_IFACE" -j ACCEPT 2>/dev/null || ((err_count++))

  iptables -C FORWARD -o "$TUN_IFACE" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -o "$TUN_IFACE" -j ACCEPT 2>/dev/null || ((err_count++))

  if [[ -n "$WAN_IFACE" ]]; then
    iptables -C FORWARD -i "$TUN_IFACE" -o "$WAN_IFACE" -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i "$TUN_IFACE" -o "$WAN_IFACE" -j ACCEPT 2>/dev/null || ((err_count++))

    iptables -C FORWARD -i "$WAN_IFACE" -o "$TUN_IFACE" $state_match -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i "$WAN_IFACE" -o "$TUN_IFACE" $state_match -j ACCEPT 2>/dev/null || ((err_count++))
  fi
fi

# 5. TCP MSS Clamping (evita travamento de pacotes grandes / TLS em tunelamento)
iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
  iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true

# 6. Salvar persistencia das regras
persist_rules

if (( err_count > 0 )); then
  echo "[VT-IPTABLES] Aviso: $err_count regra(s) de iptables nao puderam ser aplicadas (verifique permissoes ou suporte no kernel)." >&2
else
  echo "[VT-IPTABLES] Regras de iptables aplicadas com sucesso!"
fi
exit 0
EOF
    sudo chmod +x "$target" 2>/dev/null || true
}

ensure_system_tuning() {
    # 1. Limites de descritores de arquivos (File Descriptors / limits.d / limits.conf)
    if [[ -d /etc/security ]]; then
        sudo mkdir -p /etc/security/limits.d 2>/dev/null || true
        sudo rm -f /etc/security/limits.d/99-veltrix-proxy.conf 2>/dev/null || true
        cat << 'EOF' | sudo tee /etc/security/limits.d/99-proxy.conf >/dev/null
# VeltrixProxy / VTProxy - File Descriptors & Sockets Limits (65536 conexões)
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    fi

    if [[ -f /etc/security/limits.conf ]]; then
        vt_set_limit_entry "/etc/security/limits.conf" "*" "soft" "nofile" "65536"
        vt_set_limit_entry "/etc/security/limits.conf" "*" "hard" "nofile" "65536"
        vt_set_limit_entry "/etc/security/limits.conf" "root" "soft" "nofile" "65536"
        vt_set_limit_entry "/etc/security/limits.conf" "root" "hard" "nofile" "65536"
    fi

    if [[ -d /etc/profile.d ]]; then
        echo 'ulimit -n 65536 2>/dev/null || true' | sudo tee /etc/profile.d/99-proxy-limits.sh >/dev/null
        sudo chmod 644 /etc/profile.d/99-proxy-limits.sh 2>/dev/null || true
    fi

    ulimit -n 65536 2>/dev/null || true

    # 2. Otimizações de Kernel e Rede (TCP / BBR / sysctl)
    local sysctl_conf="/etc/sysctl.d/99-proxy.conf"

    sudo rm -f /etc/sysctl.d/99-vtproxy.conf /etc/sysctl.d/99-veltrix-proxy.conf /etc/sysctl.d/zz-custom-network.conf 2>/dev/null || true
    sudo mkdir -p /etc/sysctl.d 2>/dev/null || true

    if [[ -f /etc/sysctl.conf ]]; then
        sudo sed -i -E '/^(net\.core\.(somaxconn|rmem_max|wmem_max|rmem_default|wmem_default|netdev_max_backlog|default_qdisc)|net\.ipv4\.(tcp_tw_reuse|tcp_fin_timeout|tcp_max_tw_buckets|ip_local_port_range|tcp_max_syn_backlog|tcp_slow_start_after_idle|tcp_fastopen|tcp_rmem|tcp_wmem|tcp_congestion_control|tcp_keepalive_time|tcp_keepalive_intvl|tcp_keepalive_probes)|vm\.swappiness)/d' /etc/sysctl.conf 2>/dev/null || true
    fi

    cat << 'EOF' | sudo tee "$sysctl_conf" >/dev/null
# VTProxy / VeltrixProxy Network & Kernel Optimizations
net.ipv4.ip_forward = 1

# === 1. Reciclagem Rápida de Sockets e Anti-Ghosting ===
# Permite reusar portas em TIME_WAIT de forma segura sem colisão
net.ipv4.tcp_tw_reuse = 1
# Reduz o tempo de vida de conexões mortas de 60s para 15s (libera RAM 4x mais rápido)
net.ipv4.tcp_fin_timeout = 15
# Limite seguro de sockets em TIME_WAIT na memória (ocupa no máximo ~30 MB)
net.ipv4.tcp_max_tw_buckets = 131072
# Reduz keepalive de 7200s (2h) para 300s (5min) para limpar conexões fantasmas de redes móveis
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5

# === 2. Expansão de Portas Locais ===
# Libera mais de 55.000 portas para conectar ao OpenSSH, V2Ray e OpenVPN locais
net.ipv4.ip_local_port_range = 10240 65535

# === 3. Filas de Conexão de Alta Concorrência (Suporta até 65k conexões simultâneas) ===
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 65535

# === 4. Desempenho e Latência ===
# Não reseta a janela de velocidade para o mínimo após pequenas pausas
net.ipv4.tcp_slow_start_after_idle = 0
# Acelera o handshake inicial
net.ipv4.tcp_fastopen = 3

# === 5. Gerenciamento de Memória / Swap ===
# Prioriza o uso da RAM ao máximo antes de utilizar o disco swap
vm.swappiness = 10

# === 6. Auto-Tuning de Memória Seguro (Mínimo Leve, Escala se Precisar) ===
# O socket inicia leve (4KB a 64KB) e só cresce até 8MB se o cliente tiver muita banda
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608

# === 7. Algoritmo BBR do Google (Mais velocidade em conexões móveis 4G/5G) ===
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

    sudo modprobe tcp_bbr 2>/dev/null || true
    sudo modprobe sch_fq 2>/dev/null || true

    local keys=(
        "net.ipv4.ip_forward=1"
        "net.ipv4.tcp_tw_reuse=1"
        "net.ipv4.tcp_fin_timeout=15"
        "net.ipv4.tcp_max_tw_buckets=131072"
        "net.ipv4.tcp_keepalive_time=300"
        "net.ipv4.tcp_keepalive_intvl=15"
        "net.ipv4.tcp_keepalive_probes=5"
        "net.ipv4.ip_local_port_range=10240 65535"
        "net.core.somaxconn=65535"
        "net.ipv4.tcp_max_syn_backlog=65535"
        "net.core.netdev_max_backlog=65535"
        "net.ipv4.tcp_slow_start_after_idle=0"
        "net.ipv4.tcp_fastopen=3"
        "vm.swappiness=10"
        "net.core.rmem_default=65536"
        "net.core.wmem_default=65536"
        "net.core.rmem_max=8388608"
        "net.core.wmem_max=8388608"
        "net.ipv4.tcp_rmem=4096 87380 8388608"
        "net.ipv4.tcp_wmem=4096 65536 8388608"
        "net.core.default_qdisc=fq"
        "net.ipv4.tcp_congestion_control=bbr"
    )

    for kv in "${keys[@]}"; do
        sudo sysctl -w "$kv" >/dev/null 2>&1 || true
    done

    sudo sysctl -p "$sysctl_conf" >/dev/null 2>&1 || true
    sudo sysctl --system >/dev/null 2>&1 || true

    # 3. Auto-configurador de iptables para BTUN
    install_vt_iptables_script || true
    sudo /usr/local/bin/vt-iptables >/dev/null 2>&1 || true

    # 4. Configuração de locale UTF-8 global leve
    ensure_locale_tuning || true

    # 4. Otimizações de alta concorrência e estabilidade do OpenSSH
    ensure_ssh_tuning || true
}

ensure_locale_tuning() {
    if [[ -d /etc/profile.d ]]; then
        cat << 'EOF' | sudo tee /etc/profile.d/99-utf8.sh >/dev/null
export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"
export LC_CTYPE="C.UTF-8"
EOF
        sudo chmod 644 /etc/profile.d/99-utf8.sh 2>/dev/null || true
    fi

    if [[ -f /etc/bash.bashrc ]] && ! grep -q "LANG=C.UTF-8" /etc/bash.bashrc 2>/dev/null; then
        echo 'export LANG="C.UTF-8" LC_ALL="C.UTF-8"' | sudo tee -a /etc/bash.bashrc >/dev/null || true
    fi

    if [[ -f /etc/environment ]] && ! grep -q "LANG=" /etc/environment 2>/dev/null; then
        echo 'LANG="C.UTF-8"' | sudo tee -a /etc/environment >/dev/null || true
    fi

    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
    export LC_CTYPE="C.UTF-8"
}

ensure_ssh_tuning() {
    local sshd_config="/etc/ssh/sshd_config"
    local sshd_dropin_dir="/etc/ssh/sshd_config.d"
    local sshd_dropin_conf="${sshd_dropin_dir}/99-proxy.conf"
    local keys_regex="LogLevel|AcceptEnv|MaxStartups|MaxSessions|MaxAuthTries|LoginGraceTime|UsePAM|UseDNS|GSSAPIAuthentication|TCPKeepAlive|ClientAliveInterval|ClientAliveCountMax|AllowTcpForwarding|GatewayPorts|PermitTunnel|X11Forwarding|Compression|PrintMotd|PrintLastLog"

    if [[ -d /etc/ssh ]]; then
        sudo mkdir -p "$sshd_dropin_dir" 2>/dev/null || true
        sudo rm -f "${sshd_dropin_dir}/99-vtproxy.conf" "${sshd_dropin_dir}/99-veltrix-proxy.conf" 2>/dev/null || true

        cat << 'EOF' | sudo tee "$sshd_dropin_conf" >/dev/null
# VTProxy / VeltrixProxy OpenSSH Optimizations
LogLevel ERROR
AcceptEnv LANG LC_*
MaxStartups 2000:30:5000
MaxSessions 500
MaxAuthTries 10
LoginGraceTime 30
UsePAM no
UseDNS no
GSSAPIAuthentication no
TCPKeepAlive yes
ClientAliveInterval 15
ClientAliveCountMax 3
AllowTcpForwarding yes
GatewayPorts yes
PermitTunnel yes
X11Forwarding no
Compression no
PrintMotd no
PrintLastLog no
EOF
        sudo chmod 644 "$sshd_dropin_conf" 2>/dev/null || true
    fi

    if [[ -f "$sshd_config" ]]; then
        if ! grep -qiE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$sshd_config"; then
            sudo sed -i '1i Include /etc/ssh/sshd_config.d/*.conf\n' "$sshd_config" 2>/dev/null || true
        fi

        sudo sed -i -E -e "/^[[:space:]]*(${keys_regex})([[:space:]=]|$)/Id" "$sshd_config" 2>/dev/null || true
    fi

    for svc_dir in /etc/systemd/system/ssh.service.d /etc/systemd/system/sshd.service.d; do
        sudo mkdir -p "$svc_dir" 2>/dev/null || true
        cat << 'EOF' | sudo tee "${svc_dir}/99-proxy-limits.conf" >/dev/null
[Service]
LimitNOFILE=1048576
LimitNPROC=65536
TasksMax=infinity
EOF
    done

    if sshd -t >/dev/null 2>&1; then
        sudo systemctl daemon-reload >/dev/null 2>&1 || true
        sudo systemctl reload ssh >/dev/null 2>&1 || sudo systemctl reload sshd >/dev/null 2>&1 || sudo service ssh reload >/dev/null 2>&1 || sudo service sshd reload >/dev/null 2>&1 || true
    fi
}

if [[ "$1" == "--migrate" ]]; then
    migrate_legacy_services_to_unified || true
    exit 0
fi

if [[ "$1" == "--iptables" || "$1" == "iptables" ]]; then
    install_vt_iptables_script || true
    sudo /usr/local/bin/vt-iptables
    exit 0
fi

load_language

if [ "$EUID" -ne 0 ]; then
    print_error "$(t root_required)"
    echo -e "${YELLOW}$(t run_with_sudo "$0")${RESET}"
    exit 1
fi

ensure_system_tuning || true

migrate_legacy_services_to_unified || true

check_token_on_startup

run_quick_setup_first_time

migrate_legacy_udpgw_if_needed || true
udpgw_fix_all_metrics_collisions || true

initial_menu


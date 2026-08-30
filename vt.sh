#!/bin/bash

readonly PROJECT_NAME="VTProxy"
readonly MENU_BOX_MIN=34
readonly MENU_BOX_MAX=56
readonly MENU_REV="42"
readonly INSTALL_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh"
readonly LICENSE_API_URL="${LICENSE_API_URL:-https://proxyvt.sshtproject.com}"
readonly MENU_BIN="/usr/local/bin/vt"
readonly PROXY_VERSION_FILE="/etc/proxy-version"
readonly UDPGW_VERSION_FILE="/etc/udpgw-version"
readonly UDPGW_REPO="TelksBr/VeltrixUPGW"
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
I18N_PT[status_ssh_onlines]="Onlines SSH:"
I18N_PT[status_udpgw]="UDP Gateway:"
I18N_PT[status_ports]="portas"

I18N_PT[menu_main_title]="MENU INICIAL"
I18N_PT[menu_proxy]="Proxy / Portas"
I18N_PT[menu_online_users]="Usuarios Online (SSH:%s)"
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
I18N_PT[proxy_opt_start]="Iniciar porta configurada"
I18N_PT[proxy_opt_stop]="Parar porta (mantém config)"
I18N_PT[proxy_opt_restart]="Reiniciar serviço proxy"
I18N_PT[proxy_opt_edit]="Editar / Alternar porta (SSL, Pausar/Ativar)"
I18N_PT[proxy_opt_adv]="Opções avançadas globais (buffer/flags)"
I18N_PT[proxy_opt_http]="Alterar resposta HTTP global"
I18N_PT[proxy_opt_details]="Detalhes do serviço unificado"
I18N_PT[proxy_opt_logs]="Ver log da porta"
I18N_PT[proxy_opt_remove]="Remover porta"
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
I18N_EN[status_ports]="ports"

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
I18N_EN[lang_saved]="Language changed to %s!"

I18N_EN[proxy_menu_title]="%s — PROXY"
I18N_EN[proxy_menu_ports]="Ports: %s"
I18N_EN[proxy_opt_open]="Open / create port"
I18N_EN[proxy_opt_start]="Start configured port"
I18N_EN[proxy_opt_stop]="Stop port (keep config)"
I18N_EN[proxy_opt_restart]="Restart port"
I18N_EN[proxy_opt_edit]="Edit port"
I18N_EN[proxy_opt_adv]="Advanced options (buffer/flags)"
I18N_EN[proxy_opt_http]="Change HTTP response"
I18N_EN[proxy_opt_details]="Details / ExecStart"
I18N_EN[proxy_opt_logs]="View port log"
I18N_EN[proxy_opt_remove]="Remove port"
I18N_EN[proxy_opt_back]="Back to Main Menu"

I18N_EN[udpgw_menu_title]="UDP GATEWAY (udpgw)"
I18N_EN[udpgw_menu_ports]="Ports: %s"
I18N_EN[udpgw_opt_open]="Open / create port"
I18N_EN[udpgw_opt_start]="Start port"
I18N_EN[udpgw_opt_stop]="Stop port"
I18N_EN[udpgw_opt_restart]="Restart port"
I18N_EN[udpgw_opt_status]="Status & ExecStart"
I18N_EN[udpgw_opt_metrics]="Metrics dashboard"
I18N_EN[udpgw_opt_logs]="View logs"
I18N_EN[udpgw_opt_adv]="Advanced options (flags)"
I18N_EN[udpgw_opt_install]="Install/update binary"
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
I18N_ES[status_ports]="puertos"

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
I18N_ES[proxy_opt_open]="Abrir / crear puerto"
I18N_ES[proxy_opt_start]="Iniciar puerto configurado"
I18N_ES[proxy_opt_stop]="Detener puerto (mantiene config)"
I18N_ES[proxy_opt_restart]="Reiniciar puerto"
I18N_ES[proxy_opt_edit]="Editar puerto"
I18N_ES[proxy_opt_adv]="Opciones avanzadas (buffer/flags)"
I18N_ES[proxy_opt_http]="Cambiar respuesta HTTP"
I18N_ES[proxy_opt_details]="Detalles / ExecStart"
I18N_ES[proxy_opt_logs]="Ver registros del puerto"
I18N_ES[proxy_opt_remove]="Eliminar puerto"
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
    local label="${item#* - }"
    # Compatível com itens antigos "N • label"
    if [[ "$item" == *" • "* ]]; then
        label="${item#* • }"
    fi
    local content

    if is_narrow_menu; then
        if [[ "$emphasis" == "red" ]]; then
            content="${RED}[${num}] ${label}${RESET}"
        else
            content="${WHITE}[${CYAN}${num}${WHITE}] ${BLUE}${label}${RESET}"
        fi
    else
    if [[ "$emphasis" == "red" ]]; then
        content="${RED}  [${num}] ${label}${RESET}"
    else
        content="${WHITE}  [${CYAN}${num}${WHITE}] ${BLUE}${label}${RESET}"
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

# Usuários SSH únicos com sessão sshd (filhos sshd:), excluindo root.
get_ssh_online_users_count() {
    local count
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

    proxy_ports=$(format_proxy_ports_status)
    proxy_label="${proxy_ports:-$(t status_none)}"
    [[ -n "$(load_proxy_token)" ]] && proxy_tok="$(mark_ok)" || proxy_tok="$(mark_fail)"
    bound_ip=""
    [[ -f /etc/vtproxy/ip ]] && bound_ip=$(cat /etc/vtproxy/ip)
    ssh_onlines=$(get_ssh_online_users_count)

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
        print_box_line "${WHITE}$(t status_token) ${proxy_tok}${RESET}"
        if [[ -n "$bound_ip" ]]; then
            print_box_line "${WHITE}$(t status_ip) ${CYAN}${bound_ip}${RESET}"
        fi
        print_box_line "${WHITE}$(t status_ssh_onlines)${CYAN}${ssh_onlines}${RESET}"
        print_box_line "${WHITE}UDPgw: ${udpgw_status}${WHITE} ${CYAN}${udpgw_ports}${RESET}"
    else
        print_box_line "${WHITE} $(t status_proxy) ${CYAN}${proxy_label}${RESET}"
        local tokens_line="${WHITE} $(t status_token_proxy) ${proxy_tok}"
        if [[ -n "$bound_ip" ]]; then
            tokens_line+="${WHITE} | $(t status_ip) ${CYAN}${bound_ip}${RESET}"
        fi
        print_box_line "$tokens_line"
        print_box_line "${WHITE} $(t status_ssh_onlines) ${CYAN}${ssh_onlines}${RESET}"
        print_box_line "${WHITE} $(t status_udpgw) ${udpgw_status}${WHITE} $(t status_ports) ${CYAN}${udpgw_ports}${RESET}"
    fi
    print_box_close
    echo
}

print_initial_menu() {
    print_box_open
    print_box_heading "$(t menu_main_title)"
    print_box_divider

    local ssh_onlines
    ssh_onlines=$(get_ssh_online_users_count)
    
    local menu_items=(
        "1 • $(t menu_proxy)"
        "2 • $(t menu_online_users "$ssh_onlines")"
        "3 • $(t menu_tokens)"
        "4 • $(t menu_update)"
        "5 • $(t menu_udpgw)"
        "6 • $(t menu_lang) [${LANG_ACTIVE^^}]"
        "7 • $(t menu_uninstall)"
        "0 • $(t menu_exit)"
    )
    
    for item in "${menu_items[@]}"; do
        if [[ $item == *"$(t menu_uninstall)"* || $item == *"$(t menu_exit)"* || $item == *"Remover"* || $item == *"Uninstall"* || $item == *"Desinstalar"* || $item == *"Sair"* || $item == *"Exit"* || $item == *"Salir"* ]]; then
            render_menu_option "$item" "red"
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
    sudo mkdir -p "$PROXY_DIR" "$PROXY_CONFIG_DIR" "$PROXY_LOG_DIR"
}

load_proxy_token() {
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
    sudo mkdir -p "$(dirname "$PROXY_TOKEN_VTPROXY")" "$PROXY_DIR"
    printf '%s' "$token" | sudo tee "$PROXY_TOKEN_VTPROXY" >/dev/null
    printf '%s' "$token" | sudo tee "$PROXY_TOKEN_FILE" >/dev/null
    printf '%s' "$token" >"$PROXY_TOKEN_HOME"
    sudo chmod 600 "$PROXY_TOKEN_VTPROXY" "$PROXY_TOKEN_FILE" 2>/dev/null || true
    chmod 600 "$PROXY_TOKEN_HOME" 2>/dev/null || true
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

list_configured_proxy_ports() {
    local ports=()
    local f port service_file

    ensure_proxy_dirs_quiet

    for service_file in /etc/systemd/system/${PROXY_SERVICE_PREFIX}-*.service; do
        [[ -f "$service_file" ]] || continue
        port=$(basename "$service_file" .service | sed -n "s/^${PROXY_SERVICE_PREFIX}-\\([0-9]\\+\\)$/\\1/p")
        [[ -n "$port" ]] && ports+=("$port")
    done

    for f in "$PROXY_CONFIG_DIR"/proxy-*.conf; do
        [[ -f "$f" ]] || continue
        port=$(basename "$f" .conf | sed -n 's/^proxy-\([0-9]\+\)$/\1/p')
        [[ -n "$port" ]] && ports+=("$port")
    done

    if [[ ${#ports[@]} -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "${ports[@]}" | sort -nu | paste -sd, - 2>/dev/null || true
}

get_global_proxy_setting() {
    local key="$1"
    local default_val="$2"
    local configured_ports port val

    configured_ports=$(list_configured_proxy_ports)
    if [[ -n "$configured_ports" ]]; then
        IFS=',' read -ra port_array <<< "$configured_ports"
        for port in "${port_array[@]}"; do
            [[ -z "$port" ]] && continue
            val=$(get_proxy_conf_value "$port" "$key" "")
            if [[ -n "$val" ]]; then
                echo "$val"
                return 0
            fi
        done
    fi
    echo "$default_val"
}


ensure_proxy_dirs_quiet() {
    sudo mkdir -p "$PROXY_DIR" "$PROXY_CONFIG_DIR" "$PROXY_LOG_DIR" 2>/dev/null || true
}

list_active_proxies() {
    local ports port active_list=""
    ports=$(list_configured_proxy_ports)
    [[ -z "$ports" ]] && return 0

    if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
        IFS=',' read -ra port_array <<< "$ports"
        for port in "${port_array[@]}"; do
            [[ -z "$port" ]] && continue
            local enabled
            enabled=$(get_proxy_conf_value "$port" "ENABLED" "true")
            if [[ "$enabled" == "true" ]]; then
                [[ -n "$active_list" ]] && active_list+=","
                active_list+="$port"
            fi
        done
        printf '%s' "$active_list"
        return 0
    fi

    # Fallback legado para transicao
    IFS=',' read -ra port_array <<< "$ports"
    for port in "${port_array[@]}"; do
        [[ -z "$port" ]] && continue
        local service_name
        service_name=$(get_proxy_service_name "$port")
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            [[ -n "$active_list" ]] && active_list+=","
            active_list+="$port"
        fi
    done
    printf '%s' "$active_list"
}

format_proxy_port_flags() {
    local port="$1"
    local flags=()
    local ssl cert_internal ssh_only

    ssl=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    cert_internal=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    ssh_only=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")

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
    local configured active status_items=() port ssl enabled item
    configured=$(list_configured_proxy_ports)

    if [[ -z "$configured" ]]; then
        echo "nenhuma"
        return 0
    fi

    IFS=',' read -ra port_array <<< "$configured"
    for port in "${port_array[@]}"; do
        [[ -z "$port" ]] && continue
        ssl=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
        enabled=$(get_proxy_conf_value "$port" "ENABLED" "true")

        item="$port"
        if [[ "$ssl" == "true" ]]; then
            item="${port} [SSL]"
        fi
        if [[ "$enabled" == "false" ]]; then
            item="${item} (OFF)"
        fi
        status_items+=("$item")
    done

    local count=${#status_items[@]}
    if (( count <= 4 )); then
        local IFS=,
        echo "${status_items[*]}" | sed 's/,/, /g'
    else
        local first_four=("${status_items[@]:0:4}")
        local remaining=$(( count - 4 ))
        local IFS=,
        echo "${first_four[*]}" | sed 's/,/, /g' | sed "s/$/ (+${remaining} portas)/"
    fi
}

is_port_in_use() {
    local port="$1"
    command -v ss >/dev/null 2>&1 && ss -tuln | grep -q ":$port "
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

is_proxy_service_configured() {
    local port="$1"
    [[ -f "$(get_proxy_config_file "$port")" ]] && return 0
    [[ -f "/etc/systemd/system/${PROXY_SERVICE_PREFIX}-${port}.service" ]] && return 0
    systemctl cat "${PROXY_SERVICE_PREFIX}-${port}" &>/dev/null
}

get_proxy_config_file() {
    local port="$1"
    echo "$PROXY_CONFIG_DIR/proxy-$port.conf"
}

get_proxy_log_file() {
    local port="$1"
    echo "$PROXY_LOG_DIR/proxy-$port.log"
}

get_proxy_service_name() {
    local port="$1"
    echo "$PROXY_SERVICE_PREFIX-$port"
}

get_proxy_conf_value() {
    local port="$1"
    local key="$2"
    local default="${3:-}"
    local file val
    file=$(get_proxy_config_file "$port")
    if [[ -f "$file" ]]; then
        val=$(grep -E "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d= -f2-)
        if [[ -n "$val" ]]; then
            printf '%s' "$val"
            return 0
        fi
    fi
    printf '%s' "$default"
}

write_proxy_conf() {
    local port="$1"
    local ssl_enabled="$2"
    local ssl_cert_path="$3"
    local cert_internal="$4"
    local ssh_only_flag="$5"
    local http_response="$6"
    local buffer_size="$7"
    local domain_flag="$8" # legado (ignorado; --domain removido do binario)
    local max_connections="$9"
    local write_timeout="${10}"
    local idle_timeout="${11}"
    local log_level="${12}"
    local ssh_port="${13}"
    local openvpn_port="${14}"
    local v2ray_port="${15}"
    local display_banner="${16}"
    local enabled="${17:-true}"
    local file

    ensure_proxy_dirs_quiet
    file=$(get_proxy_config_file "$port")

    sudo tee "$file" > /dev/null <<EOF
PORT=$port
ENABLED=$enabled
SSL_ENABLED=$ssl_enabled
SSL_CERT_PATH=$ssl_cert_path
CERT_INTERNAL=$cert_internal
SSH_ONLY=$ssh_only_flag
HTTP_RESPONSE=$http_response
BUFFER_SIZE=$buffer_size
DOMAIN=false
MAX_CONNECTIONS=$max_connections
WRITE_TIMEOUT=$write_timeout
IDLE_TIMEOUT=$idle_timeout
LOG_LEVEL=$log_level
SSH_PORT=$ssh_port
OPENVPN_PORT=$openvpn_port
V2RAY_PORT=$v2ray_port
DISPLAY_BANNER=$display_banner
EOF
}

set_proxy_conf_key() {
    local port="$1"
    local key="$2"
    local value="$3"
    local file temp_file
    file=$(get_proxy_config_file "$port")
    ensure_proxy_dirs_quiet
    temp_file=$(mktemp)

    if [[ -f "$file" ]]; then
        grep -v "^${key}=" "$file" > "$temp_file" || true
    fi
    echo "${key}=${value}" >> "$temp_file"
    sudo mv "$temp_file" "$file"
    sudo chmod 644 "$file" 2>/dev/null || true
}

migrate_proxy_conf_from_unit_if_needed() {
    local port="$1"
    local file service_file exec_line
    file=$(get_proxy_config_file "$port")
    [[ -f "$file" ]] && return 0

    service_file="/etc/systemd/system/$(get_proxy_service_name "$port").service"
    [[ -f "$service_file" ]] || return 1

    exec_line=$(grep -E '^ExecStart=' "$service_file" | head -n1 | sed 's/^ExecStart=//')

    local ssl="false" cert="" cert_internal="true" ssh_only="false"
    local response="$DEFAULT_HTTP_RESPONSE" buffer="$DEFAULT_BUFFER_SIZE"
    local domain="false"

    [[ "$exec_line" == *":ssl"* ]] && ssl="true"
    if [[ "$exec_line" =~ --cert=([^ ]+) ]]; then
        cert="${BASH_REMATCH[1]}"
        cert_internal="false"
    fi
    [[ "$exec_line" == *"--ssh-only"* ]] && ssh_only="true"
    if [[ "$exec_line" =~ --response=([^ ]+) ]]; then
        response="${BASH_REMATCH[1]}"
    fi
    if [[ "$exec_line" =~ --buffer-size=([0-9]+) ]]; then
        buffer="${BASH_REMATCH[1]}"
    fi

    write_proxy_conf "$port" "$ssl" "$cert" "$cert_internal" "$ssh_only" "$response" \
        "$buffer" "$domain" "0" "0" "0" "info" "22" "1194" "1080" "true"
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

build_proxy_command_from_conf() {
    local port="$1"
    local token="$2"

    migrate_proxy_conf_from_unit_if_needed "$port" || true

    local ssl_enabled ssl_cert_path cert_internal ssh_only_flag http_response
    local buffer_size max_connections write_timeout idle_timeout
    local log_level ssh_port openvpn_port v2ray_port display_banner

    ssl_enabled=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    ssl_cert_path=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
    cert_internal=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    ssh_only_flag=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")
    http_response=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
    buffer_size=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    max_connections=$(get_proxy_conf_value "$port" "MAX_CONNECTIONS" "0")
    write_timeout=$(get_proxy_conf_value "$port" "WRITE_TIMEOUT" "0")
    idle_timeout=$(get_proxy_conf_value "$port" "IDLE_TIMEOUT" "0")
    log_level=$(get_proxy_conf_value "$port" "LOG_LEVEL" "info")
    ssh_port=$(get_proxy_conf_value "$port" "SSH_PORT" "22")
    openvpn_port=$(get_proxy_conf_value "$port" "OPENVPN_PORT" "1194")
    v2ray_port=$(get_proxy_conf_value "$port" "V2RAY_PORT" "1080")
    display_banner=$(get_proxy_conf_value "$port" "DISPLAY_BANNER" "true")

    local command="$PROXY_EXECUTABLE --token=$token --buffer-size=$buffer_size --response=$http_response --log-file=$(get_proxy_log_file "$port") --log-level=$log_level --ssh-port=$ssh_port --openvpn-port=$openvpn_port --v2ray-port=$v2ray_port --max-connections=$max_connections --write-timeout=$write_timeout --idle-timeout=$idle_timeout"

    if [[ "$display_banner" != "true" ]]; then
        command="$command --display-banner=false"
    fi

    if [[ "$ssl_enabled" == "true" ]]; then
        command="$command --port=$port:ssl"
        if [[ "$cert_internal" == "true" ]]; then
            command="$command --cert-internal=true"
        else
            command="$command --cert-internal=false"
            if [[ -n "$ssl_cert_path" ]]; then
                command="$command --cert=$ssl_cert_path"
            fi
        fi
    else
        command="$command --port=$port"
    fi

    if [[ "$ssh_only_flag" == "true" ]]; then
        command="$command --ssh-only"
    fi

    echo "$command"
}

# Compatível com chamadas antigas (quick setup / start).
build_proxy_command() {
    local port="$1"
    local token="$2"
    local ssl_enabled="$3"
    local ssl_cert_path="$4"
    local ssh_only_flag="$5"
    local http_response="$6"
    local cert_internal="true"

    if [[ "$ssl_enabled" == "true" && -n "$ssl_cert_path" ]]; then
        cert_internal="false"
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ssl_cert_path" "$cert_internal" "$ssh_only_flag" \
        "$http_response" "$DEFAULT_BUFFER_SIZE" "false" "$DEFAULT_MAX_CONNECTIONS" "$DEFAULT_WRITE_TIMEOUT" "$DEFAULT_IDLE_TIMEOUT" "$DEFAULT_LOG_LEVEL" "$DEFAULT_SSH_PORT" "$DEFAULT_OPENVPN_PORT" "$DEFAULT_V2RAY_PORT" "true"
    build_proxy_command_from_conf "$port" "$token"
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
    local token="$1"
    local configured_ports port
    configured_ports=$(list_configured_proxy_ports)
    [[ -z "$configured_ports" ]] && return 0

    local port_args=()
    local custom_cert_path=""
    local has_ssl=false
    local has_cert_internal=true
    local any_ssh_only=false

    # Defaults para flags compartilhadas
    local buffer_size="$DEFAULT_BUFFER_SIZE"
    local http_response="$DEFAULT_HTTP_RESPONSE"
    local max_connections="$DEFAULT_MAX_CONNECTIONS"
    local write_timeout="$DEFAULT_WRITE_TIMEOUT"
    local idle_timeout="$DEFAULT_IDLE_TIMEOUT"
    local log_level="info"
    local ssh_port="22"
    local openvpn_port="1194"
    local v2ray_port="1080"
    local display_banner="true"

    IFS=',' read -ra port_array <<< "$configured_ports"
    for port in "${port_array[@]}"; do
        [[ -z "$port" ]] && continue
        migrate_proxy_conf_from_unit_if_needed "$port" || true

        local enabled
        enabled=$(get_proxy_conf_value "$port" "ENABLED" "true")
        [[ "$enabled" != "true" ]] && continue

        local ssl_enabled ssl_cert_path cert_internal ssh_only_flag
        ssl_enabled=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
        ssl_cert_path=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
        cert_internal=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
        ssh_only_flag=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")

        # Pega as flags compartilhadas da primeira porta ativa encontrada
        if [[ ${#port_args[@]} -eq 0 ]]; then
            buffer_size=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
            http_response=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
            max_connections=$(get_proxy_conf_value "$port" "MAX_CONNECTIONS" "$DEFAULT_MAX_CONNECTIONS")
            write_timeout=$(get_proxy_conf_value "$port" "WRITE_TIMEOUT" "$DEFAULT_WRITE_TIMEOUT")
            idle_timeout=$(get_proxy_conf_value "$port" "IDLE_TIMEOUT" "$DEFAULT_IDLE_TIMEOUT")
            log_level=$(get_proxy_conf_value "$port" "LOG_LEVEL" "info")
            ssh_port=$(get_proxy_conf_value "$port" "SSH_PORT" "22")
            openvpn_port=$(get_proxy_conf_value "$port" "OPENVPN_PORT" "1194")
            v2ray_port=$(get_proxy_conf_value "$port" "V2RAY_PORT" "1080")
            display_banner=$(get_proxy_conf_value "$port" "DISPLAY_BANNER" "true")
        fi

        if [[ "$ssl_enabled" == "true" ]]; then
            has_ssl=true
            port_args+=("--port=$port:ssl")
            if [[ "$cert_internal" == "false" && -n "$ssl_cert_path" ]]; then
                has_cert_internal=false
                custom_cert_path="$ssl_cert_path"
            fi
        else
            port_args+=("--port=$port")
        fi

        [[ "$ssh_only_flag" == "true" ]] && any_ssh_only=true
    done

    # Se nenhuma porta ativa estiver configurada, encerra
    [[ ${#port_args[@]} -eq 0 ]] && return 0

    local log_file="$PROXY_LOG_DIR/proxy.log"
    ensure_proxy_dirs_quiet

    local command="$PROXY_EXECUTABLE --token=$token ${port_args[*]} --buffer-size=$buffer_size --response=$http_response --log-file=$log_file --log-level=$log_level --ssh-port=$ssh_port --openvpn-port=$openvpn_port --v2ray-port=$v2ray_port --max-connections=$max_connections --write-timeout=$write_timeout --idle-timeout=$idle_timeout"

    if [[ "$display_banner" != "true" ]]; then
        command="$command --display-banner=false"
    fi

    if [[ "$has_ssl" == "true" ]]; then
        if [[ "$has_cert_internal" == "false" && -n "$custom_cert_path" ]]; then
            command="$command --cert=$custom_cert_path --cert-internal=false"
        else
            command="$command --cert-internal=true"
        fi
    fi

    if [[ "$any_ssh_only" == "true" ]]; then
        command="$command --ssh-only"
    fi

    echo "$command"
}

write_unified_proxy_systemd_unit() {
    local proxy_command="$1"
    local gomemlimit
    gomemlimit=$(calculate_dynamic_gomemlimit)

    sudo tee "/etc/systemd/system/${PROXY_UNIFIED_SERVICE_NAME}.service" > /dev/null <<EOF
[Unit]
Description=${PROJECT_NAME} Unified Proxy Server
After=network.target

[Service]
Environment="GOMEMLIMIT=${gomemlimit}"
Environment="GOGC=100"
ExecStart=$proxy_command
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

apply_unified_proxy_service() {
    local do_start="${1:-true}"
    local token proxy_command

    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy nao configurado. Use Gerenciar Tokens no menu inicial."
        return 1
    fi

    proxy_command=$(build_unified_proxy_command "$token")
    if [[ -z "$proxy_command" ]]; then
        if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
            print_info "Nenhuma porta ativa restante. Parando servico unificado..."
            sudo systemctl stop "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null || true
            sudo systemctl disable "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null || true
        fi
        return 0
    fi

    write_unified_proxy_systemd_unit "$proxy_command"

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
            migrate_proxy_conf_from_unit_if_needed "$port" || true
            set_proxy_conf_key "$port" "ENABLED" "true"
            sudo systemctl stop "${PROXY_SERVICE_PREFIX}-${port}" 2>/dev/null || true
            sudo systemctl disable "${PROXY_SERVICE_PREFIX}-${port}" 2>/dev/null || true
            sudo rm -f "$service_file"
        fi
    done

    if [[ "$legacy_found" == "true" ]]; then
        sudo systemctl daemon-reload
        apply_unified_proxy_service "true" || true
    fi
}

sync_all_proxy_tokens() {
    local token="$1"
    [[ -n "$token" ]] || return 0

    apply_unified_proxy_service "true"
    echo "1"
}

start_proxy_for_port() {
    local port="$1"
    local ssl_enabled="$2"
    local ssl_cert_path="$3"
    local ssh_only_flag="$4"
    local http_response="$5"
    local skip_listen_check="${6:-false}"

    if ! validate_port "$port"; then
        return 1
    fi

    if [[ "$skip_listen_check" != "true" ]]; then
        if ! check_port_available "$port"; then
            return 1
        fi
    fi

    local token
    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy nao configurado. Use Gerenciar Tokens no menu inicial."
        return 1
    fi

    local cert_internal="true"
    if [[ "$ssl_enabled" == "true" && -n "$ssl_cert_path" ]]; then
        cert_internal="false"
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ssl_cert_path" "$cert_internal" "$ssh_only_flag" \
        "$http_response" "$DEFAULT_BUFFER_SIZE" "false" "$DEFAULT_MAX_CONNECTIONS" "$DEFAULT_WRITE_TIMEOUT" "$DEFAULT_IDLE_TIMEOUT" "$DEFAULT_LOG_LEVEL" "$DEFAULT_SSH_PORT" "$DEFAULT_OPENVPN_PORT" "$DEFAULT_V2RAY_PORT" "true" "true"

    apply_unified_proxy_service "true"
}

prompt_proxy_advanced_options() {
    # Edita globals ADV_* (já inicializados). Submenu interativo completo para todas as flags.
    local choice
    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "OPÇÕES E FLAGS AVANÇADAS" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Buffer (--buffer-size): ${CYAN}${ADV_BUFFER_SIZE} bytes${RESET}"
        print_box_line "${WHITE}  2 • Idle Timeout (--idle-timeout): ${CYAN}${ADV_IDLE_TIMEOUT}s${RESET}"
        print_box_line "${WHITE}  3 • Write Timeout (--write-timeout): ${CYAN}${ADV_WRITE_TIMEOUT}s${RESET}"
        print_box_line "${WHITE}  4 • Max Conexões (--max-connections): ${CYAN}${ADV_MAX_CONNECTIONS}${RESET}"
        print_box_line "${WHITE}  5 • Resposta HTTP (--response): ${CYAN}${ADV_HTTP_RESPONSE}${RESET}"
        print_box_line "${WHITE}  6 • Modo Somente SSH (--ssh-only): ${CYAN}${ADV_SSH_ONLY}${RESET}"
        print_box_line "${WHITE}  7 • Banner no Terminal (--display-banner): ${CYAN}${ADV_DISPLAY_BANNER}${RESET}"
        print_box_line "${WHITE}  8 • Nível de Log (--log-level): ${CYAN}${ADV_LOG_LEVEL}${RESET}"
        print_box_line "${WHITE}  9 • Backends SSH/OVPN/V2Ray: ${CYAN}${ADV_SSH_PORT}/${ADV_OPENVPN_PORT}/${ADV_V2RAY_PORT}${RESET}"
        print_box_line "${WHITE}  A • Certificado SSL (--cert-internal / --cert): ${CYAN}${ADV_CERT_INTERNAL}${RESET}"
        print_box_divider
        if [[ -n "${ADV_PORT:-}" ]]; then
            print_box_line "${WHITE}  V • Ver comando ExecStart completo${RESET}"
            print_box_line "${WHITE}  S • Salvar e aplicar na porta ${CYAN}${ADV_PORT}${RESET}"
        fi
        render_menu_option "0 • Concluir / Voltar" "red"
        print_box_close
        echo

        read -rp "$(echo -e "${BLUE}Selecione a opção desejada [0-9/A/V/S]:${RESET} ")" choice
        case "${choice,,}" in
            1)
                ADV_BUFFER_SIZE=$(prompt_with_default "Buffer size em bytes (--buffer-size)" "$ADV_BUFFER_SIZE")
                if ! [[ "$ADV_BUFFER_SIZE" =~ ^[0-9]+$ ]] || [[ "$ADV_BUFFER_SIZE" -lt 1024 ]]; then
                    print_warning "Valor inválido; usando $DEFAULT_BUFFER_SIZE"
                    ADV_BUFFER_SIZE="$DEFAULT_BUFFER_SIZE"
                fi
                ;;
            2)
                ADV_IDLE_TIMEOUT=$(prompt_with_default "Tempo de inatividade em segundos (--idle-timeout)" "$ADV_IDLE_TIMEOUT")
                if ! [[ "$ADV_IDLE_TIMEOUT" =~ ^[0-9]+$ ]]; then
                    ADV_IDLE_TIMEOUT="$DEFAULT_IDLE_TIMEOUT"
                fi
                ;;
            3)
                ADV_WRITE_TIMEOUT=$(prompt_with_default "Tempo limite de escrita em segundos (--write-timeout)" "$ADV_WRITE_TIMEOUT")
                if ! [[ "$ADV_WRITE_TIMEOUT" =~ ^[0-9]+$ ]]; then
                    ADV_WRITE_TIMEOUT="$DEFAULT_WRITE_TIMEOUT"
                fi
                ;;
            4)
                ADV_MAX_CONNECTIONS=$(prompt_with_default "Limite máximo de conexões simultâneas (--max-connections, 0=ilimitado)" "$ADV_MAX_CONNECTIONS")
                if ! [[ "$ADV_MAX_CONNECTIONS" =~ ^[0-9]+$ ]]; then
                    ADV_MAX_CONNECTIONS="0"
                fi
                ;;
            5)
                ADV_HTTP_RESPONSE=$(prompt_with_default "Resposta HTTP (--response)" "$ADV_HTTP_RESPONSE")
                ;;
            6)
                if confirm_action "Habilitar modo somente SSH (--ssh-only)? (atual: $ADV_SSH_ONLY)" "$([[ "$ADV_SSH_ONLY" == "true" ]] && echo s || echo n)"; then
                    ADV_SSH_ONLY="true"
                else
                    ADV_SSH_ONLY="false"
                fi
                ;;
            7)
                if confirm_action "Exibir banner de status no terminal (--display-banner)? (atual: $ADV_DISPLAY_BANNER)" "$([[ "$ADV_DISPLAY_BANNER" == "true" ]] && echo s || echo n)"; then
                    ADV_DISPLAY_BANNER="true"
                else
                    ADV_DISPLAY_BANNER="false"
                fi
                ;;
            8)
                ADV_LOG_LEVEL=$(prompt_with_default "Nível de log (debug|info|warn|error)" "$ADV_LOG_LEVEL")
                ;;
            9)
                ADV_SSH_PORT=$(prompt_with_default "Porta backend SSH (--ssh-port)" "$ADV_SSH_PORT")
                ADV_OPENVPN_PORT=$(prompt_with_default "Porta backend OpenVPN (--openvpn-port)" "$ADV_OPENVPN_PORT")
                ADV_V2RAY_PORT=$(prompt_with_default "Porta backend V2Ray (--v2ray-port)" "$ADV_V2RAY_PORT")
                ;;
            a)
                if confirm_action "Usar certificado interno autogerado (--cert-internal)? (atual: $ADV_CERT_INTERNAL)" "$([[ "$ADV_CERT_INTERNAL" == "true" ]] && echo s || echo n)"; then
                    ADV_CERT_INTERNAL="true"
                    ADV_SSL_CERT_PATH=""
                else
                    ADV_CERT_INTERNAL="false"
                    ADV_SSL_CERT_PATH=$(prompt_with_default "Caminho do certificado externo (--cert)" "${ADV_SSL_CERT_PATH:-/etc/ssl/cert.pem}")
                fi
                ;;
            v)
                if [[ -z "${ADV_PORT:-}" ]]; then
                    print_warning "ExecStart só está disponível após escolher uma porta configurada."
                    pause
                else
                    show_proxy_execstart_line "$ADV_PORT"
                    pause
                fi
                ;;
            s)
                if [[ -z "${ADV_PORT:-}" ]]; then
                    print_warning "Sem porta selecionada — use '0' para concluir."
                    pause
                    continue
                fi
                apply_adv_globals_to_port "$ADV_PORT"
                ADV_APPLIED=1
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                print_error "Opção inválida: $choice"
                ;;
        esac
    done
}

init_adv_defaults() {
    ADV_PORT=""
    ADV_APPLIED=0
    ADV_BUFFER_SIZE="${1:-$DEFAULT_BUFFER_SIZE}"
    ADV_MAX_CONNECTIONS="${2:-$DEFAULT_MAX_CONNECTIONS}"
    ADV_WRITE_TIMEOUT="${3:-$DEFAULT_WRITE_TIMEOUT}"
    ADV_IDLE_TIMEOUT="${4:-$DEFAULT_IDLE_TIMEOUT}"
    ADV_LOG_LEVEL="${5:-$DEFAULT_LOG_LEVEL}"
    ADV_SSH_PORT="${6:-$DEFAULT_SSH_PORT}"
    ADV_OPENVPN_PORT="${7:-$DEFAULT_OPENVPN_PORT}"
    ADV_V2RAY_PORT="${8:-$DEFAULT_V2RAY_PORT}"
    ADV_DOMAIN="false"
    ADV_DISPLAY_BANNER="${10:-true}"
    ADV_CERT_INTERNAL="${11:-true}"
    ADV_SSL_CERT_PATH="${12:-}"
    ADV_HTTP_RESPONSE="${13:-$DEFAULT_HTTP_RESPONSE}"
    ADV_SSH_ONLY="${14:-false}"
    ADV_SSL_ENABLED="${15:-false}"
}

load_adv_from_port() {
    local port="$1"
    migrate_proxy_conf_from_unit_if_needed "$port" || true
    ADV_PORT="$port"
    ADV_APPLIED=0
    ADV_BUFFER_SIZE=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    ADV_MAX_CONNECTIONS=$(get_proxy_conf_value "$port" "MAX_CONNECTIONS" "$DEFAULT_MAX_CONNECTIONS")
    ADV_WRITE_TIMEOUT=$(get_proxy_conf_value "$port" "WRITE_TIMEOUT" "$DEFAULT_WRITE_TIMEOUT")
    ADV_IDLE_TIMEOUT=$(get_proxy_conf_value "$port" "IDLE_TIMEOUT" "$DEFAULT_IDLE_TIMEOUT")
    ADV_LOG_LEVEL=$(get_proxy_conf_value "$port" "LOG_LEVEL" "$DEFAULT_LOG_LEVEL")
    ADV_SSH_PORT=$(get_proxy_conf_value "$port" "SSH_PORT" "$DEFAULT_SSH_PORT")
    ADV_OPENVPN_PORT=$(get_proxy_conf_value "$port" "OPENVPN_PORT" "$DEFAULT_OPENVPN_PORT")
    ADV_V2RAY_PORT=$(get_proxy_conf_value "$port" "V2RAY_PORT" "$DEFAULT_V2RAY_PORT")
    ADV_HTTP_RESPONSE=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
    ADV_SSH_ONLY=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")
    ADV_SSL_ENABLED=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    ADV_DOMAIN="false"
    ADV_DISPLAY_BANNER=$(get_proxy_conf_value "$port" "DISPLAY_BANNER" "true")
    ADV_CERT_INTERNAL=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    ADV_SSL_CERT_PATH=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
}

show_proxy_execstart_line() {
    local port="${1:-}"
    echo
    print_info "ExecStart do servico unificado (${PROXY_UNIFIED_SERVICE_NAME}):"
    local exec_line
    exec_line=$(systemctl cat "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        echo -e "${GRAY}$exec_line${RESET}"
    else
        print_warning "Unit systemd unificada (${PROXY_UNIFIED_SERVICE_NAME}) ainda nao criada."
    fi
}

apply_adv_globals_to_port() {
    local port="$1"

    # Se marcou cert externo, forca SSL (senao --cert-internal nao faz sentido sozinho).
    if [[ "$ADV_CERT_INTERNAL" == "false" && -n "$ADV_SSL_CERT_PATH" ]]; then
        ADV_SSL_ENABLED="true"
    fi

    write_proxy_conf "$port" "$ADV_SSL_ENABLED" "$ADV_SSL_CERT_PATH" "$ADV_CERT_INTERNAL" "$ADV_SSH_ONLY" \
        "$ADV_HTTP_RESPONSE" "$ADV_BUFFER_SIZE" "false" "$ADV_MAX_CONNECTIONS" "$ADV_WRITE_TIMEOUT" \
        "$ADV_IDLE_TIMEOUT" "$ADV_LOG_LEVEL" "$ADV_SSH_PORT" "$ADV_OPENVPN_PORT" "$ADV_V2RAY_PORT" "$ADV_DISPLAY_BANNER" "true"

    if apply_unified_proxy_service "true"; then
        print_success "Opcoes avancadas aplicadas ao servico unificado."
        show_proxy_execstart_line "$port"
    else
        print_error "Falha ao aplicar opcoes avancadas."
    fi
}

edit_proxy_advanced_service() {
    print_header

    # Carrega as configuracoes globais do motor proxy
    local buffer_size max_connections write_timeout idle_timeout log_level ssh_port openvpn_port v2ray_port http_response ssh_only_flag ssl_enabled display_banner cert_internal ssl_cert_path
    buffer_size=$(get_global_proxy_setting "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    max_connections=$(get_global_proxy_setting "MAX_CONNECTIONS" "$DEFAULT_MAX_CONNECTIONS")
    write_timeout=$(get_global_proxy_setting "WRITE_TIMEOUT" "$DEFAULT_WRITE_TIMEOUT")
    idle_timeout=$(get_global_proxy_setting "IDLE_TIMEOUT" "$DEFAULT_IDLE_TIMEOUT")
    log_level=$(get_global_proxy_setting "LOG_LEVEL" "info")
    ssh_port=$(get_global_proxy_setting "SSH_PORT" "22")
    openvpn_port=$(get_global_proxy_setting "OPENVPN_PORT" "1194")
    v2ray_port=$(get_global_proxy_setting "V2RAY_PORT" "1080")
    http_response=$(get_global_proxy_setting "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
    ssh_only_flag=$(get_global_proxy_setting "SSH_ONLY" "false")
    display_banner=$(get_global_proxy_setting "DISPLAY_BANNER" "true")
    cert_internal=$(get_global_proxy_setting "CERT_INTERNAL" "true")
    ssl_cert_path=$(get_global_proxy_setting "SSL_CERT_PATH" "")
    ssl_enabled=$(get_global_proxy_setting "SSL_ENABLED" "false")

    init_adv_defaults "$buffer_size" "$max_connections" "$write_timeout" "$idle_timeout" "$log_level" "$ssh_port" "$openvpn_port" "$v2ray_port" "false" "$display_banner" "$cert_internal" "$ssl_cert_path" "$http_response" "$ssh_only_flag" "$ssl_enabled"

    prompt_proxy_advanced_options

    # Aplica as novas opcoes globais a todas as portas configuradas
    local configured_ports port
    configured_ports=$(list_configured_proxy_ports)
    if [[ -n "$configured_ports" ]]; then
        IFS=',' read -ra port_array <<< "$configured_ports"
        for port in "${port_array[@]}"; do
            [[ -z "$port" ]] && continue
            set_proxy_conf_key "$port" "BUFFER_SIZE" "$ADV_BUFFER_SIZE"
            set_proxy_conf_key "$port" "MAX_CONNECTIONS" "$ADV_MAX_CONNECTIONS"
            set_proxy_conf_key "$port" "WRITE_TIMEOUT" "$ADV_WRITE_TIMEOUT"
            set_proxy_conf_key "$port" "IDLE_TIMEOUT" "$ADV_IDLE_TIMEOUT"
            set_proxy_conf_key "$port" "LOG_LEVEL" "$ADV_LOG_LEVEL"
            set_proxy_conf_key "$port" "SSH_PORT" "$ADV_SSH_PORT"
            set_proxy_conf_key "$port" "OPENVPN_PORT" "$ADV_OPENVPN_PORT"
            set_proxy_conf_key "$port" "V2RAY_PORT" "$ADV_V2RAY_PORT"
            set_proxy_conf_key "$port" "HTTP_RESPONSE" "$ADV_HTTP_RESPONSE"
            set_proxy_conf_key "$port" "SSH_ONLY" "$ADV_SSH_ONLY"
            set_proxy_conf_key "$port" "DISPLAY_BANNER" "$ADV_DISPLAY_BANNER"
        done
    fi

    if apply_unified_proxy_service "true"; then
        print_success "Opcoes avancadas globais aplicadas ao servico unificado."
        show_proxy_execstart_line
    else
        print_error "Falha ao aplicar opcoes avancadas."
    fi
    pause
}

change_proxy_http_response() {
    print_header

    local current_response
    current_response=$(get_global_proxy_setting "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")

    echo -e "${BLUE}Resposta HTTP atual do motor proxy: ${GREEN}$current_response${RESET}"
    local new_response
    new_response=$(prompt_with_default "Nova resposta HTTP (--response)" "$current_response")
    new_response=$(echo "$new_response" | tr -d '[:space:]')

    if [[ -z "$new_response" ]]; then
        print_error "Resposta nao pode ser vazia."
        pause
        return
    fi

    local configured_ports port
    configured_ports=$(list_configured_proxy_ports)
    if [[ -n "$configured_ports" ]]; then
        IFS=',' read -ra port_array <<< "$configured_ports"
        for port in "${port_array[@]}"; do
            [[ -z "$port" ]] && continue
            set_proxy_conf_key "$port" "HTTP_RESPONSE" "$new_response"
        done
    fi

    if apply_unified_proxy_service "true"; then
        print_success "Resposta HTTP global do proxy atualizada para '$new_response'."
    else
        print_error "Falha ao aplicar alteracao de resposta HTTP."
    fi
    pause
}

# Alias legado
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

    if is_proxy_service_configured "$port"; then
        if ! confirm_action "Porta $port ja configurada. Sobrescrever?" "n"; then
            pause
            return
        fi
    fi
    
    local ssl_enabled="false"
    local ssl_cert_path=""
    local cert_internal="true"
    
    if confirm_action "Deseja habilitar SSL nesta porta?" "n"; then
        ssl_enabled="true"
        if confirm_action "Usar certificado interno seguro Cloudflare (--cert-internal)?" "s"; then
            cert_internal="true"
        else
            cert_internal="false"
            echo -e "${BLUE}Caminho do certificado SSL:${RESET}"
            read -rp "> " ssl_cert_path
        fi
    fi
    
    # Herda automaticamente as configuracoes globais do motor proxy
    local http_response buffer_size ssh_only_flag max_connections write_timeout idle_timeout log_level ssh_port openvpn_port v2ray_port display_banner
    http_response=$(get_global_proxy_setting "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
    buffer_size=$(get_global_proxy_setting "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    ssh_only_flag=$(get_global_proxy_setting "SSH_ONLY" "false")
    max_connections=$(get_global_proxy_setting "MAX_CONNECTIONS" "$DEFAULT_MAX_CONNECTIONS")
    write_timeout=$(get_global_proxy_setting "WRITE_TIMEOUT" "$DEFAULT_WRITE_TIMEOUT")
    idle_timeout=$(get_global_proxy_setting "IDLE_TIMEOUT" "$DEFAULT_IDLE_TIMEOUT")
    log_level=$(get_global_proxy_setting "LOG_LEVEL" "info")
    ssh_port=$(get_global_proxy_setting "SSH_PORT" "22")
    openvpn_port=$(get_global_proxy_setting "OPENVPN_PORT" "1194")
    v2ray_port=$(get_global_proxy_setting "V2RAY_PORT" "1080")
    display_banner=$(get_global_proxy_setting "DISPLAY_BANNER" "true")

    print_info "Iniciando porta $port no serviço unificado..."

    local token
    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy nao configurado. Use Gerenciar Tokens no menu inicial."
        pause
        return
    fi

    if ! check_port_available "$port"; then
        pause
        return
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ssl_cert_path" "$cert_internal" "$ssh_only_flag" \
        "$http_response" "$buffer_size" "false" "$max_connections" "$write_timeout" \
        "$idle_timeout" "$log_level" "$ssh_port" "$openvpn_port" "$v2ray_port" "$display_banner" "true"

    if apply_unified_proxy_service "true"; then
        print_success "Proxy unificado iniciado com sucesso contendo a porta $port!"
        show_proxy_execstart_line "$port"
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
    echo -e "${BLUE}Digite a porta para PARAR (mantem configuracao):${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta invalida ou nao configurada."
        pause
        return
    fi

    print_info "Pausando porta $port (config preservada)..."
    set_proxy_conf_key "$port" "ENABLED" "false"
    apply_unified_proxy_service "true"
    print_success "Porta $port pausada. As demais portas continuam ativas no servico unificado."
    pause
}

remove_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para REMOVER (apaga conf):${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta invalida ou nao configurada."
        pause
        return
    fi

    if ! confirm_action "Remover definitivamente a porta $port?" "n"; then
        pause
        return
    fi

    print_info "Removendo porta $port..."
    sudo rm -f "$(get_proxy_config_file "$port")"
    apply_unified_proxy_service "true"
    print_success "Porta $port removida do servico unificado."
    pause
}

# Compat: "fechar" antigo = remover
stop_proxy_service() {
    remove_proxy_service
}

start_configured_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta configurada. Use 'Abrir / criar porta'."
        pause
        return
    fi

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta configurada para iniciar:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta invalida ou nao configurada."
        pause
        return
    fi

    local enabled
    enabled=$(get_proxy_conf_value "$port" "ENABLED" "true")
    if [[ "$enabled" == "true" ]] && systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null; then
        print_warning "Porta $port ja esta ativa no servico unificado."
        pause
        return
    fi

    if ! check_port_available "$port"; then
        pause
        return
    fi

    print_info "Ativando porta $port no servico unificado..."
    set_proxy_conf_key "$port" "ENABLED" "true"
    if apply_unified_proxy_service "true"; then
        print_success "Porta $port ativada no servico unificado."
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

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para editar:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta invalida ou nao configurada."
        pause
        return
    fi

    local ssl_enabled ssl_cert_path cert_internal enabled
    ssl_enabled=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    ssl_cert_path=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
    cert_internal=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    enabled=$(get_proxy_conf_value "$port" "ENABLED" "true")

    echo -e "${BLUE}Configuracoes atuais da porta $port:${RESET}"
    echo -e "  1 - Status da Porta: ${CYAN}$(if [[ "$enabled" == "true" ]]; then echo "Ativada"; else echo "Pausada"; fi)${RESET}"
    echo -e "  2 - SSL Habilitado: ${CYAN}$ssl_enabled${RESET}"
    echo -e "  3 - Certificado Interno Cloudflare: ${CYAN}$cert_internal${RESET}"
    [[ -n "$ssl_cert_path" ]] && echo -e "  4 - Caminho do Certificado: ${CYAN}$ssl_cert_path${RESET}"
    echo

    echo -e "${BLUE}Escolha o que deseja alterar na porta $port:${RESET}"
    echo -e "  1 - Alternar Status (Ativar / Pausar)"
    echo -e "  2 - Alterar opcoes de SSL / Certificado"
    echo -e "  0 - Voltar"
    read -rp "> " edit_choice

    case "$edit_choice" in
        1)
            if [[ "$enabled" == "true" ]]; then
                print_info "Pausando porta $port..."
                set_proxy_conf_key "$port" "ENABLED" "false"
            else
                print_info "Ativando porta $port..."
                set_proxy_conf_key "$port" "ENABLED" "true"
            fi
            apply_unified_proxy_service "true"
            print_success "Status da porta $port atualizado com sucesso."
            ;;
        2)
            if confirm_action "Habilitar SSL na porta $port?" "$ssl_enabled"; then
                set_proxy_conf_key "$port" "SSL_ENABLED" "true"
                if confirm_action "Usar certificado interno seguro Cloudflare (--cert-internal)?" "s"; then
                    set_proxy_conf_key "$port" "CERT_INTERNAL" "true"
                    set_proxy_conf_key "$port" "SSL_CERT_PATH" ""
                else
                    set_proxy_conf_key "$port" "CERT_INTERNAL" "false"
                    echo -e "${BLUE}Caminho do certificado SSL:${RESET}"
                    read -rp "> " ssl_cert_path
                    set_proxy_conf_key "$port" "SSL_CERT_PATH" "$ssl_cert_path"
                fi
            else
                set_proxy_conf_key "$port" "SSL_ENABLED" "false"
                set_proxy_conf_key "$port" "CERT_INTERNAL" "true"
                set_proxy_conf_key "$port" "SSL_CERT_PATH" ""
            fi
            apply_unified_proxy_service "true"
            print_success "Opcoes de SSL da porta $port atualizadas."
            ;;
        0) return 0 ;;
        *) print_error "Opcao invalida." ;;
    esac
    pause
}

show_proxy_port_details() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta configurada."
        pause
        return
    fi

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para ver detalhes:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta invalida ou nao configurada."
        pause
        return
    fi

    migrate_proxy_conf_from_unit_if_needed "$port" || true

    local service_name conf_file
    service_name=$(get_proxy_service_name "$port")
    conf_file=$(get_proxy_config_file "$port")

    echo
    print_box_open
    print_box_heading "DETALHES PORTA $port"
    print_box_divider

    local port_is_active=false
    local port_enabled
    port_enabled=$(get_proxy_conf_value "$port" "ENABLED" "true")
    if systemctl is-active --quiet "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null && [[ "$port_enabled" == "true" ]]; then
        port_is_active=true
    elif systemctl is-active --quiet "$service_name" 2>/dev/null; then
        port_is_active=true
    fi

    if [[ "$port_is_active" == "true" ]]; then
        print_box_line "${WHITE}  Estado: ${GREEN}ATIVO${RESET}"
    else
        print_box_line "${WHITE}  Estado: ${RED}PARADO${RESET}"
    fi
    print_box_line "${WHITE}  SSL: ${CYAN}$(get_proxy_conf_value "$port" SSL_ENABLED false)${RESET}"
    print_box_line "${WHITE}  Cert interno: ${CYAN}$(get_proxy_conf_value "$port" CERT_INTERNAL true)${RESET}"
    print_box_line "${WHITE}  Cert path: ${CYAN}$(get_proxy_conf_value "$port" SSL_CERT_PATH "-")${RESET}"
    print_box_line "${WHITE}  SSH-only: ${CYAN}$(get_proxy_conf_value "$port" SSH_ONLY false)${RESET}"
    print_box_line "${WHITE}  Response: ${CYAN}$(get_proxy_conf_value "$port" HTTP_RESPONSE "$DEFAULT_HTTP_RESPONSE")${RESET}"
    print_box_line "${WHITE}  Buffer: ${CYAN}$(get_proxy_conf_value "$port" BUFFER_SIZE "$DEFAULT_BUFFER_SIZE")${RESET}"
    print_box_line "${WHITE}  Max conn: ${CYAN}$(get_proxy_conf_value "$port" MAX_CONNECTIONS 0)${RESET}"
    print_box_line "${WHITE}  Timeouts W/I: ${CYAN}$(get_proxy_conf_value "$port" WRITE_TIMEOUT 0)/$(get_proxy_conf_value "$port" IDLE_TIMEOUT 0)${RESET}"
    print_box_line "${WHITE}  Log level: ${CYAN}$(get_proxy_conf_value "$port" LOG_LEVEL info)${RESET}"
    print_box_line "${WHITE}  Backends SSH/OVPN/V2Ray: ${CYAN}$(get_proxy_conf_value "$port" SSH_PORT 22)/$(get_proxy_conf_value "$port" OPENVPN_PORT 1194)/$(get_proxy_conf_value "$port" V2RAY_PORT 1080)${RESET}"
    print_box_line "${WHITE}  Conf: ${CYAN}$conf_file${RESET}"
    print_box_line "${WHITE}  Log/banner file: ${CYAN}$(get_proxy_log_file "$port")${RESET}"
    print_box_divider
    local exec_line
    exec_line=$(systemctl cat "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        print_box_line "${WHITE}  ExecStart (${PROXY_UNIFIED_SERVICE_NAME}):${RESET}"
        echo -e "${GRAY}$exec_line${RESET}"
    else
        print_box_line "${YELLOW}  Unit systemd unificada (${PROXY_UNIFIED_SERVICE_NAME}) ainda nao criada${RESET}"
    fi
    print_box_close
    pause
}

restart_proxy_service() {
    print_header

    print_info "Reiniciando servico unificado de proxy (${PROXY_UNIFIED_SERVICE_NAME})..."

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
        print_warning "O servico unificado de proxy ($PROXY_UNIFIED_SERVICE_NAME) esta ATIVO."
        if confirm_action "Deseja PARAR o servico unificado de proxy?" "n"; then
            print_info "Parando servico unificado..."
            sudo systemctl stop "$PROXY_UNIFIED_SERVICE_NAME" 2>/dev/null || true
            print_success "Servico unificado de proxy parado."
        fi
    else
        print_info "O servico unificado de proxy ($PROXY_UNIFIED_SERVICE_NAME) esta PARADO."
        if confirm_action "Deseja INICIAR o servico unificado de proxy?" "s"; then
            print_info "Iniciando servico unificado..."
            if apply_unified_proxy_service "true"; then
                print_success "Servico unificado de proxy iniciado com sucesso!"
                show_proxy_execstart_line
            else
                print_error "Falha ao iniciar servico unificado de proxy."
            fi
        fi
    fi
    pause
}


show_proxy_logs() {
    print_header
    local log_file="$PROXY_LOG_DIR/proxy.log"
    print_info "Exibindo logs do servico unificado (${PROXY_UNIFIED_SERVICE_NAME})..."
    echo -e "${GRAY}Arquivo: $log_file | Pressione Ctrl+C para sair${RESET}"
    echo
    if [[ -f "$log_file" ]]; then
        sudo tail -n 80 -f "$log_file" || true
    else
        sudo journalctl -u "$PROXY_UNIFIED_SERVICE_NAME" -n 80 -f 2>/dev/null || print_warning "Sem logs disponiveis."
    fi
    pause
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
            "2 — $(t proxy_opt_edit)"
            "3 — $(t proxy_opt_remove)"
            "4 — $(t proxy_opt_restart)"
            "5 — Parar / Iniciar serviço proxy unificado"
            "6 — $(t proxy_opt_adv)"
            "7 — $(t proxy_opt_http)"
            "8 — $(t proxy_opt_details)"
            "9 — $(t proxy_opt_logs)"
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
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-9"):${RESET} ")" choice
        
        case "$choice" in
            1) start_proxy_service ;;
            2) edit_proxy_service ;;
            3) remove_proxy_service ;;
            4) restart_proxy_service ;;
            5) toggle_unified_proxy_service ;;
            6) edit_proxy_advanced_service ;;
            7) change_proxy_http_response ;;
            8) show_proxy_port_details ;;
            9) show_proxy_logs ;;
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

    write_proxy_conf "80" "false" "" "true" "false" "$DEFAULT_HTTP_RESPONSE" \
        "$DEFAULT_BUFFER_SIZE" "false" "$DEFAULT_MAX_CONNECTIONS" "$DEFAULT_WRITE_TIMEOUT" \
        "$DEFAULT_IDLE_TIMEOUT" "$DEFAULT_LOG_LEVEL" "$DEFAULT_SSH_PORT" "$DEFAULT_OPENVPN_PORT" "$DEFAULT_V2RAY_PORT" "true" "true"

    write_proxy_conf "443" "true" "" "true" "false" "$DEFAULT_HTTP_RESPONSE" \
        "$DEFAULT_BUFFER_SIZE" "false" "$DEFAULT_MAX_CONNECTIONS" "$DEFAULT_WRITE_TIMEOUT" \
        "$DEFAULT_IDLE_TIMEOUT" "$DEFAULT_LOG_LEVEL" "$DEFAULT_SSH_PORT" "$DEFAULT_OPENVPN_PORT" "$DEFAULT_V2RAY_PORT" "true" "true"

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
    local json tag
    json=$(curl -fsSL \
        -H "Cache-Control: no-cache" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${UDPGW_REPO}/releases/latest" 2>/dev/null || true)
    tag=$(echo "$json" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')
    [[ -n "$tag" ]] && echo "$tag"
}

download_udpgw_binary() {
    local tag="${1:-}"
    local arch filename url tmp http_status sums_url expected actual

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
    http_status=$(curl -fsSL -w "%{http_code}" -o "$tmp" "$url" 2>/dev/null || true)
    if [[ "$http_status" != "200" || ! -s "$tmp" ]]; then
        rm -f "$tmp"
        print_error "Falha ao baixar ${filename} (HTTP ${http_status:-000})."
        print_info "Release: https://github.com/${UDPGW_REPO}/releases/tag/${tag}"
        return 1
    fi

    sums_url="https://github.com/${UDPGW_REPO}/releases/download/${tag}/SHA256SUMS"
    if http_status=$(curl -fsSL -w "%{http_code}" -o "${tmp}.sums" "$sums_url" 2>/dev/null || true) && [[ "$http_status" == "200" ]]; then
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

    if [[ "$ssh_onlines" == "0" ]]; then
        echo "$(t ssh_no_users)"
    else
        pgrep -f 'sshd:' 2>/dev/null \
            | xargs -r ps -o user=,pid=,etime= 2>/dev/null \
            | grep -v '^root ' \
            | sort -u \
            | while read -r user pid etime; do
                t ssh_user_row "$user" "$pid" "$etime"
                echo
            done
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
        render_menu_option "0 • $(t ssh_opt_back)" "red"
        print_box_close
        echo

        local option
        read -rp "$(echo -e "${BLUE}$(t prompt_select_option "0-1"):${RESET} ")" option
        case "$option" in
            1) show_ssh_online_users_details ;;
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

    if [[ -x "$MENU_BIN" ]]; then
        echo
        print_warning "Recarregando o novo menu vt..."
        pause
        exec "$MENU_BIN"
    fi

    pause
    return 0
}

update_system_menu() {
    print_header

    local proxy_ver udpgw_ver
    proxy_ver=$(get_installed_proxy_version_label)
    udpgw_ver=$(get_installed_udpgw_version_label)

    print_box_open
    print_box_heading "$(t update_menu_title)" "$CYAN"
    print_box_divider
    print_box_line "${WHITE}  $(t update_installed_proxy "${GREEN}v${proxy_ver}")"
    print_box_line "${WHITE}  $(t update_installed_udpgw "${GREEN}v${udpgw_ver}")"
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
    local sysctl_conf="/etc/sysctl.d/99-veltrix-proxy.conf"

    sudo rm -f /etc/sysctl.d/99-vtproxy.conf /etc/sysctl.d/zz-custom-network.conf 2>/dev/null || true
    sudo mkdir -p /etc/sysctl.d 2>/dev/null || true

    if [[ -f /etc/sysctl.conf ]]; then
        sudo sed -i -E '/^(net\.core\.(somaxconn|rmem_max|wmem_max|rmem_default|wmem_default|netdev_max_backlog|default_qdisc)|net\.ipv4\.(tcp_tw_reuse|tcp_fin_timeout|tcp_max_tw_buckets|ip_local_port_range|tcp_max_syn_backlog|tcp_slow_start_after_idle|tcp_fastopen|tcp_rmem|tcp_wmem|tcp_congestion_control))/d' /etc/sysctl.conf 2>/dev/null || true
    fi

    cat << 'EOF' | sudo tee "$sysctl_conf" >/dev/null
# VTProxy / VeltrixProxy Network & Kernel Optimizations
net.ipv4.ip_forward = 1

# === 1. Reciclagem Rápida de Sockets (Vital para BHTTP e XHTTP) ===
# Permite reusar portas em TIME_WAIT de forma segura sem colisão
net.ipv4.tcp_tw_reuse = 1
# Reduz o tempo de vida de conexões mortas de 60s para 15s (libera RAM 4x mais rápido)
net.ipv4.tcp_fin_timeout = 15
# Limite seguro de sockets em TIME_WAIT na memória (ocupa no máximo ~30 MB)
net.ipv4.tcp_max_tw_buckets = 131072

# === 2. Expansão de Portas Locais ===
# Libera mais de 55.000 portas para conectar ao OpenSSH, V2Ray e OpenVPN locais
net.ipv4.ip_local_port_range = 10240 65535

# === 3. Filas de Conexão (Evita 'Connection Refused' nos disparos do BHTTP) ===
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 8192

# === 4. Desempenho e Latência ===
# Não reseta a janela de velocidade para o mínimo após pequenas pausas
net.ipv4.tcp_slow_start_after_idle = 0
# Acelera o handshake inicial
net.ipv4.tcp_fastopen = 3

# === 5. Auto-Tuning de Memória Seguro (Mínimo Leve, Escala se Precisar) ===
# O socket inicia leve (4KB a 64KB) e só cresce até 8MB se o cliente tiver muita banda
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608

# === 6. Algoritmo BBR do Google (Mais velocidade em conexões móveis 4G/5G) ===
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
        "net.ipv4.ip_local_port_range=10240 65535"
        "net.core.somaxconn=8192"
        "net.ipv4.tcp_max_syn_backlog=8192"
        "net.core.netdev_max_backlog=8192"
        "net.ipv4.tcp_slow_start_after_idle=0"
        "net.ipv4.tcp_fastopen=3"
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
}

if [[ "$1" == "--migrate" ]]; then
    migrate_legacy_services_to_unified || true
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


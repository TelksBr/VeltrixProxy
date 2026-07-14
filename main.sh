#!/bin/bash

declare -A COLORS=(
    ["INFO"]="\033[1;36m"
    ["WARN"]="\033[1;33m"
    ["ERROR"]="\033[1;31m"
    ["SUCCESS"]="\033[1;32m"
    ["TITLE"]="\033[1;34m"
    ["PROMPT"]="\033[1;33m"
    ["RESET"]="\033[0m"
)

declare -A EMOJIS=(
    ["INFO"]="ℹ️"
    ["WARN"]="⚠️"
    ["ERROR"]="❌"
    ["SUCCESS"]="✅"
    ["TITLE"]="✨"
    ["PROMPT"]="👉"
    ["SSL"]="🔐"
    ["CERT"]="📄"
    ["SSH"]="🔒"
    ["LOG"]="📜"
    ["EXIT"]="👋"
)

readonly TOKEN_PATH="$HOME/.proxy_token"
readonly MENU_BOX_WIDTH=29

resolve_proxy_executable() {
    if [[ -x "/usr/local/bin/proxy-server" ]]; then
        echo "/usr/local/bin/proxy-server"
    elif [[ -x "/usr/local/bin/proxy" ]]; then
        echo "/usr/local/bin/proxy"
    else
        echo "/usr/local/bin/proxy-server"
    fi
}

readonly PROXY_EXECUTABLE="$(resolve_proxy_executable)"
readonly PROJECT_NAME="VTProxy"
readonly LOG_PATH="/var/log/proxy"
readonly SYSTEMD_SERVICE_PATH="/etc/systemd/system"
readonly DEFAULT_BUFFER_SIZE=32768
readonly DEFAULT_HTTP_RESPONSE="$PROJECT_NAME"
readonly MIN_PORT=1
readonly MAX_PORT=65535

print_message() {
    local type="$1"
    local message="$2"
    echo -e "${COLORS[$type]}${EMOJIS[$type]} $message${COLORS[RESET]}" >&2
}

format_prompt() {
    echo -e "${COLORS[PROMPT]}${EMOJIS[PROMPT]} $1${COLORS[RESET]}"
}

read_input() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local value

    if [[ -n "$default_value" ]]; then
        read -rp "$(format_prompt "$prompt_text") [$default_value]: " value
        echo "${value:-$default_value}"
    else
        read -rp "$(format_prompt "$prompt_text"): " value
        echo "$value"
    fi
}

confirm_action() {
    local default_answer="${1:-n}"
    local question="$2"
    local answer

    while true; do
        read -rp "$question (s/n) [$default_answer]: " answer
        answer=${answer:-$default_answer}
        case "${answer,,}" in
        s | sim) return 0 ;;
        n | nao | não) return 1 ;;
        *) print_message "ERROR" "Resposta inválida. Use 's' para sim ou 'n' para não." ;;
        esac
    done
}

wait_for_enter() {
    read -rp "$(format_prompt 'Pressione Enter para continuar...')" _
}

get_service_name() {
    echo "proxy-$1"
}

get_service_file_path() {
    echo "$SYSTEMD_SERVICE_PATH/$(get_service_name "$1").service"
}

get_log_file_path() {
    echo "$LOG_PATH/proxy-$1.log"
}

is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    ((port >= MIN_PORT && port <= MAX_PORT))
}

is_port_in_use() {
    local port="$1"
    ss -tuln | grep -q ":$port "
}

is_service_running() {
    local service_name
    service_name=$(get_service_name "$1")
    systemctl is-active --quiet "$service_name"
}

is_service_configured() {
    local service_name service_file_path
    service_name=$(get_service_name "$1")
    service_file_path=$(get_service_file_path "$1")

    [[ -f "$service_file_path" ]] && return 0
    systemctl cat "$service_name" &>/dev/null
}

resolve_log_file_path() {
    local port="$1"
    local default_path service_name exec_start resolved

    default_path=$(get_log_file_path "$port")
    [[ -f "$default_path" ]] && echo "$default_path" && return 0

    service_name=$(get_service_name "$port")
    exec_start=$(systemctl show "$service_name" -p ExecStart --value 2>/dev/null || true)
    if [[ "$exec_start" == *"--log-file="* ]]; then
        resolved="${exec_start#*--log-file=}"
        resolved="${resolved%% *}"
        [[ -n "$resolved" ]] && echo "$resolved" && return 0
    fi

    echo "$default_path"
}

read_token_from_file() {
    [[ -f "$TOKEN_PATH" ]] && cat "$TOKEN_PATH" || echo ""
}

validate_access_token() {
    "$PROXY_EXECUTABLE" --token "$1" --validate >/dev/null 2>&1
}

prompt_for_token_if_missing() {
    local token
    token=$(read_token_from_file)

    if [[ -z "$token" ]]; then
        clear
        print_message "WARN" "Token de acesso do ${PROJECT_NAME} não encontrado."

        while true; do
            token=$(read_input "Por favor, insira seu token")
            if validate_access_token "$token"; then
                echo "$token" >"$TOKEN_PATH"
                print_message "SUCCESS" "Token salvo em $TOKEN_PATH."
                return
            fi
            print_message "ERROR" "Token inválido. Por favor, forneça um token válido."
        done
    fi
}

ask_for_port() {
    local operation="$1"
    local port

    while true; do
        port=$(read_input "Porta")

        if ! is_valid_port "$port"; then
            print_message "ERROR" "Porta inválida. Deve estar entre $MIN_PORT e $MAX_PORT."
            continue
        fi

        if [[ "$operation" == "start" ]] && is_port_in_use "$port"; then
            print_message "ERROR" "Porta $port já está em uso."
            continue
        fi

        if [[ "$operation" != "start" ]] && ! is_service_configured "$port"; then
            print_message "ERROR" "Nenhum serviço configurado na porta $port."
            continue
        fi

        if [[ "$operation" == "restart" ]] && ! is_service_running "$port"; then
            print_message "WARN" "Serviço na porta $port existe, mas não está em execução (pode estar falhando)."
        fi

        echo "$port"
        return
    done
}

build_service_file() {
    local port="$1"
    local token="$2"
    local ssl_enabled="$3"
    local ssl_cert_path="$4"
    local ssh_only_flag="$5"
    local http_response="$6"
    local service_file_path

    service_file_path=$(get_service_file_path "$port")

    cat >"$service_file_path" <<EOF
[Unit]
Description=${PROJECT_NAME} Server na porta $port

[Service]
ExecStart=$PROXY_EXECUTABLE --token=$token --port=$port$ssl_enabled $ssl_cert_path $ssh_only_flag --buffer-size=$DEFAULT_BUFFER_SIZE --response=$http_response --domain --log-file=$(get_log_file_path "$port")
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

start_proxy_service() {
    local port ssl_enabled="" ssl_cert_path="" ssh_only_flag="" http_response token

    port=$(ask_for_port "start") || return
    token=$(read_token_from_file)

    if confirm_action "n" "$(format_prompt "${EMOJIS[SSL]} Deseja habilitar SSL?")"; then
        ssl_enabled=":ssl"
        if ! confirm_action "s" "$(format_prompt "${EMOJIS[CERT]} Usar certificado interno?")"; then
            ssl_cert_path=$(read_input "Caminho do certificado SSL")
            [[ -n "$ssl_cert_path" ]] && ssl_cert_path="--cert=$ssl_cert_path"
        fi
    fi

    http_response=$(read_input "Resposta HTTP padrão" "$DEFAULT_HTTP_RESPONSE")

    if confirm_action "n" "$(format_prompt "${EMOJIS[SSH]} Habilitar modo somente SSH?")"; then
        ssh_only_flag="--ssh-only"
    fi

    build_service_file "$port" "$token" "$ssl_enabled" "$ssl_cert_path" "$ssh_only_flag" "$http_response"

    mkdir -p "$LOG_PATH"
    systemctl daemon-reload
    systemctl start "$(get_service_name "$port")"
    systemctl enable "$(get_service_name "$port")"

    print_message "SUCCESS" "Proxy iniciado na porta $port."
    wait_for_enter
}

restart_proxy_service() {
    local port service_name
    port=$(ask_for_port "restart") || return
    service_name=$(get_service_name "$port")
    systemctl restart "$service_name"

    print_message "SUCCESS" "Proxy na porta $port reiniciado."
    wait_for_enter
}

stop_proxy_service() {
    local port service_name service_file_path
    port=$(ask_for_port "stop") || return
    service_name=$(get_service_name "$port")
    service_file_path=$(get_service_file_path "$port")

    systemctl stop "$service_name"
    systemctl disable "$service_name"
    rm -f "$service_file_path"
    systemctl daemon-reload

    print_message "SUCCESS" "Proxy na porta $port foi encerrado."
    wait_for_enter
}

show_proxy_logs() {
    local port proxy_log_file
    port=$(ask_for_port "logs") || return
    proxy_log_file=$(resolve_log_file_path "$port")

    if [[ ! -f "$proxy_log_file" ]]; then
        print_message "ERROR" "Arquivo de log não encontrado: $proxy_log_file"
        print_message "INFO" "Verifique: systemctl status $(get_service_name "$port")"
        wait_for_enter
        return
    fi

    trap 'break' INT
    while :; do
        clear
        cat "$proxy_log_file"
        echo -e "\nPressione ${COLORS[WARN]}Ctrl+C${COLORS[RESET]} para retornar ao menu."
        sleep 1
    done
    trap - INT
}

list_active_proxies() {
    systemctl list-units --type=service --all --no-legend 'proxy-*.service' 2>/dev/null \
        | awk '{print $1}' \
        | grep -oE 'proxy-[0-9]+' \
        | cut -d'-' -f2 \
        | sort -nu \
        | tr '\n' ' '
}

menu_box_title() {
    local title="$1"
    local pad_left=$(( (MENU_BOX_WIDTH - ${#title}) / 2 ))
    local pad_right=$(( MENU_BOX_WIDTH - ${#title} - pad_left ))
    echo -e "${COLORS[TITLE]}║${COLORS[SUCCESS]}$(printf '%*s' $pad_left '')${title}$(printf '%*s' $pad_right '')${COLORS[TITLE]}║${COLORS[RESET]}"
}

menu_box_separator() {
    echo -e "${COLORS[TITLE]}╠$(printf '═%.0s' {1..29})╣${COLORS[RESET]}"
}

menu_option_row() {
    local num="$1"
    local label="$2"
    local label_color="${3:-${COLORS[ERROR]}}"
    local visible="[${num}] • ${label}"
    local pad=$(( MENU_BOX_WIDTH - ${#visible} ))
    (( pad < 0 )) && pad=0
    echo -e "${COLORS[TITLE]}║${COLORS[INFO]}[${COLORS[SUCCESS]}${num}${COLORS[INFO]}] ${COLORS[SUCCESS]}• ${label_color}${label}$(printf '%*s' $pad '')${COLORS[TITLE]}║${COLORS[RESET]}"
}

display_menu() {
    local active_ports usage_line pad
    echo -e "${COLORS[TITLE]}╔$(printf '═%.0s' {1..29})╗${COLORS[RESET]}"
    menu_box_title "$PROJECT_NAME"
    menu_box_separator

    active_ports=$(list_active_proxies)
    if [[ -n "$active_ports" ]]; then
        usage_line="Em uso: ${active_ports}"
        pad=$(( MENU_BOX_WIDTH - ${#usage_line} ))
        (( pad < 0 )) && pad=0
        echo -e "${COLORS[TITLE]}║${COLORS[SUCCESS]}Em uso:${COLORS[WARN]} ${active_ports}$(printf '%*s' $pad '')${COLORS[TITLE]}║${COLORS[RESET]}"
        menu_box_separator
    fi

    menu_option_row "01" "ABRIR PORTA"
    menu_option_row "02" "FECHAR PORTA"
    menu_option_row "03" "REINICIAR PORTA"
    menu_option_row "04" "VER LOG DA PORTA"
    menu_option_row "00" "SAIR" "${COLORS[WARN]}"
    echo -e "${COLORS[TITLE]}╚$(printf '═%.0s' {1..29})╝${COLORS[RESET]}"
}

main() {
    prompt_for_token_if_missing

    while true; do
        clear
        display_menu
        local choice
        choice=$(read_input "Digite sua opção")

        case "$choice" in
        1 | 01) start_proxy_service ;;
        2 | 02) stop_proxy_service ;;
        3 | 03) restart_proxy_service ;;
        4 | 04) show_proxy_logs ;;
        0 | 00)
            print_message "EXIT" "Saindo do ${PROJECT_NAME}. Até logo!"
            exit 0
            ;;
        *)
            print_message "ERROR" "Opção inválida."
            wait_for_enter
            ;;
        esac
    done
}

main

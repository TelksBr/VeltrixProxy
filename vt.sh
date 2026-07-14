#!/bin/bash

readonly PROJECT_NAME="VTProxy"
readonly MENU_BOX_WIDTH=62

PROTO_SERVER_BIN="/usr/local/bin/proto-server"
TOKEN_FILE="/etc/proto-server/token"
CONFIG_FILE="/etc/proto-server/config.conf"
DATA_DIR="/var/lib/proto-server"
CREDENTIALS_FILE="$DATA_DIR/credentials.json"
STATS_FILE="$DATA_DIR/stats.json"
CERTIFICATE_SSL_FILE="$DATA_DIR/cert.pem"
PRIVATE_KEY_SSL_FILE="$DATA_DIR/key.pem"
SERVICE_NAME="proto-server"
FIRST_RUN_MARKER="$DATA_DIR/.quick-setup-done"
QUICK_SETUP_ASKED_KEY="QUICK_SETUP_ASKED"
ONLINE_API_SERVICE_NAME="proto-online-api"
ONLINE_API_SCRIPT="/usr/local/bin/proto_online_api.py"
ONLINE_API_PORT_FILE="/etc/proto-server/online_api_port"

PROXY_DIR="/etc/proxy"
PROXY_TOKEN_VTPROXY="/etc/vtproxy/proxy.token"
PROXY_TOKEN_FILE="$PROXY_DIR/token"
PROXY_TOKEN_HOME="${HOME:-/root}/.proxy_token"
PROXY_CONFIG_DIR="$PROXY_DIR/conf.d"
PROXY_LOG_DIR="/var/log/proxy"
PROXY_SERVICE_PREFIX="proxy"

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

AUTH_MODE_FILE="file"
AUTH_MODE_URL="url"
AUTH_MODE_SSH="ssh"
AUTH_MODE_NONE="none"

DEFAULT_BUFFER_SIZE=32768
DEFAULT_HTTP_RESPONSE="$PROJECT_NAME"
MIN_PORT=1
MAX_PORT=65535

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[1;90m'
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'
BG_GRAY='\033[100m'
RESET='\033[0m'
BOLD='\033[1m'

print_header() {
    clear
    echo -e "${BLUE}╔$(printf '═%.0s' {1..62})╗${RESET}"
    printf "${BLUE}║${BG_BLUE}${WHITE}%-${MENU_BOX_WIDTH}s${RESET}${BLUE}║${RESET}\n" "                    ${PROJECT_NAME} Manager                    "
    echo -e "${BLUE}║${WHITE}           Proxy + Protocolo integrados                     ${BLUE}║${RESET}"
    echo -e "${BLUE}╚$(printf '═%.0s' {1..62})╝${RESET}"
    echo
}

get_online_users_count() {
    if [[ ! -f "$STATS_FILE" ]]; then
        echo "0"
        return
    fi

    python3 - "$STATS_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        print(len(data))
    else:
        print(0)
except Exception:
    print(0)
PY
}

is_online_api_active() {
    systemctl is-active --quiet "$ONLINE_API_SERVICE_NAME"
}

get_online_api_port() {
    if [[ -f "$ONLINE_API_PORT_FILE" ]]; then
        cat "$ONLINE_API_PORT_FILE"
    else
        echo ""
    fi
}

create_online_api_script() {
    sudo tee "$ONLINE_API_SCRIPT" > /dev/null <<'PY'
#!/usr/bin/env python3
import argparse
import json
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

def fmt_bytes(value):
    try:
        value = float(value)
    except Exception:
        return "0 B"
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{value:.2f} {unit}"
        value /= 1024

def fmt_duration(seconds):
    seconds = max(0, int(seconds))
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}"

def load_onlines(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            return []
    except Exception:
        return []

    rows = []
    for ip, info in data.items():
        if not isinstance(info, dict):
            continue
        user = info.get("id") or ip
        up = info.get("traffic_up", 0)
        down = info.get("traffic_down", 0)
        connected_at = info.get("connected_at")
        last_seen_at = info.get("last_seen_at")
        connected_time = "N/A"
        if connected_at and last_seen_at:
            try:
                c = datetime.strptime(connected_at, "%Y-%m-%d %H:%M:%S")
                l = datetime.strptime(last_seen_at, "%Y-%m-%d %H:%M:%S")
                connected_time = fmt_duration((l - c).total_seconds())
            except Exception:
                pass
        rows.append({
            "user": user,
            "ip": ip,
            "traffic_up": fmt_bytes(up),
            "traffic_down": fmt_bytes(down),
            "connected_at": connected_at,
            "last_seen_at": last_seen_at,
            "connected_time": connected_time
        })
    return rows

class Handler(BaseHTTPRequestHandler):
    stats_file = ""
    server_version = "DTProtoOnline"
    sys_version = ""

    def do_GET(self):
        if self.path != "/onlines":
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        body = json.dumps(load_onlines(self.stats_file), ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _method_not_allowed(self):
        self.send_response(405)
        self.send_header("Allow", "GET")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt, *args):
        return

for method in ("POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"):
    setattr(Handler, f"do_{method}", Handler._method_not_allowed)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--stats-file", required=True)
    args = parser.parse_args()
    Handler.stats_file = args.stats_file
    HTTPServer(("0.0.0.0", args.port), Handler).serve_forever()

if __name__ == "__main__":
    main()
PY
    sudo chmod +x "$ONLINE_API_SCRIPT"
}

activate_online_api() {
    if is_online_api_active; then
        print_warning "API já está ativa."
        pause
        return
    fi

    local api_port
    echo -e "${BLUE}Digite a porta para API de onlines:${RESET}"
    read -rp "> " api_port
    api_port=$(echo "$api_port" | tr -d '[:space:]')

    if ! validate_port "$api_port"; then
        pause
        return
    fi

    if ! check_port_available "$api_port"; then
        pause
        return
    fi

    create_online_api_script
    sudo mkdir -p "$(dirname "$ONLINE_API_PORT_FILE")"
    echo "$api_port" | sudo tee "$ONLINE_API_PORT_FILE" > /dev/null

    sudo tee "/etc/systemd/system/$ONLINE_API_SERVICE_NAME.service" > /dev/null <<EOF
[Unit]
Description=DTProto Online API
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $ONLINE_API_SCRIPT --port=$api_port --stats-file=$STATS_FILE
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    if sudo systemctl start "$ONLINE_API_SERVICE_NAME"; then
        sudo systemctl enable "$ONLINE_API_SERVICE_NAME" > /dev/null 2>&1
        print_success "API de onlines ativada na porta $api_port."
        print_info "JSON: http://SEU_IP:$api_port/onlines"
    else
        print_error "Falha ao ativar API de onlines."
    fi
    pause
}

deactivate_online_api() {
    if ! is_online_api_active; then
        print_warning "API já está desativada."
        pause
        return
    fi

    sudo systemctl stop "$ONLINE_API_SERVICE_NAME"
    sudo systemctl disable "$ONLINE_API_SERVICE_NAME" > /dev/null 2>&1
    sudo rm -f "/etc/systemd/system/$ONLINE_API_SERVICE_NAME.service"
    sudo systemctl daemon-reload
    print_success "API de onlines desativada."
    pause
}

print_status() {
    local proto_status="OFFLINE"
    local status_bg=$BG_RED
    local status_color=$WHITE

    if is_server_active; then
        proto_status="ONLINE "
        status_bg=$BG_GREEN
    else
        proto_status="OFFLINE"
    fi

    local proxy_ports proxy_label proxy_tok proto_tok bound_ip
    proxy_ports=$(list_configured_proxy_ports)
    proxy_label="${proxy_ports:-nenhuma}"
    [[ -n "$(load_proxy_token)" ]] && proxy_tok="✅" || proxy_tok="❌"
    [[ -n "$(load_proto_token)" ]] && proto_tok="✅" || proto_tok="❌"
    bound_ip=""
    [[ -f /etc/vtproxy/ip ]] && bound_ip=$(cat /etc/vtproxy/ip)

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${BLUE}║${WHITE} Proto: ${status_bg}${BOLD}${status_color}  ${proto_status}  ${RESET}${BLUE} | Proxy: ${CYAN}$(printf '%-18s' "$proxy_label")${BLUE}║${RESET}\n"
    printf "${BLUE}║${WHITE} Tokens proxy: ${proxy_tok}  proto: ${proto_tok}"
    if [[ -n "$bound_ip" ]]; then
        printf " | IP: ${CYAN}%-15s" "$bound_ip"
    fi
    printf " %*s${BLUE}║${RESET}\n" 1 ""

    local port subnet tun
    port=$(get_config_value "PORT")
    subnet=$(get_config_value "VIRTUAL_SUBNET_CIDR")
    tun=$(get_config_value "TUN_INTERFACE")
    port=${port:-8000}
    subnet=${subnet:-10.10.0.0/16}
    tun=${tun:-tun0}

    local line="${WHITE} Porta proto: ${CYAN}$(printf '%-5s' "$port")${WHITE} | Sub-rede: ${CYAN}$(printf '%-13s' "$subnet")${WHITE} | TUN: ${CYAN}$(printf '%-6s' "$tun")"
    printf "${BLUE}║${line}%*s${BLUE}║${RESET}\n" 3 ""
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

print_main_menu() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${WHITE}                        MENU PRINCIPAL                        ${BLUE}║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    
    local menu_items=(
        "1 • Iniciar Servidor"
        "2 • Parar Servidor" 
        "3 • Reiniciar Servidor"
        "4 • Status & Configuração"
        "5 • Visualizar Logs"
        "6 • Alterar Porta"
        "7 • Token Proto (menu [4])"
        "8 • Modo de Autenticação"
        "0 • Voltar ao Menu Inicial"
    )
    
    for item in "${menu_items[@]}"; do
        local padding=$((60 - ${#item}))
        if [[ $item == *"Voltar"* ]]; then
            printf "${BLUE}║${RED}  [${item%% *}] ${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        else
            printf "${BLUE}║${WHITE}  [${CYAN}${item%% *}${WHITE}] ${BLUE}${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        fi
    done
    
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

print_initial_menu() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${WHITE}                        MENU INICIAL                          ${BLUE}║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    
    local menu_items=(
        "1 • Servidor Protocolo"
        "2 • Proxy / Portas"
        "3 • Usuarios Online"
        "4 • Gerenciar Tokens"
        "5 • Remover Instalação"
        "0 • Sair"
    )
    
    for item in "${menu_items[@]}"; do
        local padding=$((60 - ${#item}))
        if [[ $item == *"Remover"* ]]; then
            printf "${BLUE}║${RED}  [${item%% *}] ${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        elif [[ $item == *"Sair"* ]]; then
            printf "${BLUE}║${RED}  [${item%% *}] ${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        else
            printf "${BLUE}║${WHITE}  [${CYAN}${item%% *}${WHITE}] ${BLUE}${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        fi
    done
    
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
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
    print_warning "Pressione Enter para continuar..."
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

load_proto_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        sudo cat "$TOKEN_FILE"
    fi
}

save_proto_token() {
    local token="$1"
    sudo mkdir -p "$(dirname "$TOKEN_FILE")"
    printf '%s' "$token" | sudo tee "$TOKEN_FILE" >/dev/null
    sudo chmod 600 "$TOKEN_FILE" 2>/dev/null || true
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
    systemctl list-units --type=service --all --no-legend 'proxy-*.service' 2>/dev/null \
        | awk '{print $1}' \
        | grep -oE 'proxy-[0-9]+' \
        | cut -d'-' -f2 \
        | sort -nu \
        | paste -sd, - 2>/dev/null || true
}

list_active_proxies() {
    list_configured_proxy_ports
}

is_port_in_use() {
    local port="$1"
    command -v ss >/dev/null 2>&1 && ss -tuln | grep -q ":$port "
}

ensure_proto_for_proxy() {
    if is_server_active; then
        return 0
    fi

    print_warning "Servidor protocolo (${SERVICE_NAME}) não está ativo."
    print_info "O proxy depende de --dt-proto-port=$(get_proto_port)."
    if confirm_action "Continuar mesmo assim?" "n"; then
        return 0
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

is_proxy_service_configured() {
    local port="$1"
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
    echo -e "${YELLOW}$message (s/N)${RESET}"
    read -rp "> " response
    response=${response:-$default_answer}
    case "${response,,}" in
        s|sim|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

get_proto_port() {
    local proto_port=$(get_config_value "PORT")
    echo "${proto_port:-8000}"
}

normalize_protocol_config() {
    local input="$1"
    local output=""
    local part

    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        case "$part" in
            tcp:*|udp:*|quic:*)
                if [[ -n "$output" ]]; then
                    output="$output,$part"
                else
                    output="$part"
                fi
                ;;
        esac
    done

    echo "$output"
}

build_proxy_command() {
    local port="$1"
    local token="$2"
    local ssl_enabled="$3"
    local ssl_cert_path="$4"
    local ssh_only_flag="$5"
    local http_response="$6"
    
    local command="$PROXY_EXECUTABLE --token=$token --buffer-size=$DEFAULT_BUFFER_SIZE --response=$http_response --domain --log-file=$(get_proxy_log_file "$port")"
    
    local proto_port=$(get_proto_port)
    command="$command --dt-proto-port=$proto_port"
    
    if [[ "$ssl_enabled" == "true" ]]; then
        command="$command --port=$port:ssl"
        if [[ -n "$ssl_cert_path" ]]; then
            command="$command --cert=$ssl_cert_path"
        fi
    else
        command="$command --port=$port"
    fi
    
    if [[ "$ssh_only_flag" == "true" ]]; then
        command="$command --ssh-only"
    fi
    
    echo "$command"
}

start_proxy_for_port() {
    local port="$1"
    local ssl_enabled="$2"
    local ssl_cert_path="$3"
    local ssh_only_flag="$4"
    local http_response="$5"

    if ! validate_port "$port"; then
        return 1
    fi

    if ! check_port_available "$port"; then
        return 1
    fi

    local token
    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy não configurado. Use Gerenciar Tokens no menu inicial."
        return 1
    fi

    ensure_proto_for_proxy || return 1

    local proxy_command
    proxy_command=$(build_proxy_command "$port" "$token" "$ssl_enabled" "$ssl_cert_path" "$ssh_only_flag" "$http_response")
    if [[ "$proxy_command" != *"--dt-proto-port="* ]]; then
        proxy_command="$proxy_command --dt-proto-port=$(get_proto_port)"
    fi

    local service_name
    service_name=$(get_proxy_service_name "$port")

    sudo tee "/etc/systemd/system/$service_name.service" > /dev/null <<EOF
[Unit]
Description=${PROJECT_NAME} Proxy Server na porta $port
After=network.target ${SERVICE_NAME}.service
Wants=${SERVICE_NAME}.service

[Service]
ExecStart=$proxy_command
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    if sudo systemctl start "$service_name"; then
        sudo systemctl enable "$service_name" > /dev/null 2>&1
        return 0
    fi

    return 1
}

change_proxy_status() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta proxy configurada."
        pause
        return
    fi

    echo -e "${BLUE}Portas configuradas: ${GREEN}$configured_ports${RESET}"
    echo -e "${BLUE}Digite a porta para alterar o status/resposta:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port"; then
        pause
        return
    fi

    local service_name
    service_name=$(get_proxy_service_name "$port")
    local service_file="/etc/systemd/system/$service_name.service"
    if [[ ! -f "$service_file" ]]; then
        print_error "Serviço não encontrado para a porta $port."
        pause
        return
    fi

    local current_response
    current_response=$(sudo grep -o -- '--response=[^ ]*' "$service_file" | head -n1 | cut -d= -f2)
    current_response=${current_response:-$DEFAULT_HTTP_RESPONSE}

    echo -e "${BLUE}Status/Resposta atual: ${GREEN}$current_response${RESET}"
    echo -e "${BLUE}Novo status/resposta (Enter para manter):${RESET}"
    read -rp "> " new_response
    new_response=${new_response:-$current_response}
    new_response=$(echo "$new_response" | tr -d '[:space:]')

    if [[ -z "$new_response" ]]; then
        print_error "Status/resposta não pode ser vazio."
        pause
        return
    fi

    local safe_response
    safe_response=$(escape_sed_replacement "$new_response")
    sudo sed -Ei "s|--response=[^ ]+|--response=${safe_response}|g" "$service_file"
    sudo systemctl daemon-reload

    if sudo systemctl restart "$service_name"; then
        print_success "Status/resposta da porta $port atualizado para '$new_response'."
    else
        print_error "Falha ao reiniciar proxy na porta $port."
    fi

    pause
}

sync_proxy_dtproto_port() {
    local new_proto_port="$1"
    local service_file
    local updated_any="false"

    for service_file in /etc/systemd/system/${PROXY_SERVICE_PREFIX}-*.service; do
        if [[ ! -f "$service_file" ]]; then
            continue
        fi

        if sudo grep -q -- "--dt-proto-port=" "$service_file"; then
            sudo sed -Ei "s/--dt-proto-port=[0-9]+/--dt-proto-port=$new_proto_port/g" "$service_file"
            updated_any="true"
        fi
    done

    if [[ "$updated_any" == "true" ]]; then
        sudo systemctl daemon-reload

        local service
        for service in $(systemctl list-unit-files --type=service --no-legend | awk '{print $1}' | grep "^${PROXY_SERVICE_PREFIX}-.*\\.service$"); do
            if systemctl is-active --quiet "$service"; then
                sudo systemctl restart "$service"
            fi
        done
    fi
}

start_proxy_service() {
    print_header
    
    local port
    echo -e "${BLUE}Digite a porta para abrir:${RESET}"
    read -rp "> " port
    
    port=$(echo "$port" | tr -d '[:space:]')
    
    local ssl_enabled="false"
    local ssl_cert_path=""
    
    if confirm_action "Deseja habilitar SSL?" "n"; then
        ssl_enabled="true"
        if ! confirm_action "Usar certificado interno?" "s"; then
            echo -e "${BLUE}Caminho do certificado SSL:${RESET}"
            read -rp "> " ssl_cert_path
        fi
    fi
    
    local http_response
    echo -e "${BLUE}Resposta HTTP padrão (Enter para '$DEFAULT_HTTP_RESPONSE'):${RESET}"
    read -rp "> " http_response
    http_response=${http_response:-$DEFAULT_HTTP_RESPONSE}
    
    local ssh_only_flag="false"
    if confirm_action "Habilitar modo somente SSH?" "n"; then
        ssh_only_flag="true"
    fi
    
    print_info "Iniciando proxy na porta $port..."
    if start_proxy_for_port "$port" "$ssl_enabled" "$ssl_cert_path" "$ssh_only_flag" "$http_response"; then
        print_success "Proxy iniciado com sucesso na porta $port!"
    else
        print_error "Falha ao iniciar proxy na porta $port"
    fi
    
    pause
}

stop_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)

    echo -e "${BLUE}Portas configuradas: ${GREEN}${configured_ports:-nenhuma}${RESET}"
    echo -e "${BLUE}Digite a porta para fechar:${RESET}"
    read -rp "> " port

    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port"; then
        pause
        return
    fi

    if ! is_proxy_service_configured "$port"; then
        print_error "Nenhum serviço configurado na porta $port."
        pause
        return
    fi

    local service_name
    service_name=$(get_proxy_service_name "$port")

    print_info "Parando proxy na porta $port..."

    sudo systemctl stop "$service_name" 2>/dev/null || true
    sudo systemctl disable "$service_name" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/$service_name.service"
    sudo systemctl daemon-reload
    print_success "Proxy na porta $port foi encerrado."

    pause
}

restart_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)

    echo -e "${BLUE}Portas configuradas: ${GREEN}${configured_ports:-nenhuma}${RESET}"
    echo -e "${BLUE}Digite a porta para reiniciar:${RESET}"
    read -rp "> " port

    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port"; then
        pause
        return
    fi

    if ! is_proxy_service_configured "$port"; then
        print_error "Nenhum serviço configurado na porta $port."
        pause
        return
    fi

    local service_name
    service_name=$(get_proxy_service_name "$port")

    print_info "Reiniciando proxy na porta $port..."

    if sudo systemctl restart "$service_name"; then
        print_success "Proxy reiniciado com sucesso na porta $port!"
    else
        print_error "Falha ao reiniciar proxy na porta $port"
    fi

    pause
}

show_proxy_logs() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)

    echo -e "${BLUE}Portas configuradas: ${GREEN}${configured_ports:-nenhuma}${RESET}"
    echo -e "${BLUE}Digite a porta para ver os logs:${RESET}"
    read -rp "> " port

    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port"; then
        pause
        return
    fi

    if ! is_proxy_service_configured "$port"; then
        print_error "Nenhum serviço configurado na porta $port."
        pause
        return
    fi

    local log_file
    log_file=$(get_proxy_log_file "$port")

    if [[ ! -f "$log_file" ]]; then
        print_error "Arquivo de log não encontrado: $log_file"
        print_info "Verifique: systemctl status $(get_proxy_service_name "$port")"
        pause
        return
    fi
    
    echo -e "${BLUE}Exibindo logs da porta $port (Ctrl+C para sair):${RESET}"
    echo
    
    trap 'break' INT
    while :; do
        clear
        sudo cat "$log_file"
        echo -e "\n${YELLOW}Pressione Ctrl+C para retornar ao menu.${RESET}"
        sleep 5
    done
    trap - INT
    
    pause
}

connection_menu() {
    init_proxy_dirs
    prompt_for_proxy_token_if_missing
    
    while true; do
        print_header
        
        local configured_ports
        configured_ports=$(list_configured_proxy_ports)
        
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BLUE}║${CYAN}                    ${PROJECT_NAME} — PROXY                         ${BLUE}║${RESET}"
        echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
        
        if [[ -n "$configured_ports" ]]; then
            echo -e "${BLUE}║${WHITE}  Portas configuradas: ${GREEN}$(printf '%-38s' "$configured_ports")${BLUE}║${RESET}"
            echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
        fi
        
        local menu_items=(
            "1 • Abrir Porta"
            "2 • Fechar Porta"
            "3 • Reiniciar Porta"
            "4 • Alterar Status"
            "5 • Ver Log da Porta"
            "0 • Voltar ao Menu Inicial"
        )
        
        for item in "${menu_items[@]}"; do
            local padding=$((60 - ${#item}))
            if [[ $item == *"Voltar"* ]]; then
                printf "${BLUE}║${RED}  [${item%% *}] ${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
            else
                printf "${BLUE}║${WHITE}  [${CYAN}${item%% *}${WHITE}] ${BLUE}${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
            fi
        done
        
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo
        
        local choice
        read -rp "$(echo -e "${BLUE}Selecione uma opção [0-5]:${RESET} ")" choice
        
        case "$choice" in
            1) start_proxy_service ;;
            2) stop_proxy_service ;;
            3) restart_proxy_service ;;
            4) change_proxy_status ;;
            5) show_proxy_logs ;;
            0) return 0 ;;
            *) 
                print_error "Opção inválida: $choice"
                pause 
                ;;
        esac
    done
}

get_config_value() {
    local key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2
    else
        echo ""
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    local temp_file=$(mktemp)

    sudo mkdir -p "$(dirname "$CONFIG_FILE")"

    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^$key=" "$CONFIG_FILE" > "$temp_file"
    fi
    echo "$key=$value" >> "$temp_file"
    sudo mv "$temp_file" "$CONFIG_FILE"
}

load_token() {
    load_proto_token
}

save_token() {
    local token="$1"
    save_proto_token "$token"
}

validate_token() {
    local token="$1"
    if [ -z "$token" ]; then
        print_error "Token vazio. Não pode ser validado."
        return 1
    fi

    print_info "Validando token..."
    
    if [ ! -f "$PROTO_SERVER_BIN" ]; then
        print_error "Binário do servidor não encontrado."
        return 1
    fi
    
    if sudo "$PROTO_SERVER_BIN" --token "$token" --validate; then
        return 0
    else
        return 1
    fi
}

is_server_active() {
    systemctl is-active "$SERVICE_NAME" &> /dev/null
}

CURRENT_AUTH_MODE=$(get_config_value "AUTH_MODE")
CURRENT_AUTH_MODE=${CURRENT_AUTH_MODE:-$AUTH_MODE_FILE}
CURRENT_AUTH_URL=$(get_config_value "AUTH_URL")

ensure_data_structure() {
    local quiet_mode="${1:-false}"

    if [ ! -d "$DATA_DIR" ]; then
        sudo mkdir -p "$DATA_DIR"
        if [[ "$quiet_mode" != "true" ]]; then
            print_success "Diretório de dados criado: $DATA_DIR"
        fi
    fi

    if [[ ! -f "$CERTIFICATE_SSL_FILE" ]] || [[ ! -f "$PRIVATE_KEY_SSL_FILE" ]]; then
        if [[ "$quiet_mode" != "true" ]]; then
            print_info "Generating TLS certificates..."
        fi
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$PRIVATE_KEY_SSL_FILE" \
            -out "$CERTIFICATE_SSL_FILE" \
            -subj "/C=BR/ST=State/L=City/O=ProtoServer/CN=proto-server" \
            2>/dev/null
        chmod 600 "$PRIVATE_KEY_SSL_FILE"
        chmod 644 "$CERTIFICATE_SSL_FILE"
    fi

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        if [[ "$quiet_mode" != "true" ]]; then
            print_info "Criando arquivo de credenciais..."
        fi
        sudo cat > "$CREDENTIALS_FILE" <<EOF
{
  "credentials": [
    {
      "user": "Dtunnel",
      "pass": "Dtunnel"
    }
  ]
}
EOF
        sudo chmod 644 "$CREDENTIALS_FILE"
        if [[ "$quiet_mode" != "true" ]]; then
            print_success "Arquivo credentials.json criado com credenciais padrão."
        fi
    fi

    if [ ! -f "$STATS_FILE" ]; then
        if [[ "$quiet_mode" != "true" ]]; then
            print_info "Criando arquivo de estatísticas..."
        fi
        echo "{}" > "$STATS_FILE"
        sudo chmod 644 "$STATS_FILE"
        if [[ "$quiet_mode" != "true" ]]; then
            print_success "Arquivo stats.json criado."
        fi
    fi
}

create_systemd_service() {
    local current_token=$(load_token)
    local port=$(get_config_value "PORT")
    local subnet=$(get_config_value "VIRTUAL_SUBNET_CIDR")
    local tun=$(get_config_value "TUN_INTERFACE")
    local auth_flag=$(get_auth_flag)
    local protocol_config=$(get_config_value "PROTOCOL_CONFIG")
    local client_cleanup=$(get_config_value "CLIENT_CLEANUP_INTERVAL")
    local client_timeout=$(get_config_value "CLIENT_INACTIVE_TIMEOUT")
    local tun_buffer=$(get_config_value "TUN_BUFFER_SIZE")

    if [ -z "$current_token" ]; then
        print_error "Token não configurado."
        return 1
    fi
    if [ -z "$port" ] || [ -z "$subnet" ] || [ -z "$tun" ]; then
        print_error "Configurações incompletas."
        return 1
    fi

    print_info "Criando serviço systemd..."

    protocol_config=$(normalize_protocol_config "$protocol_config")

    local service_command="$PROTO_SERVER_BIN \\
    --token=$current_token \\
    --virtual-subnet-cidr=$subnet \\
    --tun=$tun \\
    --quic-cert=$CERTIFICATE_SSL_FILE \\
    --quic-key=$PRIVATE_KEY_SSL_FILE \\
    --stats-file=$STATS_FILE"

    if [[ -n "$protocol_config" ]]; then
        service_command="$service_command \\
    --protocol=$protocol_config"
    else
        service_command="$service_command \\
    --protocol=tcp:$port"
    fi

    if [[ -n "$client_cleanup" ]]; then
        service_command="$service_command \\
    --client-cleanup-interval=$client_cleanup"
    fi

    if [[ -n "$client_timeout" ]]; then
        service_command="$service_command \\
    --client-inactive-timeout=$client_timeout"
    fi

    if [[ -n "$tun_buffer" ]]; then
        service_command="$service_command \\
    --tun-buffer-size=$tun_buffer"
    fi

    if [[ -n "$auth_flag" ]]; then
        service_command="$service_command \\
    $auth_flag"
    fi

    sudo cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=${PROJECT_NAME} Proto Server
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$service_command
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    print_success "Serviço systemd configurado."
}

start_server() {
    print_header
    
    ensure_data_structure
    check_or_set_proto_token

    local port=$(get_config_value "PORT")
    local subnet=$(get_config_value "VIRTUAL_SUBNET_CIDR")
    local tun=$(get_config_value "TUN_INTERFACE")
    local protocol_config=$(get_config_value "PROTOCOL_CONFIG")

    port=${port:-8000}
    subnet=${subnet:-10.10.0.0/16}
    tun=${tun:-tun0}

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${CYAN}  📋 CONFIGURAÇÕES ATUAIS ${BLUE}                                    ║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BLUE}║${WHITE}  ┣ Porta: ${BLUE}$(printf '%-51s' "$port")${BLUE}║${RESET}"
    echo -e "${BLUE}║${WHITE}  ┣ Sub-rede: ${BLUE}$(printf '%-48s' "$subnet")${BLUE}║${RESET}"
    echo -e "${BLUE}║${WHITE}  ┣ Interface TUN: ${BLUE}$(printf '%-43s' "$tun")${BLUE}║${RESET}"
    if [[ -n "$protocol_config" ]]; then
        echo -e "${BLUE}║${WHITE}  ┣ Protocolos: ${BLUE}$(printf '%-46s' "$protocol_config")${BLUE}║${RESET}"
    fi
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    while true; do
        echo -e "${BLUE}Porta (Enter para manter [$port]):${RESET}"
        read -rp "> " new_port_input
        
        if [ -z "$new_port_input" ]; then
            break
        fi
        
        if validate_port "$new_port_input" && check_port_available "$new_port_input"; then
            port="$new_port_input"
            print_success "Porta $port validada com sucesso!"
            break
        else
            print_warning "Por favor, insira uma porta válida e disponível."
            echo
        fi
    done

    echo -e "${BLUE}Sub-rede CIDR (Enter para manter [$subnet]):${RESET}"
    read -rp "> " new_subnet_input
    
    echo -e "${BLUE}Interface TUN (Enter para manter [$tun]):${RESET}"
    read -rp "> " new_tun_input

    if [ -n "$new_subnet_input" ]; then
        subnet="$new_subnet_input"
    fi
    if [ -n "$new_tun_input" ]; then
        tun="$new_tun_input"
    fi

    echo
    print_info "Configuração de protocolos:"
    echo -e "${BLUE}TCP será ativado obrigatoriamente na porta $port${RESET}"
    
    local protocol_components="tcp:$port"
    
    if confirm_action "Deseja ativar UDP na mesma porta?" "n"; then
        protocol_components="$protocol_components,udp:$port"
        print_success "UDP ativado na porta $port"
    fi
    
    local quic_port=""
    if confirm_action "Deseja ativar QUIC?" "n"; then
        while true; do
            echo -e "${BLUE}Porta para QUIC (Enter para $((port + 1))):${RESET}"
            read -rp "> " quic_port_input
            quic_port=${quic_port_input:-$((port + 1))}
            
            if validate_port "$quic_port" && check_port_available "$quic_port"; then
                protocol_components="$protocol_components,quic:$quic_port"
                print_success "QUIC ativado na porta $quic_port"
                break
            else
                print_warning "Porta QUIC inválida ou indisponível."
            fi
        done
    fi

    set_config_value "PORT" "$port"
    set_config_value "VIRTUAL_SUBNET_CIDR" "$subnet"
    set_config_value "TUN_INTERFACE" "$tun"
    set_config_value "PROTOCOL_CONFIG" "$protocol_components"
    
    print_success "Configurações salvas!"

    if create_systemd_service; then
        print_info "Iniciando servidor..."
        if sudo systemctl start "$SERVICE_NAME"; then
            sudo systemctl enable "$SERVICE_NAME" &> /dev/null
            print_success "Servidor protocolo iniciado com sucesso!"
            
            sleep 2
            if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
                print_success "Servidor está ativo e rodando!"
                echo -e "${BLUE}Protocolos configurados: $protocol_components${RESET}"
            else
                print_error "Servidor pode não ter iniciado corretamente."
                print_info "Verifique os logs: ${BLUE}sudo journalctl -u $SERVICE_NAME -f${RESET}"
            fi
        else
            print_error "Falha ao iniciar o serviço."
            print_info "Verifique os logs: ${BLUE}sudo journalctl -u $SERVICE_NAME -f${RESET}"
        fi
    fi
    pause
}

stop_server() {
    
    if is_server_active; then
        print_info "Parando serviço $SERVICE_NAME..."
        sudo systemctl stop "$SERVICE_NAME"
        print_success "Servidor parado."
    else
        print_error "Servidor não está ativo."
    fi
    pause
}

restart_server() {
    
    if is_server_active; then
        print_info "Reiniciando serviço $SERVICE_NAME..."
        sudo systemctl restart "$SERVICE_NAME"
        print_success "Servidor reiniciado."
    else
        print_error "Servidor não está ativo."
    fi
    pause
}

show_server_status() {
    print_header
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${CYAN}  📊 STATUS DO SISTEMA${BLUE}                                        ║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    
    local port=$(get_config_value 'PORT')
    local subnet=$(get_config_value 'VIRTUAL_SUBNET_CIDR')
    local tun=$(get_config_value 'TUN_INTERFACE')
    local auth_mode=$(get_config_value 'AUTH_MODE')
    auth_mode=${auth_mode:-$AUTH_MODE_FILE}
    local auth_url=$(get_config_value 'AUTH_URL')
    local protocol_config=$(get_config_value 'PROTOCOL_CONFIG')
    local token_status=$([ -f "$TOKEN_FILE" ] && echo '✅' || echo '❌')
    
    if is_server_active; then
        echo -e "${BLUE}║${WHITE}  ┣ Status: ${GREEN}🟢              ${BLUE}                                  ║${RESET}"
    else
        echo -e "${BLUE}║${WHITE}  ┣ Status: ${RED}🔴         ${BLUE}                                       ║${RESET}"
    fi
    
    echo -e "${BLUE}║${WHITE}  ┣ Porta: ${BLUE}$(printf '%-51s' "${port:-8000}")${BLUE}║${RESET}"
    echo -e "${BLUE}║${WHITE}  ┣ Sub-rede Virtual: ${BLUE}$(printf '%-40s' "${subnet:-10.10.0.0/16}")${BLUE}║${RESET}"
    echo -e "${BLUE}║${WHITE}  ┣ Interface TUN: ${BLUE}$(printf '%-43s' "${tun:-tun0}")${BLUE}║${RESET}"
    if [[ -n "$protocol_config" ]]; then
        echo -e "${BLUE}║${WHITE}  ┣ Protocolos: ${BLUE}$(printf '%-46s' "$protocol_config")${BLUE}║${RESET}"
    fi
    echo -e "${BLUE}║${WHITE}  ┣ Token Configurado: ${BLUE}$(printf '%-40s' "$token_status")${BLUE}║${RESET}"
    
    local auth_display=""
    case "$auth_mode" in
        $AUTH_MODE_FILE) auth_display="Arquivo" ;;
        $AUTH_MODE_URL) auth_display="URL ($auth_url)" ;;
        $AUTH_MODE_SSH) auth_display="SSH/PAM" ;; 
        $AUTH_MODE_NONE) auth_display="Nenhuma" ;;
        *) auth_display="Arquivo" ;;
    esac
    echo -e "${BLUE}║${WHITE}  ┗ Autenticação: ${BLUE}$(printf '%-44s' "$auth_display")${BLUE}║${RESET}"
    
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    pause
}

view_logs() {
    
    print_info "Exibindo logs (Ctrl+C para sair)..."
    echo
    sudo journalctl -u "$SERVICE_NAME" -f
    pause
}

get_auth_flag() {
    local auth_mode=$(get_config_value "AUTH_MODE")
    auth_mode=${auth_mode:-$AUTH_MODE_FILE}
    local auth_url=$(get_config_value "AUTH_URL")
    
    case "$auth_mode" in
        $AUTH_MODE_URL)
            if [[ -n "$auth_url" ]]; then
                echo "--auth-url=$auth_url"
            else
                echo "--auth-file=$CREDENTIALS_FILE"
            fi
            ;;
        $AUTH_MODE_SSH)
            echo "--auth-url=http://127.0.0.1:6328/auth"
            ;;
        $AUTH_MODE_FILE)
            echo "--auth-file=$CREDENTIALS_FILE"
            ;;
        $AUTH_MODE_NONE)
            echo ""
            ;;
        *)
            echo "--auth-file=$CREDENTIALS_FILE"
            ;;
    esac
}

setup_ssh_auth() {
    print_info "Configurando autenticação SSH/PAM..."
    
    local SCRIPT_PATH="/usr/local/bin/ssh_auth.py"
    local VENV_PATH="/usr/local/bin/ssh_auth_venv"
    local SSH_AUTH_SERVICE="ssh-auth-api"
    local SERVICE_FILE="/etc/systemd/system/ssh-auth-api.service"
    
    echo ">>> Atualizando pacotes..."
    sudo apt update -y

    echo ">>> Instalando dependências..."
    sudo apt install -y python3 python3-venv python3-pip curl systemd

    echo ">>> Instalando módulo PAM..."
    if ! sudo apt install -y python3-pam; then
        echo ">>> Pacote python3-pam não disponível, tentando via pip..."
        sudo pip3 install python-pam || sudo pip3 install pam
    fi

    echo ">>> Criando script ssh_auth.py..."
    sudo tee "$SCRIPT_PATH" > /dev/null << 'EOF'
import logging
from flask import Flask, request, jsonify
import pam

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

p = pam.pam()

@app.route('/auth', methods=['POST'])
def auth():
    if not request.json:
        return jsonify({'success': False, 'message': 'invalid request'}), 400

    username = request.json.get('username')
    password = request.json.get('password')

    if not username or not password:
        return jsonify({'success': False, 'message': 'username and password required'}), 400

    logging.info('Authentication request for user: %s', username)

    try:
        if p.authenticate(username, password):
            logging.info('Authentication successful for user: %s', username)
            return jsonify({'success': True, 'message': 'Authentication successful'}), 200
        else:
            logging.info('Authentication failed for user: %s', username)
            return jsonify({'success': False, 'message': 'invalid credentials'}), 401
    except Exception as e:
        logging.error('PAM error: %s', e)
        return jsonify({'success': False, 'message': 'authentication error'}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=6328, debug=False)
EOF

    sudo chmod +x "$SCRIPT_PATH"

    echo ">>> Criando ambiente virtual..."
    sudo python3 -m venv "$VENV_PATH"
    sudo "$VENV_PATH/bin/pip" install --upgrade pip

    echo ">>> Instalando dependências no ambiente virtual..."
    sudo "$VENV_PATH/bin/pip" install flask six python-pam || sudo "$VENV_PATH/bin/pip" install flask six pam

    echo ">>> Criando serviço systemd..."
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=SSH Auth Python Service
After=network.target

[Service]
Type=simple
ExecStart=${VENV_PATH}/bin/python ${SCRIPT_PATH}
WorkingDirectory=/usr/local/bin
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

    echo ">>> Recarregando e iniciando serviço..."
    sudo systemctl daemon-reload
    sudo systemctl enable "$SSH_AUTH_SERVICE"
    sudo systemctl restart "$SSH_AUTH_SERVICE"

    sleep 2
    
    echo ">>> Verificando status do serviço..."
    if sudo systemctl is-active --quiet "$SSH_AUTH_SERVICE"; then
        print_success "Serviço SSH Auth API criado e iniciado com sucesso!"
        print_info "API rodando em: http://127.0.0.1:6328/auth"
        
        set_config_value "AUTH_MODE" "$AUTH_MODE_SSH"
        set_config_value "AUTH_URL" "http://127.0.0.1:6328/auth"
        
        print_success "Autenticação SSH/PAM configurada com sucesso!"
    else
        print_error "Falha ao iniciar o serviço SSH Auth API."
        print_info "Verifique os logs: sudo journalctl -u ssh-auth-api -f"
        return 1
    fi
}

change_auth_mode() {
    print_header
    
    local current_mode=$(get_config_value "AUTH_MODE")
    current_mode=${current_mode:-$AUTH_MODE_FILE}
    local current_url=$(get_config_value "AUTH_URL")
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${CYAN}                 ALTERAR MODO DE AUTENTICAÇÃO                 ${BLUE}║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    
    local mode_line="${WHITE}  Modo atual: ${GREEN}$current_mode"
    local mode_padding=$((60 - ${#mode_line} + 22)) 
    printf "${BLUE}║${mode_line}%${mode_padding}s${BLUE}║${RESET}\n" ""
    
    if [[ "$current_mode" == "$AUTH_MODE_URL" && -n "$current_url" ]]; then
        local url_line="${WHITE}  URL atual: ${CYAN}$current_url"
        local url_padding=$((60 - ${#url_line} + 22)) 
        printf "${BLUE}║${url_line}%${url_padding}s${BLUE}║${RESET}\n" ""
    fi
    
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    
    local menu_items=(
        "1 • Arquivo ($CREDENTIALS_FILE)"
        "2 • URL personalizada"
        "3 • SSH" 
        "4 • Sem autenticação"
        "0 • Voltar"
    )
    
    for item in "${menu_items[@]}"; do
        local padding=$((60 - ${#item}))
        if [[ $item == *"Voltar"* ]]; then
            printf "${BLUE}║${RED}  [${item%% *}] ${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        else
            printf "${BLUE}║${WHITE}  [${CYAN}${item%% *}${WHITE}] ${BLUE}${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
        fi
    done
    
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    
    local option
    read -rp "$(echo -e "${BLUE}Selecione uma opção [0-4]:${RESET} ")" option 
    
    case "$option" in
        1)
            set_config_value "AUTH_MODE" "$AUTH_MODE_FILE"
            set_config_value "AUTH_URL" ""
            print_success "Modo de autenticação alterado para: Arquivo"
            ;;
        2)
            echo -e "${BLUE}Digite a URL de autenticação:${RESET}"
            read -rp "> " auth_url
            if [[ -n "$auth_url" ]]; then
                set_config_value "AUTH_MODE" "$AUTH_MODE_URL"
                set_config_value "AUTH_URL" "$auth_url"
                print_success "Modo de autenticação alterado para: URL ($auth_url)"
            else
                print_error "URL não pode ser vazia!"
            fi
            ;;
        3) 
            setup_ssh_auth
            ;;
        4) 
            set_config_value "AUTH_MODE" "$AUTH_MODE_NONE"
            set_config_value "AUTH_URL" ""
            print_success "Autenticação desativada"
            ;;
        0)
            return
            ;;
        *)
            print_error "Opção inválida!"
            ;;
    esac
    
    if is_server_active; then
        echo
        print_info "Reiniciando serviço para aplicar mudanças..."
        if create_systemd_service; then
            sudo systemctl restart "$SERVICE_NAME"
            print_success "Serviço reiniciado com nova configuração de autenticação!"
        else
            print_error "Falha ao atualizar o serviço."
        fi
    fi
    
    pause
}

change_port() {
    print_header
    
    local current_port
    current_port=$(get_config_value "PORT")
    local current_protocol
    current_protocol=$(get_config_value "PROTOCOL_CONFIG")

    current_port=${current_port:-8000}
    echo -e "${WHITE}Porta atual: ${BLUE}$current_port${RESET}"
    if [[ -n "$current_protocol" ]]; then
        echo -e "${WHITE}Protocolos atuais: ${BLUE}$current_protocol${RESET}"
    fi

    local new_port
    while true; do
        echo -e "${BLUE}Nova porta (1-65535):${RESET}"
        read -rp "> " new_port
        
        new_port=$(echo "$new_port" | tr -d '\000-\037')

        if [[ "$new_port" == "$current_port" ]]; then
            print_warning "Esta já é a porta atual!"
            continue
        fi
        
        if validate_port "$new_port" && check_port_available "$new_port"; then
            print_success "Porta $new_port validada com sucesso!"
            break
        else
            print_warning "Por favor, insira uma porta válida e disponível."
            echo
        fi
    done

    echo
    echo -e "${YELLOW}Alterar a porta de $current_port para $new_port${RESET}"
    echo -e "${YELLOW}Isso afetará todos os clientes conectados.${RESET}"
    
    if confirm_action "Deseja continuar?"; then
        local new_protocol_config=""
        
        if [[ -n "$current_protocol" ]]; then
            new_protocol_config=$(echo "$current_protocol" | sed "s/tcp:$current_port/tcp:$new_port/g" | sed "s/udp:$current_port/udp:$new_port/g")
            
            local quic_port=$(echo "$current_protocol" | grep -o "quic:[0-9]*" | cut -d: -f2)
            if [[ -n "$quic_port" ]]; then
                local new_quic_port=$((new_port + 1))
                if check_port_available "$new_quic_port"; then
                    new_protocol_config=$(echo "$new_protocol_config" | sed "s/quic:$quic_port/quic:$new_quic_port/g")
                    print_success "Porta QUIC atualizada para $new_quic_port"
                else
                    print_warning "Porta QUIC $new_quic_port indisponível, mantendo configuração anterior"
                    new_protocol_config=$(echo "$new_protocol_config" | sed "s/quic:$quic_port//g" | sed 's/,,/,/g' | sed 's/^,//' | sed 's/,$//')
                fi
            fi

            new_protocol_config=$(normalize_protocol_config "$new_protocol_config")
        else
            new_protocol_config="tcp:$new_port"
        fi

        set_config_value "PORT" "$new_port"
        set_config_value "PROTOCOL_CONFIG" "$new_protocol_config"
        sync_proxy_dtproto_port "$new_port"
        print_success "Porta atualizada para $new_port"
        print_success "Protocolos atualizados: $new_protocol_config"

        if [ "$is_running" == "true" ]; then
            print_info "Reiniciando servidor com nova configuração..."
            if create_systemd_service; then
                if sudo systemctl restart "$SERVICE_NAME"; then
                    print_success "Servidor reiniciado com sucesso!"
                    
                    sleep 2
                    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
                        print_success "Servidor está ativo e rodando na nova porta $new_port"
                        echo -e "${BLUE}Protocolos configurados: $new_protocol_config${RESET}"
                    else
                        print_error "Servidor pode não ter reiniciado corretamente."
                        print_info "Verifique os logs: ${BLUE}sudo journalctl -u $SERVICE_NAME -f${RESET}"
                    fi
                else
                    print_error "Falha ao reiniciar o serviço."
                    print_info "Verifique os logs: ${BLUE}sudo journalctl -u $SERVICE_NAME -f${RESET}"
                fi
            else
                print_error "Falha ao atualizar o serviço systemd."
            fi
        else
            print_info "Servidor não está em execução. A nova porta será usada no próximo início."
        fi
    else
        print_info "Alteração de porta cancelada."
    fi
    
    pause
}

change_token_menu() {
    print_header

    local new_token
    while true; do
        echo -e "${BLUE}Insira o token proto:${RESET}"
        read -rp "> " new_token

        new_token=$(echo "$new_token" | tr -d '\000-\037')

        if [[ -z "$new_token" ]]; then
            print_error "Token não pode ser vazio."
            continue
        fi

        if validate_token "$new_token"; then
            save_proto_token "$new_token"
            print_success "Token proto salvo!"
            break
        else
            print_error "Token proto inválido. Tente novamente."
        fi
    done

    if is_server_active; then
        print_info "Reiniciando servidor com novo token..."
        if create_systemd_service; then
            sudo systemctl restart "$SERVICE_NAME"
            print_success "Servidor reiniciado com novo token!"
        else
            print_error "Falha ao reiniciar o serviço."
        fi
    fi
    pause
}

check_or_set_proto_token() {
    local current_token
    current_token=$(load_proto_token)
    
    if [[ -z "$current_token" ]]; then
        print_warning "Token proto não encontrado."
        change_token_menu
    fi
}

check_token_on_startup() {
    if [[ -z "$(load_proto_token)" ]]; then
        print_warning "Token proto não encontrado!"
        print_info "Configure em: Menu inicial → Gerenciar Tokens [4]"
        echo
    fi

    if [[ -z "$(load_proxy_token)" ]]; then
        print_warning "Token proxy (licença) não encontrado!"
        print_info "Configure em: Menu inicial → Gerenciar Tokens [4]"
        echo
    fi
}

run_quick_setup_first_time() {
    if [[ -n "$(load_proxy_token)" && -n "$(load_proto_token)" ]]; then
        if [[ ! -f "$FIRST_RUN_MARKER" ]]; then
            set_config_value "$QUICK_SETUP_ASKED_KEY" "true"
            sudo mkdir -p "$(dirname "$FIRST_RUN_MARKER")"
            sudo touch "$FIRST_RUN_MARKER"
        fi
        return 0
    fi

    if [[ -f "$FIRST_RUN_MARKER" ]] || [[ "$(get_config_value "$QUICK_SETUP_ASKED_KEY")" == "true" ]]; then
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
        set_config_value "$QUICK_SETUP_ASKED_KEY" "true"
        sudo mkdir -p "$(dirname "$FIRST_RUN_MARKER")"
        sudo touch "$FIRST_RUN_MARKER"
        print_info "Instalação rápida pulada. Indo para o menu inicial..."
        return 0
    fi

    print_header
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${CYAN}                  INSTALAÇÃO RÁPIDA INICIAL                   ${BLUE}║${RESET}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BLUE}║${WHITE}  Esta instalação ativa TCP, UDP e QUIC.                      ${BLUE}║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    ensure_data_structure "true"
    check_or_set_proto_token
    prompt_for_proxy_token_if_missing

    local base_port=8000
    local quic_port=8001
    local required_ports=(80 443 8000 8001)
    local all_ports_free="true"

    print_warning "Antes de continuar, as portas abaixo precisam estar livres e serão ativadas nos seguintes serviços:"
    echo -e "${WHITE}  • ${CYAN}80${WHITE}   -> ${PROJECT_NAME}${RESET}"
    echo -e "${WHITE}  • ${CYAN}443${WHITE}  -> ${PROJECT_NAME} SSL${RESET}"
    echo -e "${WHITE}  • ${CYAN}8000${WHITE} -> Protocolo TCP/UDP${RESET}"
    echo -e "${WHITE}  • ${CYAN}8001${WHITE} -> Protocolo QUIC${RESET}"
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

    local subnet
    local tun
    subnet=$(get_config_value "VIRTUAL_SUBNET_CIDR")
    tun=$(get_config_value "TUN_INTERFACE")
    subnet=${subnet:-10.10.0.0/16}
    tun=${tun:-tun0}

    local protocol_components="tcp:$base_port,udp:$base_port,quic:$quic_port"
    set_config_value "PORT" "$base_port"
    set_config_value "VIRTUAL_SUBNET_CIDR" "$subnet"
    set_config_value "TUN_INTERFACE" "$tun"
    set_config_value "PROTOCOL_CONFIG" "$protocol_components"

    print_info "Aplicando configuração automática..."
    if create_systemd_service; then
        if sudo systemctl start "$SERVICE_NAME"; then
            sudo systemctl enable "$SERVICE_NAME" > /dev/null 2>&1
            print_success "Servidor protocolo iniciado com sucesso!"
            print_success "Protocolos: $protocol_components"
        else
            print_error "Falha ao iniciar o serviço protocolo."
            print_info "Verifique os logs: sudo journalctl -u $SERVICE_NAME -f"
            pause
            return 1
        fi
    else
        print_error "Falha ao criar serviço systemd."
        pause
        return 1
    fi

    init_proxy_dirs
    print_info "Configurando proxies automáticos: 80 (sem SSL) e 443 (com SSL)..."

    if start_proxy_for_port "80" "false" "" "false" "$DEFAULT_HTTP_RESPONSE"; then
        print_success "Proxy automático ativo na porta 80 (sem SSL)."
    else
        print_warning "Não foi possível ativar proxy automático na porta 80."
    fi

    if start_proxy_for_port "443" "true" "" "false" "$DEFAULT_HTTP_RESPONSE"; then
        print_success "Proxy automático ativo na porta 443 (com SSL)."
    else
        print_warning "Não foi possível ativar proxy automático na porta 443."
    fi

    set_config_value "$QUICK_SETUP_ASKED_KEY" "true"
    sudo mkdir -p "$(dirname "$FIRST_RUN_MARKER")"
    sudo touch "$FIRST_RUN_MARKER"
    print_success "Instalação rápida inicial concluída!"
    pause
}

protocol_main_menu() {
    while true; do
        print_header
        print_status
        print_main_menu
        
        local option
        read -rp "$(echo -e "${BLUE}Selecione uma opção [1-8]:${RESET} ")" option
        
        case "$option" in
            1) start_server ;;
            2) stop_server ;;
            3) restart_server ;;
            4) show_server_status ;;
            5) view_logs ;;
            6) change_port ;;
            7)
                print_info "Redirecionando para Gerenciar Tokens..."
                tokens_menu
                ;;
            8) change_auth_mode ;; 
            0) return 0 ;;
            *) 
                print_error "Opção inválida: $option"
                pause 
                ;;
        esac
    done
}

show_online_users_details() {
    while :; do
        print_header

        local online_count
        online_count=$(get_online_users_count)

        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
        local online_title="USUARIOS ONLINE (${online_count})"
        local online_title_padding=$((60 - ${#online_title}))
        printf "${BLUE}║${CYAN}  ${online_title}%${online_title_padding}s${BLUE}║${RESET}\n" ""
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo

        python3 - "$STATS_FILE" <<'PY'
import json
import sys
from datetime import datetime

path = sys.argv[1]

def fmt_bytes(value):
    try:
        value = float(value)
    except Exception:
        return "0 B"
    units = ["B", "KB", "MB", "GB", "TB"]
    idx = 0
    while value >= 1024 and idx < len(units) - 1:
        value /= 1024
        idx += 1
    return f"{value:.2f} {units[idx]}"

def fmt_duration(seconds):
    seconds = max(0, int(seconds))
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}"

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

if not isinstance(data, dict) or not data:
    print("Nenhum usuario online.")
    sys.exit(0)

for ip, info in data.items():
    if not isinstance(info, dict):
        continue
    user = info.get("id") or ip
    up = fmt_bytes(info.get("traffic_up", 0))
    down = fmt_bytes(info.get("traffic_down", 0))
    connected_at = info.get("connected_at")
    last_seen_at = info.get("last_seen_at")
    elapsed = "N/A"
    if connected_at and last_seen_at:
        try:
            c = datetime.strptime(connected_at, "%Y-%m-%d %H:%M:%S")
            l = datetime.strptime(last_seen_at, "%Y-%m-%d %H:%M:%S")
            elapsed = fmt_duration((l - c).total_seconds())
        except Exception:
            pass

    print(f"Usuário: {user}")
    print(f"IP: {ip}")
    print(f"Tráfego Up: {up}")
    print(f"Tráfego Down: {down}")
    print(f"Tempo conectado: {elapsed}")
    print("-" * 62)
PY
        echo
        echo -e "${YELLOW}Pressione Enter para voltar.${RESET}"
        if read -r -t 5; then
            break
        fi
    done
}

online_users_menu() {
    while true; do
        print_header

        local api_status="OFFLINE"
        local api_port
        api_port=$(get_online_api_port)
        local online_count
        online_count=$(get_online_users_count)

        if is_online_api_active; then
            api_status="ONLINE"
        fi

        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BLUE}║${WHITE}                     PAINEL DE ONLINES                        ${BLUE}║${RESET}"
        echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
        local status_line=" Api status: $api_status"
        local status_fill=$((62 - ${#status_line}))
        printf "${BLUE}║${WHITE}%s%${status_fill}s${BLUE}║${RESET}\n" "$status_line" ""
        if [[ -n "$api_port" ]]; then
            local port_line=" Api porta: $api_port"
            local port_fill=$((62 - ${#port_line}))
            printf "${BLUE}║${WHITE}%s%${port_fill}s${BLUE}║${RESET}\n" "$port_line" ""
        fi
        local online_line=" Usuarios online: $online_count"
        local online_fill=$((62 - ${#online_line}))
        printf "${BLUE}║${WHITE}%s%${online_fill}s${BLUE}║${RESET}\n" "$online_line" ""
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo

        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BLUE}║${WHITE}                           MENU                               ${BLUE}║${RESET}"
        echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${RESET}"
        local menu_items=("1 • Listar Onlines")
        if is_online_api_active; then
            menu_items+=("2 • Desativar API")
        else
            menu_items+=("2 • Ativar API")
        fi
        menu_items+=("0 • Voltar")
        for item in "${menu_items[@]}"; do
            local padding=$((60 - ${#item}))
            if [[ $item == 0* ]]; then
                printf "${BLUE}║${RED}  [${item%% *}] ${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
            else
                printf "${BLUE}║${WHITE}  [${CYAN}${item%% *}${WHITE}] ${BLUE}${item#* • }%${padding}s${BLUE}║${RESET}\n" ""
            fi
        done
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo

        local option
        read -rp "$(echo -e "${BLUE}Selecione uma opção [0-2]:${RESET} ")" option
        case "$option" in
            1) show_online_users_details ;;
            2)
                if is_online_api_active; then
                    deactivate_online_api
                else
                    activate_online_api
                fi
                ;;
            0) return 0 ;;
            *)
                print_error "Opção inválida: $option"
                pause
                ;;
        esac
    done
}

remove_completely() {
    print_header
    
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}                   ⚠️  REMOÇÃO COMPLETA ⚠️                    ${RED}║${RESET}"
    echo -e "${RED}║${WHITE}        Esta ação irá remover TODOS os dados e serviços       ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${YELLOW}Itens que serão removidos:${RESET}"
    echo -e "${WHITE}  • Serviço protocolo (proto-server)${RESET}"
    echo -e "${WHITE}  • Todos os serviços Proxy ativos${RESET}"
    echo -e "${WHITE}  • Serviço SSH Auth API${RESET}"
    echo -e "${WHITE}  • Ambiente virtual SSH Auth${RESET}"
    echo -e "${WHITE}  • Serviço Online API${RESET}"
    echo -e "${WHITE}  • Binários do sistema${RESET}"
    echo -e "${WHITE}  • Arquivos de configuração${RESET}"
    echo -e "${WHITE}  • Arquivos de dados e logs${RESET}"
    echo -e "${WHITE}  • Script de gerenciamento${RESET}"
    echo
    
    if ! confirm_action "${RED}TEM CERTEZA que deseja remover completamente?${RESET}" "n"; then
        print_info "Remoção cancelada."
        pause
        return
    fi
    
    print_info "Iniciando remoção completa..."
    
    if is_server_active; then
        print_info "Parando serviço $SERVICE_NAME..."
        sudo systemctl stop "$SERVICE_NAME"
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
    fi

    print_info "Parando serviço SSH Auth API..."
    if systemctl is-active --quiet ssh-auth-api; then
        sudo systemctl stop ssh-auth-api
        sudo systemctl disable ssh-auth-api 2>/dev/null
        sudo rm -f "/etc/systemd/system/ssh-auth-api.service"
    fi

    print_info "Removendo arquivos SSH Auth API..."
    sudo rm -f "/usr/local/bin/ssh_auth.py"
    sudo rm -rf "/usr/local/bin/ssh_auth_venv"

    print_info "Parando serviço Online API..."
    if systemctl is-active --quiet "$ONLINE_API_SERVICE_NAME"; then
        sudo systemctl stop "$ONLINE_API_SERVICE_NAME"
    fi
    sudo systemctl disable "$ONLINE_API_SERVICE_NAME" 2>/dev/null
    sudo rm -f "/etc/systemd/system/$ONLINE_API_SERVICE_NAME.service"
    sudo rm -f "$ONLINE_API_SCRIPT"
    sudo rm -f "$ONLINE_API_PORT_FILE"
    
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
    
    print_info "Removendo arquivos de serviço..."
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    
    print_info "Removendo binários..."
    sudo rm -f "$PROTO_SERVER_BIN"
    sudo rm -f "$PROXY_EXECUTABLE"
    sudo rm -f "/usr/local/bin/vt"
    sudo rm -f "/usr/local/bin/main"
    sudo rm -f "/usr/local/bin/proto"
    print_info "Removendo configurações e dados..."
    sudo rm -rf "$(dirname "$TOKEN_FILE")"
    sudo rm -rf "$(dirname "$CONFIG_FILE")"
    sudo rm -rf "$(dirname "$PROXY_TOKEN_VTPROXY")"
    sudo rm -rf "$DATA_DIR"
    sudo rm -rf "$PROXY_DIR"
    sudo rm -rf "$PROXY_LOG_DIR"
    sudo rm -f "$PROXY_TOKEN_HOME"
    print_success "Remoção completa concluída!"
    echo
    echo -e "${GREEN}Todos os serviços e arquivos foram removidos com sucesso.${RESET}"
    echo -e "${YELLOW}O sistema está limpo.${RESET}"
    echo
    
    pause
    exit 0
}

change_proxy_token_menu() {
    print_header

    local new_token
    while true; do
        echo -e "${BLUE}Insira o token proxy (licença ${PROJECT_NAME}):${RESET}"
        read -rp "> " new_token
        new_token=$(echo "$new_token" | tr -d '\000-\037')

        if [[ -z "$new_token" ]]; then
            print_error "Token não pode ser vazio."
            continue
        fi

        if validate_proxy_token "$new_token"; then
            save_proxy_token "$new_token"
            print_success "Token proxy salvo!"
            break
        else
            print_error "Token proxy inválido. Tente novamente."
        fi
    done
    pause
}

tokens_menu() {
    while true; do
        print_header
        local proxy_status="❌"
        local proto_status="❌"
        [[ -n "$(load_proxy_token)" ]] && proxy_status="✅"
        [[ -n "$(load_proto_token)" ]] && proto_status="✅"

        echo -e "${BLUE}╔$(printf '═%.0s' {1..62})╗${RESET}"
        echo -e "${BLUE}║${WHITE}                      GERENCIAR TOKENS                        ${BLUE}║${RESET}"
        echo -e "${BLUE}╠$(printf '═%.0s' {1..62})╣${RESET}"
        printf "${BLUE}║${WHITE}  Proxy (licença): %-43s${BLUE}║${RESET}\n" "$proxy_status"
        printf "${BLUE}║${WHITE}  Proto (protocolo): %-41s${BLUE}║${RESET}\n" "$proto_status"
        echo -e "${BLUE}╠$(printf '═%.0s' {1..62})╣${RESET}"
        echo -e "${BLUE}║${WHITE}  [1] Configurar token Proxy                                   ${BLUE}║${RESET}"
        echo -e "${BLUE}║${WHITE}  [2] Configurar token Proto                                   ${BLUE}║${RESET}"
        echo -e "${BLUE}║${RED}  [0] Voltar                                                   ${BLUE}║${RESET}"
        echo -e "${BLUE}╚$(printf '═%.0s' {1..62})╝${RESET}"
        echo

        local option
        read -rp "$(echo -e "${BLUE}Selecione uma opção [0-2]:${RESET} ")" option
        case "$option" in
            1) change_proxy_token_menu ;;
            2) change_token_menu ;;
            0) return 0 ;;
            *) print_error "Opção inválida: $option"; pause ;;
        esac
    done
}

initial_menu() {
    while true; do
        print_header
        print_status
        print_initial_menu
        
        local option
        read -rp "$(echo -e "${BLUE}Selecione uma opção [0-5]:${RESET} ")" option
        
        case "$option" in
            1) protocol_main_menu ;;
            2) connection_menu ;;
            3) online_users_menu ;;
            4) tokens_menu ;;
            5) remove_completely ;;
            0)
                print_info "Saindo..."
                exit 0
                ;;
            *)
                print_error "Opção inválida: $option"
                pause
                ;;
        esac
    done
}

if [ "$EUID" -ne 0 ]; then
    print_error "Este script requer privilégios de root."
    echo -e "${YELLOW}Execute com: ${WHITE}sudo $0${RESET}"
    exit 1
fi

check_token_on_startup

run_quick_setup_first_time

initial_menu

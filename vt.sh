#!/bin/bash

readonly PROJECT_NAME="VTProxy"
readonly MENU_BOX_MIN=34
readonly MENU_BOX_MAX=56
readonly MENU_REV="2026-07-22-udpgw-metrics-live"
readonly INSTALL_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh"
readonly MENU_BIN="/usr/local/bin/vt"
readonly PROXY_VERSION_FILE="/etc/proxy-version"
readonly PROTO_VERSION_FILE="/etc/proto-server-version"
readonly UDPGW_VERSION_FILE="/etc/udpgw-version"
readonly UDPGW_REPO="TelksBr/VeltrixUPGW"

# Largura interna da caixa (sem as bordas ║). Recalculada por refresh_menu_layout.
MENU_BOX_WIDTH=$MENU_BOX_MAX

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
    cut=$((max - 1))
    ((cut < 1)) && cut=1
    # "..." ASCII — reticência unicode quebra em alguns terminais mobile
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
        print_box_heading "Proxy + Protocolo"
    else
        print_box_heading "Proxy + Protocolo integrados"
    fi
    print_box_close
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

    local proxy_ports proxy_label proxy_tok proto_tok udpgw_status bound_ip
    proxy_ports=$(format_proxy_ports_status)
    proxy_label="${proxy_ports:-nenhuma}"
    [[ -n "$(load_proxy_token)" ]] && proxy_tok="$(mark_ok)" || proxy_tok="$(mark_fail)"
    [[ -n "$(load_proto_token)" ]] && proto_tok="$(mark_ok)" || proto_tok="$(mark_fail)"
    bound_ip=""
    [[ -f /etc/vtproxy/ip ]] && bound_ip=$(cat /etc/vtproxy/ip)

    local port subnet tun udpgw_ports udpgw_status
    port=$(get_config_value "PORT")
    subnet=$(get_config_value "VIRTUAL_SUBNET_CIDR")
    tun=$(get_config_value "TUN_INTERFACE")
    port=${port:-8000}
    subnet=${subnet:-10.10.0.0/16}
    tun=${tun:-tun0}
    udpgw_ports=$(format_udpgw_ports_status)
    if [[ "$udpgw_ports" == *":ON"* ]] || systemctl is-active --quiet "$UDPGW_SERVICE_NAME" 2>/dev/null; then
        udpgw_status="$(mark_online)"
    else
        udpgw_status="$(mark_offline)"
    fi

    print_box_open
    local status_badge="${status_bg}${BOLD}${status_color} ${proto_status} ${RESET}"

    if is_narrow_menu; then
        print_box_line "${WHITE}Proto: ${status_badge}${RESET}"
        print_box_line "${WHITE}Proxy: ${CYAN}${proxy_label}${RESET}"
        print_box_line "${WHITE}Tok P/R: ${proxy_tok} ${proto_tok}${RESET}"
        if [[ -n "$bound_ip" ]]; then
            print_box_line "${WHITE}IP: ${CYAN}${bound_ip}${RESET}"
        fi
        print_box_line "${WHITE}Proto:${CYAN}${port}${WHITE} TUN:${CYAN}${tun}${RESET}"
        print_box_line "${WHITE}Net: ${CYAN}${subnet}${RESET}"
        print_box_line "${WHITE}UDPgw: ${udpgw_status}${WHITE} ${CYAN}${udpgw_ports}${RESET}"
        print_box_line "${GRAY}${MENU_REV}${RESET}"
    else
        print_box_line "${WHITE} Proto: ${status_badge}${BLUE} | Proxy: ${CYAN}${proxy_label}${RESET}"
        local tokens_line="${WHITE} Tokens proxy: ${proxy_tok}  proto: ${proto_tok}"
        if [[ -n "$bound_ip" ]]; then
            tokens_line+="${WHITE} | IP: ${CYAN}${bound_ip}${RESET}"
        fi
        print_box_line "$tokens_line"
        print_box_line "${WHITE} Porta proto: ${CYAN}${port}${WHITE} | Sub-rede: ${CYAN}${subnet}${WHITE} | TUN: ${CYAN}${tun}${RESET}"
        print_box_line "${WHITE} UDP Gateway: ${udpgw_status}${WHITE} portas ${CYAN}${udpgw_ports}${RESET}"
        print_box_line "${WHITE} Menu: ${GRAY}${MENU_REV}${RESET}  (${MENU_BIN})"
    fi
    print_box_close
    echo
}

print_main_menu() {
    print_box_open
    print_box_heading "MENU PRINCIPAL"
    print_box_divider
    
    local menu_items=(
        "1 • Iniciar Servidor"
        "2 • Parar Servidor" 
        "3 • Reiniciar Servidor"
        "4 • Status & Configuração"
        "5 • Visualizar Logs"
        "6 • Alterar Porta"
        "7 • Gerenciar Tokens"
        "8 • Modo de Autenticação"
        "0 • Voltar ao Menu Inicial"
    )
    
    for item in "${menu_items[@]}"; do
        if [[ $item == *"Voltar"* ]]; then
            render_menu_option "$item" "red"
        else
            render_menu_option "$item"
        fi
    done
    
    print_box_close
    echo
}

print_initial_menu() {
    print_box_open
    print_box_heading "MENU INICIAL"
    print_box_divider
    
    local menu_items=(
        "1 • Servidor Protocolo"
        "2 • Proxy / Portas"
        "3 • Usuarios Online"
        "4 • Gerenciar Tokens"
        "5 • Atualizar Sistema"
        "6 • UDP Gateway (udpgw)"
        "7 • Remover Instalação"
        "0 • Sair"
    )
    
    for item in "${menu_items[@]}"; do
        if [[ $item == *"Remover"* || $item == *"Sair"* ]]; then
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

ensure_proxy_dirs_quiet() {
    sudo mkdir -p "$PROXY_DIR" "$PROXY_CONFIG_DIR" "$PROXY_LOG_DIR" 2>/dev/null || true
}

list_active_proxies() {
    local ports port service_name active_list=""
    ports=$(list_configured_proxy_ports)
    [[ -z "$ports" ]] && return 0

    IFS=',' read -ra port_array <<< "$ports"
    for port in "${port_array[@]}"; do
        [[ -z "$port" ]] && continue
        service_name=$(get_proxy_service_name "$port")
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            if [[ -n "$active_list" ]]; then
                active_list+=","
            fi
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
    local configured active port status_line="" mark extras
    configured=$(list_configured_proxy_ports)
    active=$(list_active_proxies)

    if [[ -z "$configured" ]]; then
        echo "nenhuma"
        return 0
    fi

    IFS=',' read -ra port_array <<< "$configured"
    for port in "${port_array[@]}"; do
        [[ -z "$port" ]] && continue
        if [[ ",${active}," == *",${port},"* ]]; then
            mark="ON"
        else
            mark="OFF"
        fi
        extras=$(format_proxy_port_flags "$port")
        if [[ -n "$status_line" ]]; then
            status_line+=", "
        fi
        if [[ -n "$extras" ]]; then
            status_line+="${port} ${mark} (${extras})"
        else
            status_line+="${port} ${mark}"
        fi
    done
    echo "$status_line"
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
    local domain_flag="$8"
    local max_connections="$9"
    local write_timeout="${10}"
    local idle_timeout="${11}"
    local log_level="${12}"
    local ssh_port="${13}"
    local openvpn_port="${14}"
    local v2ray_port="${15}"
    local display_banner="${16}"
    local file

    ensure_proxy_dirs_quiet
    file=$(get_proxy_config_file "$port")

    sudo tee "$file" > /dev/null <<EOF
PORT=$port
SSL_ENABLED=$ssl_enabled
SSL_CERT_PATH=$ssl_cert_path
CERT_INTERNAL=$cert_internal
SSH_ONLY=$ssh_only_flag
HTTP_RESPONSE=$http_response
BUFFER_SIZE=$buffer_size
DOMAIN=$domain_flag
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
    local domain="true"

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
    [[ "$exec_line" != *"--domain"* ]] && domain="false"

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
    # Mensagens em stderr: permite uso futuro em $(...) sem engolir o prompt.
    echo -e "${YELLOW}$message (s/N)${RESET}" >&2
    read -rp "> " response
    response=${response:-$default_answer}
    case "${response,,}" in
        s|sim|y|yes) return 0 ;;
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

build_proxy_command_from_conf() {
    local port="$1"
    local token="$2"

    migrate_proxy_conf_from_unit_if_needed "$port" || true

    local ssl_enabled ssl_cert_path cert_internal ssh_only_flag http_response
    local buffer_size domain_flag max_connections write_timeout idle_timeout
    local log_level ssh_port openvpn_port v2ray_port display_banner proto_port

    ssl_enabled=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    ssl_cert_path=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
    cert_internal=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    ssh_only_flag=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")
    http_response=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
    buffer_size=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    domain_flag=$(get_proxy_conf_value "$port" "DOMAIN" "true")
    max_connections=$(get_proxy_conf_value "$port" "MAX_CONNECTIONS" "0")
    write_timeout=$(get_proxy_conf_value "$port" "WRITE_TIMEOUT" "0")
    idle_timeout=$(get_proxy_conf_value "$port" "IDLE_TIMEOUT" "0")
    log_level=$(get_proxy_conf_value "$port" "LOG_LEVEL" "info")
    ssh_port=$(get_proxy_conf_value "$port" "SSH_PORT" "22")
    openvpn_port=$(get_proxy_conf_value "$port" "OPENVPN_PORT" "1194")
    v2ray_port=$(get_proxy_conf_value "$port" "V2RAY_PORT" "1080")
    display_banner=$(get_proxy_conf_value "$port" "DISPLAY_BANNER" "true")
    proto_port=$(get_proto_port)

    local command="$PROXY_EXECUTABLE --token=$token --buffer-size=$buffer_size --response=$http_response --log-file=$(get_proxy_log_file "$port") --log-level=$log_level --dt-proto-port=$proto_port --ssh-port=$ssh_port --openvpn-port=$openvpn_port --v2ray-port=$v2ray_port --max-connections=$max_connections --write-timeout=$write_timeout --idle-timeout=$idle_timeout"

    if [[ "$domain_flag" == "true" ]]; then
        command="$command --domain"
    fi

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
        "$http_response" "$DEFAULT_BUFFER_SIZE" "true" "0" "0" "0" "info" "22" "1194" "1080" "true"
    build_proxy_command_from_conf "$port" "$token"
}

write_proxy_systemd_unit() {
    local port="$1"
    local proxy_command="$2"
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
}

apply_proxy_service() {
    local port="$1"
    local do_start="${2:-true}"
    local token proxy_command service_name

    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy não configurado. Use Gerenciar Tokens no menu inicial."
        return 1
    fi

    migrate_proxy_conf_from_unit_if_needed "$port" || true
    if [[ ! -f "$(get_proxy_config_file "$port")" ]]; then
        print_error "Configuração da porta $port não encontrada."
        return 1
    fi

    proxy_command=$(build_proxy_command_from_conf "$port" "$token")
    write_proxy_systemd_unit "$port" "$proxy_command"
    service_name=$(get_proxy_service_name "$port")

    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name" > /dev/null 2>&1 || true

    if [[ "$do_start" == "true" ]]; then
        if sudo systemctl restart "$service_name"; then
            return 0
        fi
        return 1
    fi
    return 0
}

sync_all_proxy_tokens() {
    local token="$1"
    local port service_name updated=0

    [[ -n "$token" ]] || return 0

    for port in $(list_configured_proxy_ports | tr ',' ' '); do
        [[ -z "$port" ]] && continue
        migrate_proxy_conf_from_unit_if_needed "$port" || true
        if [[ -f "$(get_proxy_config_file "$port")" ]] || is_proxy_service_configured "$port"; then
            if apply_proxy_service "$port" "false"; then
                service_name=$(get_proxy_service_name "$port")
                if systemctl is-active --quiet "$service_name" 2>/dev/null; then
                    sudo systemctl restart "$service_name" 2>/dev/null || true
                fi
                updated=$((updated + 1))
            fi
        fi
    done

    echo "$updated"
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
        print_error "Token proxy não configurado. Use Gerenciar Tokens no menu inicial."
        return 1
    fi

    ensure_proto_for_proxy || return 1

    local cert_internal="true"
    if [[ "$ssl_enabled" == "true" && -n "$ssl_cert_path" ]]; then
        cert_internal="false"
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ssl_cert_path" "$cert_internal" "$ssh_only_flag" \
        "$http_response" "$DEFAULT_BUFFER_SIZE" "true" "0" "0" "0" "info" "22" "1194" "1080" "true"

    apply_proxy_service "$port" "true"
}

prompt_proxy_advanced_options() {
    # Edita globals ADV_* (já inicializados). Submenu interativo.
    local choice
    while true; do
        echo
        refresh_menu_layout
        print_box_open
        print_box_heading "OPÇÕES AVANÇADAS" "$CYAN"
        print_box_divider
        print_box_line "${WHITE}  1 • Buffer (--buffer-size): ${CYAN}${ADV_BUFFER_SIZE}${RESET}"
        print_box_line "${WHITE}  2 • Log level: ${CYAN}${ADV_LOG_LEVEL}${RESET}"
        print_box_line "${WHITE}  3 • Domain (--domain): ${CYAN}${ADV_DOMAIN}${RESET}"
        print_box_line "${WHITE}  4 • Backends SSH/OVPN/V2Ray: ${CYAN}${ADV_SSH_PORT}/${ADV_OPENVPN_PORT}/${ADV_V2RAY_PORT}${RESET}"
        print_box_line "${WHITE}  5 • Max conn / write / idle: ${CYAN}${ADV_MAX_CONNECTIONS}/${ADV_WRITE_TIMEOUT}/${ADV_IDLE_TIMEOUT}${RESET}"
        print_box_line "${WHITE}  6 • Banner (--display-banner): ${CYAN}${ADV_DISPLAY_BANNER}${RESET}"
        print_box_line "${WHITE}  7 • Cert interno (--cert-internal): ${CYAN}${ADV_CERT_INTERNAL}${RESET}"
        if [[ -n "${ADV_PORT:-}" ]]; then
            print_box_line "${WHITE}  8 • Ver ExecStart atual${RESET}"
            print_box_line "${WHITE}  9 • Salvar e aplicar na porta ${CYAN}${ADV_PORT}${RESET}"
        fi
        print_box_divider
        render_menu_option "0 • Concluir (voltar)" "red"
        print_box_close
        echo

        read -rp "$(echo -e "${BLUE}Selecione [0-9]:${RESET} ")" choice
        case "$choice" in
            1)
                ADV_BUFFER_SIZE=$(prompt_with_default "Buffer size em bytes (--buffer-size)" "$ADV_BUFFER_SIZE")
                if ! [[ "$ADV_BUFFER_SIZE" =~ ^[0-9]+$ ]] || [[ "$ADV_BUFFER_SIZE" -lt 1024 ]]; then
                    print_warning "Valor inválido; usando $DEFAULT_BUFFER_SIZE"
                    ADV_BUFFER_SIZE="$DEFAULT_BUFFER_SIZE"
                fi
                ;;
            2)
                ADV_LOG_LEVEL=$(prompt_with_default "Log level (debug|info|warn|error)" "$ADV_LOG_LEVEL")
                ;;
            3)
                if confirm_action "Gerar domínio automático (--domain)? (atual: $ADV_DOMAIN)" "$([[ "$ADV_DOMAIN" == "true" ]] && echo s || echo n)"; then
                    ADV_DOMAIN="true"
                else
                    ADV_DOMAIN="false"
                fi
                ;;
            4)
                ADV_SSH_PORT=$(prompt_with_default "Porta backend SSH (--ssh-port)" "$ADV_SSH_PORT")
                ADV_OPENVPN_PORT=$(prompt_with_default "Porta backend OpenVPN (--openvpn-port)" "$ADV_OPENVPN_PORT")
                ADV_V2RAY_PORT=$(prompt_with_default "Porta backend V2Ray (--v2ray-port)" "$ADV_V2RAY_PORT")
                ;;
            5)
                ADV_MAX_CONNECTIONS=$(prompt_with_default "Max connections (0=ilimitado)" "$ADV_MAX_CONNECTIONS")
                ADV_WRITE_TIMEOUT=$(prompt_with_default "Write timeout segundos (0=off)" "$ADV_WRITE_TIMEOUT")
                ADV_IDLE_TIMEOUT=$(prompt_with_default "Idle timeout segundos (0=off)" "$ADV_IDLE_TIMEOUT")
                ;;
            6)
                if confirm_action "Exibir banner de status (--display-banner)? (atual: $ADV_DISPLAY_BANNER)" "$([[ "$ADV_DISPLAY_BANNER" == "true" ]] && echo s || echo n)"; then
                    ADV_DISPLAY_BANNER="true"
                else
                    ADV_DISPLAY_BANNER="false"
                fi
                ;;
            7)
                if confirm_action "Usar certificado interno (--cert-internal)? (atual: $ADV_CERT_INTERNAL)" "$([[ "$ADV_CERT_INTERNAL" == "true" ]] && echo s || echo n)"; then
                    ADV_CERT_INTERNAL="true"
                    ADV_SSL_CERT_PATH=""
                else
                    ADV_CERT_INTERNAL="false"
                    ADV_SSL_CERT_PATH=$(prompt_with_default "Caminho do certificado externo" "${ADV_SSL_CERT_PATH:-/etc/ssl/cert.pem}")
                fi
                ;;
            8)
                if [[ -z "${ADV_PORT:-}" ]]; then
                    print_warning "ExecStart só está disponível após escolher uma porta configurada."
                    pause
                else
                    show_proxy_execstart_line "$ADV_PORT"
                    pause
                fi
                ;;
            9)
                if [[ -z "${ADV_PORT:-}" ]]; then
                    print_warning "Sem porta selecionada — use 'Concluir' na criação."
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
    ADV_MAX_CONNECTIONS="${2:-0}"
    ADV_WRITE_TIMEOUT="${3:-0}"
    ADV_IDLE_TIMEOUT="${4:-0}"
    ADV_LOG_LEVEL="${5:-info}"
    ADV_SSH_PORT="${6:-22}"
    ADV_OPENVPN_PORT="${7:-1194}"
    ADV_V2RAY_PORT="${8:-1080}"
    ADV_DOMAIN="${9:-true}"
    ADV_DISPLAY_BANNER="${10:-true}"
    ADV_CERT_INTERNAL="${11:-true}"
    ADV_SSL_CERT_PATH="${12:-}"
}

load_adv_from_port() {
    local port="$1"
    migrate_proxy_conf_from_unit_if_needed "$port" || true
    ADV_PORT="$port"
    ADV_APPLIED=0
    ADV_BUFFER_SIZE=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    ADV_MAX_CONNECTIONS=$(get_proxy_conf_value "$port" "MAX_CONNECTIONS" "0")
    ADV_WRITE_TIMEOUT=$(get_proxy_conf_value "$port" "WRITE_TIMEOUT" "0")
    ADV_IDLE_TIMEOUT=$(get_proxy_conf_value "$port" "IDLE_TIMEOUT" "0")
    ADV_LOG_LEVEL=$(get_proxy_conf_value "$port" "LOG_LEVEL" "info")
    ADV_SSH_PORT=$(get_proxy_conf_value "$port" "SSH_PORT" "22")
    ADV_OPENVPN_PORT=$(get_proxy_conf_value "$port" "OPENVPN_PORT" "1194")
    ADV_V2RAY_PORT=$(get_proxy_conf_value "$port" "V2RAY_PORT" "1080")
    ADV_DOMAIN=$(get_proxy_conf_value "$port" "DOMAIN" "true")
    ADV_DISPLAY_BANNER=$(get_proxy_conf_value "$port" "DISPLAY_BANNER" "true")
    ADV_CERT_INTERNAL=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    ADV_SSL_CERT_PATH=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
}

show_proxy_execstart_line() {
    local port="$1"
    local service_name exec_line
    service_name=$(get_proxy_service_name "$port")
    echo
    print_info "ExecStart da porta $port:"
    exec_line=$(systemctl cat "$service_name" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        echo -e "${GRAY}$exec_line${RESET}"
    else
        print_warning "Unit systemd ainda não existe para esta porta."
    fi
}

apply_adv_globals_to_port() {
    local port="$1"
    local ssl_enabled ssh_only http_response was_active="false"

    ssl_enabled=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    ssh_only=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")
    http_response=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")

    # Se marcou cert externo, força SSL (senão --cert-internal não faz sentido sozinho).
    if [[ "$ADV_CERT_INTERNAL" == "false" && -n "$ADV_SSL_CERT_PATH" ]]; then
        ssl_enabled="true"
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ADV_SSL_CERT_PATH" "$ADV_CERT_INTERNAL" "$ssh_only" \
        "$http_response" "$ADV_BUFFER_SIZE" "$ADV_DOMAIN" "$ADV_MAX_CONNECTIONS" "$ADV_WRITE_TIMEOUT" \
        "$ADV_IDLE_TIMEOUT" "$ADV_LOG_LEVEL" "$ADV_SSH_PORT" "$ADV_OPENVPN_PORT" "$ADV_V2RAY_PORT" "$ADV_DISPLAY_BANNER"

    systemctl is-active --quiet "$(get_proxy_service_name "$port")" 2>/dev/null && was_active="true"

    if apply_proxy_service "$port" "$was_active"; then
        if [[ "$was_active" == "true" ]]; then
            print_success "Opções avançadas aplicadas e serviço reiniciado (porta $port)."
        else
            print_success "Opções avançadas salvas na porta $port (serviço parado)."
        fi
        show_proxy_execstart_line "$port"
    else
        print_error "Falha ao aplicar opções avançadas na porta $port."
    fi
    pause
}

edit_proxy_advanced_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta configurada. Abra uma porta antes."
        pause
        return
    fi

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para opções avançadas:${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    load_adv_from_port "$port"
    print_info "Editando opções avançadas da porta $port (inclui buffer)."
    prompt_proxy_advanced_options
    if [[ "${ADV_APPLIED:-0}" != "1" ]]; then
        apply_adv_globals_to_port "$port"
    fi
}

change_proxy_http_response() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    if [[ -z "$configured_ports" ]]; then
        print_error "Nenhuma porta proxy configurada."
        pause
        return
    fi

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para alterar a resposta HTTP (--response):${RESET}"
    read -rp "> " port
    port=$(echo "$port" | tr -d '[:space:]')

    if ! validate_port "$port" || ! is_proxy_service_configured "$port"; then
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    migrate_proxy_conf_from_unit_if_needed "$port" || true
    local current_response
    current_response=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")

    echo -e "${BLUE}Resposta atual: ${GREEN}$current_response${RESET}"
    local new_response
    new_response=$(prompt_with_default "Nova resposta HTTP" "$current_response")
    new_response=$(echo "$new_response" | tr -d '[:space:]')

    if [[ -z "$new_response" ]]; then
        print_error "Resposta não pode ser vazia."
        pause
        return
    fi

    set_proxy_conf_key "$port" "HTTP_RESPONSE" "$new_response"
    if apply_proxy_service "$port" "true"; then
        print_success "Resposta HTTP da porta $port atualizada para '$new_response'."
    else
        print_error "Falha ao aplicar alteração na porta $port."
    fi
    pause
}

# Alias legado
change_proxy_status() {
    change_proxy_http_response
}

sync_proxy_dtproto_port() {
    local new_proto_port="$1"
    local port updated_any="false"

    for port in $(list_configured_proxy_ports | tr ',' ' '); do
        [[ -z "$port" ]] && continue
        migrate_proxy_conf_from_unit_if_needed "$port" || true
        if [[ -f "$(get_proxy_config_file "$port")" ]]; then
            if apply_proxy_service "$port" "false"; then
                updated_any="true"
                if systemctl is-active --quiet "$(get_proxy_service_name "$port")" 2>/dev/null; then
                    sudo systemctl restart "$(get_proxy_service_name "$port")" 2>/dev/null || true
                fi
            fi
        fi
    done

    [[ "$updated_any" == "true" ]] && sudo systemctl daemon-reload
    _="$new_proto_port"
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
        if ! confirm_action "Porta $port já configurada. Sobrescrever?" "n"; then
            pause
            return
        fi
    fi
    
    local ssl_enabled="false"
    local ssl_cert_path=""
    local cert_internal="true"
    
    if confirm_action "Deseja habilitar SSL?" "n"; then
        ssl_enabled="true"
        if confirm_action "Usar certificado interno (--cert-internal)?" "s"; then
            cert_internal="true"
        else
            cert_internal="false"
            echo -e "${BLUE}Caminho do certificado SSL:${RESET}"
            read -rp "> " ssl_cert_path
        fi
    fi
    
    local http_response
    http_response=$(prompt_with_default "Resposta HTTP (--response)" "$DEFAULT_HTTP_RESPONSE")
    
    local ssh_only_flag="false"
    if confirm_action "Habilitar modo somente SSH (--ssh-only)?" "n"; then
        ssh_only_flag="true"
    fi

    local buffer_size
    buffer_size=$(prompt_with_default "Buffer size (--buffer-size, bytes)" "$DEFAULT_BUFFER_SIZE")
    if ! [[ "$buffer_size" =~ ^[0-9]+$ ]] || [[ "$buffer_size" -lt 1024 ]]; then
        print_warning "Buffer inválido; usando $DEFAULT_BUFFER_SIZE"
        buffer_size="$DEFAULT_BUFFER_SIZE"
    fi

    local domain_flag="true"
    local max_connections="0"
    local write_timeout="0"
    local idle_timeout="0"
    local log_level="info"
    local ssh_port="22"
    local openvpn_port="1194"
    local v2ray_port="1080"
    local display_banner="true"

    init_adv_defaults "$buffer_size" "0" "0" "0" "info" "22" "1194" "1080" "true" "true" "$cert_internal" "$ssl_cert_path"
    if confirm_action "Abrir submenu de opções avançadas (log, domain, backends, timeouts...)?" "n"; then
        prompt_proxy_advanced_options
        buffer_size="$ADV_BUFFER_SIZE"
        max_connections="$ADV_MAX_CONNECTIONS"
        write_timeout="$ADV_WRITE_TIMEOUT"
        idle_timeout="$ADV_IDLE_TIMEOUT"
        log_level="$ADV_LOG_LEVEL"
        ssh_port="$ADV_SSH_PORT"
        openvpn_port="$ADV_OPENVPN_PORT"
        v2ray_port="$ADV_V2RAY_PORT"
        domain_flag="$ADV_DOMAIN"
        display_banner="$ADV_DISPLAY_BANNER"
        cert_internal="$ADV_CERT_INTERNAL"
        ssl_cert_path="$ADV_SSL_CERT_PATH"
        if [[ "$cert_internal" == "false" && -n "$ssl_cert_path" ]]; then
            ssl_enabled="true"
        fi
    fi
    
    print_info "Iniciando proxy na porta $port..."
    ensure_proto_for_proxy || { pause; return; }

    local token
    token=$(load_proxy_token)
    if [[ -z "$token" ]]; then
        print_error "Token proxy não configurado."
        pause
        return
    fi

    if ! check_port_available "$port"; then
        pause
        return
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ssl_cert_path" "$cert_internal" "$ssh_only_flag" \
        "$http_response" "$buffer_size" "$domain_flag" "$max_connections" "$write_timeout" \
        "$idle_timeout" "$log_level" "$ssh_port" "$openvpn_port" "$v2ray_port" "$display_banner"

    if apply_proxy_service "$port" "true"; then
        print_success "Proxy iniciado com sucesso na porta $port!"
        show_proxy_execstart_line "$port"
    else
        print_error "Falha ao iniciar proxy na porta $port"
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

    local service_name
    service_name=$(get_proxy_service_name "$port")
    print_info "Parando proxy na porta $port (config preservada)..."
    sudo systemctl stop "$service_name" 2>/dev/null || true
    print_success "Proxy na porta $port parado. Use 'Iniciar porta configurada' para religar."
    pause
}

remove_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)
    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
    echo -e "${BLUE}Digite a porta para REMOVER (apaga unit + conf):${RESET}"
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

    local service_name
    service_name=$(get_proxy_service_name "$port")
    print_info "Removendo proxy na porta $port..."
    sudo systemctl stop "$service_name" 2>/dev/null || true
    sudo systemctl disable "$service_name" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/$service_name.service"
    sudo rm -f "$(get_proxy_config_file "$port")"
    sudo systemctl daemon-reload
    print_success "Proxy na porta $port removido."
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
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    migrate_proxy_conf_from_unit_if_needed "$port" || true
    ensure_proto_for_proxy || { pause; return; }

    local service_name
    service_name=$(get_proxy_service_name "$port")
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        print_warning "Porta $port já está ativa."
        pause
        return
    fi

    if ! check_port_available "$port"; then
        pause
        return
    fi

    print_info "Iniciando porta $port..."
    if apply_proxy_service "$port" "true"; then
        print_success "Porta $port iniciada."
    else
        print_error "Falha ao iniciar porta $port."
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
        print_error "Porta inválida ou não configurada."
        pause
        return
    fi

    migrate_proxy_conf_from_unit_if_needed "$port" || true

    local ssl_enabled ssl_cert_path cert_internal ssh_only_flag http_response
    local buffer_size domain_flag max_connections write_timeout idle_timeout
    local log_level ssh_port openvpn_port v2ray_port display_banner

    ssl_enabled=$(get_proxy_conf_value "$port" "SSL_ENABLED" "false")
    ssl_cert_path=$(get_proxy_conf_value "$port" "SSL_CERT_PATH" "")
    cert_internal=$(get_proxy_conf_value "$port" "CERT_INTERNAL" "true")
    ssh_only_flag=$(get_proxy_conf_value "$port" "SSH_ONLY" "false")
    http_response=$(get_proxy_conf_value "$port" "HTTP_RESPONSE" "$DEFAULT_HTTP_RESPONSE")
    buffer_size=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    domain_flag=$(get_proxy_conf_value "$port" "DOMAIN" "true")
    max_connections=$(get_proxy_conf_value "$port" "MAX_CONNECTIONS" "0")
    write_timeout=$(get_proxy_conf_value "$port" "WRITE_TIMEOUT" "0")
    idle_timeout=$(get_proxy_conf_value "$port" "IDLE_TIMEOUT" "0")
    log_level=$(get_proxy_conf_value "$port" "LOG_LEVEL" "info")
    ssh_port=$(get_proxy_conf_value "$port" "SSH_PORT" "22")
    openvpn_port=$(get_proxy_conf_value "$port" "OPENVPN_PORT" "1194")
    v2ray_port=$(get_proxy_conf_value "$port" "V2RAY_PORT" "1080")
    display_banner=$(get_proxy_conf_value "$port" "DISPLAY_BANNER" "true")

    echo
    print_info "Editando porta $port (Enter mantém o valor atual)."
    echo

    if confirm_action "SSL habilitado? (atual: $ssl_enabled)" "$([[ "$ssl_enabled" == "true" ]] && echo s || echo n)"; then
        ssl_enabled="true"
        if confirm_action "Usar certificado interno? (atual: $cert_internal)" "$([[ "$cert_internal" == "true" ]] && echo s || echo n)"; then
            cert_internal="true"
            ssl_cert_path=""
        else
            cert_internal="false"
            ssl_cert_path=$(prompt_with_default "Caminho do certificado" "${ssl_cert_path:-/path/cert.pem}")
        fi
    else
        ssl_enabled="false"
        cert_internal="true"
        ssl_cert_path=""
    fi

    http_response=$(prompt_with_default "Resposta HTTP" "$http_response")
    if confirm_action "Modo ssh-only? (atual: $ssh_only_flag)" "$([[ "$ssh_only_flag" == "true" ]] && echo s || echo n)"; then
        ssh_only_flag="true"
    else
        ssh_only_flag="false"
    fi

    buffer_size=$(prompt_with_default "Buffer size (--buffer-size, bytes)" "$buffer_size")
    if ! [[ "$buffer_size" =~ ^[0-9]+$ ]] || [[ "$buffer_size" -lt 1024 ]]; then
        print_warning "Buffer inválido; mantendo valor anterior."
        buffer_size=$(get_proxy_conf_value "$port" "BUFFER_SIZE" "$DEFAULT_BUFFER_SIZE")
    fi

    init_adv_defaults "$buffer_size" "$max_connections" "$write_timeout" "$idle_timeout" \
        "$log_level" "$ssh_port" "$openvpn_port" "$v2ray_port" "$domain_flag" "$display_banner" \
        "$cert_internal" "$ssl_cert_path"
    ADV_PORT="$port"

    if confirm_action "Abrir submenu de opções avançadas?" "n"; then
        prompt_proxy_advanced_options
        buffer_size="$ADV_BUFFER_SIZE"
        max_connections="$ADV_MAX_CONNECTIONS"
        write_timeout="$ADV_WRITE_TIMEOUT"
        idle_timeout="$ADV_IDLE_TIMEOUT"
        log_level="$ADV_LOG_LEVEL"
        ssh_port="$ADV_SSH_PORT"
        openvpn_port="$ADV_OPENVPN_PORT"
        v2ray_port="$ADV_V2RAY_PORT"
        domain_flag="$ADV_DOMAIN"
        display_banner="$ADV_DISPLAY_BANNER"
        cert_internal="$ADV_CERT_INTERNAL"
        ssl_cert_path="$ADV_SSL_CERT_PATH"
        if [[ "$cert_internal" == "false" && -n "$ssl_cert_path" ]]; then
            ssl_enabled="true"
        fi
    fi

    write_proxy_conf "$port" "$ssl_enabled" "$ssl_cert_path" "$cert_internal" "$ssh_only_flag" \
        "$http_response" "$buffer_size" "$domain_flag" "$max_connections" "$write_timeout" \
        "$idle_timeout" "$log_level" "$ssh_port" "$openvpn_port" "$v2ray_port" "$display_banner"

    local was_active="false"
    systemctl is-active --quiet "$(get_proxy_service_name "$port")" 2>/dev/null && was_active="true"

    if apply_proxy_service "$port" "$was_active"; then
        if [[ "$was_active" == "true" ]]; then
            print_success "Porta $port atualizada e reiniciada."
        else
            print_success "Configuração da porta $port salva (serviço parado)."
        fi
        show_proxy_execstart_line "$port"
    else
        print_error "Falha ao aplicar configuração da porta $port."
    fi
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
        print_error "Porta inválida ou não configurada."
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
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
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
    print_box_line "${WHITE}  Domain: ${CYAN}$(get_proxy_conf_value "$port" DOMAIN true)${RESET}"
    print_box_line "${WHITE}  dt-proto-port: ${CYAN}$(get_proto_port)${RESET}"
    print_box_line "${WHITE}  Conf: ${CYAN}$conf_file${RESET}"
    print_box_line "${WHITE}  Log/banner file: ${CYAN}$(get_proxy_log_file "$port")${RESET}"
    print_box_divider
    local exec_line
    exec_line=$(systemctl cat "$service_name" 2>/dev/null | grep -E '^ExecStart=' | head -n1 | sed 's/^ExecStart=//')
    if [[ -n "$exec_line" ]]; then
        print_box_line "${WHITE}  ExecStart:${RESET}"
        echo -e "${GRAY}$exec_line${RESET}"
    else
        print_box_line "${YELLOW}  Unit systemd ainda não criada${RESET}"
    fi
    print_box_close
    pause
}

restart_proxy_service() {
    print_header

    local configured_ports
    configured_ports=$(list_configured_proxy_ports)

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
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

    migrate_proxy_conf_from_unit_if_needed "$port" || true
    print_info "Reiniciando proxy na porta $port..."

    if apply_proxy_service "$port" "true"; then
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

    echo -e "${BLUE}Portas: ${GREEN}$(format_proxy_ports_status)${RESET}"
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
        print_error "Arquivo de log/banner não encontrado: $log_file"
        print_info "Verifique: systemctl status $(get_proxy_service_name "$port")"
        pause
        return
    fi

    echo -e "${BLUE}Exibindo banner/status da porta $port (Ctrl+C para sair):${RESET}"
    echo
    sudo tail -n 80 -f "$log_file" || true
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
        print_box_heading "${PROJECT_NAME} — PROXY" "$CYAN"
        print_box_line "${WHITE}  Portas: ${CYAN}${ports_status}${RESET}"
        print_box_divider
        
        local menu_items=(
            "1 • Abrir / criar porta"
            "2 • Iniciar porta configurada"
            "3 • Parar porta (mantém config)"
            "4 • Reiniciar porta"
            "5 • Editar porta"
            "6 • Opções avançadas (buffer/flags)"
            "7 • Alterar resposta HTTP"
            "8 • Detalhes / ExecStart"
            "9 • Ver log da porta"
            "A • Remover porta"
            "0 • Voltar ao Menu Inicial"
        )
        
        for item in "${menu_items[@]}"; do
            if [[ $item == *"Voltar"* || $item == *"Remover"* ]]; then
                render_menu_option "$item" "red"
            else
                render_menu_option "$item"
            fi
        done
        
        print_box_close
        echo
        
        local choice
        read -rp "$(echo -e "${BLUE}Selecione [0-9/A]:${RESET} ")" choice
        
        case "$choice" in
            1) start_proxy_service ;;
            2) start_configured_proxy_service ;;
            3) pause_proxy_service ;;
            4) restart_proxy_service ;;
            5) edit_proxy_service ;;
            6) edit_proxy_advanced_service ;;
            7) change_proxy_http_response ;;
            8) show_proxy_port_details ;;
            9) show_proxy_logs ;;
            a|A) remove_proxy_service ;;
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

    print_box_open
    print_box_line "${CYAN}  CONFIGURACOES ATUAIS${RESET}"
    print_box_divider
    print_box_line "${WHITE}  Porta: ${BLUE}${port}${RESET}"
    print_box_line "${WHITE}  Sub-rede: ${BLUE}${subnet}${RESET}"
    print_box_line "${WHITE}  Interface TUN: ${BLUE}${tun}${RESET}"
    if [[ -n "$protocol_config" ]]; then
        print_box_line "${WHITE}  Protocolos: ${BLUE}${protocol_config}${RESET}"
    fi
    print_box_close
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
    
    print_box_open
    print_box_line "${CYAN}  STATUS DO SISTEMA${RESET}"
    print_box_divider
    
    local port=$(get_config_value 'PORT')
    local subnet=$(get_config_value 'VIRTUAL_SUBNET_CIDR')
    local tun=$(get_config_value 'TUN_INTERFACE')
    local auth_mode=$(get_config_value 'AUTH_MODE')
    auth_mode=${auth_mode:-$AUTH_MODE_FILE}
    local auth_url=$(get_config_value 'AUTH_URL')
    local protocol_config=$(get_config_value 'PROTOCOL_CONFIG')
    local token_status
    if [[ -f "$TOKEN_FILE" ]]; then
        token_status="$(mark_ok)"
    else
        token_status="$(mark_fail)"
    fi
    
    if is_server_active; then
        print_box_line "${WHITE}  Status: $(mark_online)${RESET}"
    else
        print_box_line "${WHITE}  Status: $(mark_offline)${RESET}"
    fi
    
    print_box_line "${WHITE}  Porta: ${BLUE}${port:-8000}${RESET}"
    print_box_line "${WHITE}  Sub-rede: ${BLUE}${subnet:-10.10.0.0/16}${RESET}"
    print_box_line "${WHITE}  TUN: ${BLUE}${tun:-tun0}${RESET}"
    if [[ -n "$protocol_config" ]]; then
        print_box_line "${WHITE}  Protocolos: ${BLUE}${protocol_config}${RESET}"
    fi
    print_box_line "${WHITE}  Token: ${token_status}${RESET}"
    
    local auth_display=""
    case "$auth_mode" in
        $AUTH_MODE_FILE) auth_display="Arquivo" ;;
        $AUTH_MODE_URL) auth_display="URL ($auth_url)" ;;
        $AUTH_MODE_SSH) auth_display="SSH/PAM" ;; 
        $AUTH_MODE_NONE) auth_display="Nenhuma" ;;
        *) auth_display="Arquivo" ;;
    esac
    print_box_line "${WHITE}  Auth: ${BLUE}${auth_display}${RESET}"
    
    print_box_close
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
    
    print_box_open
    print_box_heading "ALTERAR MODO DE AUTENTICAÇÃO" "$CYAN"
    print_box_divider
    
    print_box_line "${WHITE}  Modo atual: ${GREEN}${current_mode}${RESET}"
    
    if [[ "$current_mode" == "$AUTH_MODE_URL" && -n "$current_url" ]]; then
        print_box_line "${WHITE}  URL atual: ${CYAN}${current_url}${RESET}"
    fi
    
    print_box_divider
    
    local menu_items=(
        "1 • Arquivo ($CREDENTIALS_FILE)"
        "2 • URL personalizada"
        "3 • SSH" 
        "4 • Sem autenticação"
        "0 • Voltar"
    )
    
    for item in "${menu_items[@]}"; do
        if [[ $item == *"Voltar"* ]]; then
            render_menu_option "$item" "red"
        else
            render_menu_option "$item"
        fi
    done
    
    print_box_close
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
    local is_running="false"
    if is_server_active; then
        is_running="true"
    fi

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
    sudo mkdir -p /etc/udpgw "$UDPGW_CONFIG_DIR" 2>/dev/null || true
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
    local metrics_listen listen

    metrics_listen=$(suggest_udpgw_metrics_listen "$port")
    listen="0.0.0.0:${port}"

    sudo tee "$(get_udpgw_config_file "$port")" >/dev/null <<EOF
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
    local configured port mark line="" active_ports=""
    configured=$(list_configured_udpgw_ports)

    if [[ -z "$configured" ]]; then
        echo "nenhuma"
        return 0
    fi

    IFS=',' read -ra pa <<< "$configured"
    for port in "${pa[@]}"; do
        [[ -z "$port" ]] && continue
        if is_udpgw_port_active "$port"; then
            mark="ON"
            [[ -n "$active_ports" ]] && active_ports+=","
            active_ports+="$port"
        else
            mark="OFF"
        fi
        if [[ -n "$line" ]]; then line+=","; fi
        line+="${port}:${mark}"
    done
    echo "$line"
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
        write_udpgw_conf_new "$port"
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
    print_box_heading "UDP GATEWAY (udpgw)"
    print_box_divider
    print_box_line "${WHITE}  Portas: ${CYAN}${ports_status}${RESET}"
    print_box_divider
    local menu_items=(
        "1 • Abrir / criar porta"
        "2 • Iniciar porta"
        "3 • Parar porta"
        "4 • Reiniciar porta"
        "5 • Status & ExecStart"
        "6 • Painel de metricas"
        "7 • Visualizar logs"
        "8 • Opcoes avancadas (flags)"
        "9 • Instalar/atualizar binario"
        "A • Remover porta"
        "0 • Voltar ao Menu Inicial"
    )
    for item in "${menu_items[@]}"; do
        if [[ $item == *"Voltar"* || $item == *"Remover"* ]]; then
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
        read -rp "$(echo -e "${BLUE}Selecione [0-9/A]:${RESET} ")" option
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
        *) print_error "Opcao invalida: $option"; pause ;;
        esac
    done
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

        print_box_open
        print_box_heading "USUARIOS ONLINE (${online_count})" "$CYAN"
        print_box_close
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

        local api_status
        local api_port
        api_port=$(get_online_api_port)
        local online_count
        online_count=$(get_online_users_count)

        if is_online_api_active; then
            api_status="$(mark_online)"
        else
            api_status="$(mark_offline)"
        fi

        print_box_open
        print_box_heading "PAINEL DE ONLINES"
        print_box_divider
        print_box_line "${WHITE} Api status: ${api_status}${RESET}"
        if [[ -n "$api_port" ]]; then
            print_box_line "${WHITE} Api porta: ${api_port}${RESET}"
        fi
        print_box_line "${WHITE} Usuarios online: ${online_count}${RESET}"
        print_box_close
        echo

        print_box_open
        print_box_heading "MENU"
        print_box_divider
        local menu_items=("1 • Listar Onlines")
        if is_online_api_active; then
            menu_items+=("2 • Desativar API")
        else
            menu_items+=("2 • Ativar API")
        fi
        menu_items+=("0 • Voltar")
        for item in "${menu_items[@]}"; do
            if [[ $item == 0* ]]; then
                render_menu_option "$item" "red"
            else
                render_menu_option "$item"
            fi
        done
        print_box_close
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

get_installed_proto_version_label() {
    local ver=""
    if [[ -x "$PROTO_SERVER_BIN" ]]; then
        ver=$("$PROTO_SERVER_BIN" --version 2>/dev/null | awk '{print $NF}' | tr -d 'v' || true)
    fi
    if [[ -z "$ver" && -f "$PROTO_VERSION_FILE" ]]; then
        ver=$(tr -d '\r\n' <"$PROTO_VERSION_FILE")
    fi
    echo "${ver:-desconhecida}"
}

show_update_preserve_notice() {
    echo -e "${WHITE}O que será atualizado:${RESET}"
    echo -e "${CYAN}  • Binário proxy-server${RESET}"
    echo -e "${CYAN}  • Binário proto-server${RESET}"
    echo -e "${CYAN}  • Binário udpgw (UDP Gateway)${RESET}"
    echo -e "${CYAN}  • Menu vt (este menu)${RESET}"
    echo
    echo -e "${WHITE}O que é PRESERVADO:${RESET}"
    echo -e "${GREEN}  • Tokens proxy e proto${RESET}"
    echo -e "${GREEN}  • Units systemd e configs de portas (/etc/proxy/conf.d)${RESET}"
    echo -e "${GREEN}  • Config do proto (/etc/proto-server)${RESET}"
    echo -e "${GREEN}  • Config do udpgw (/etc/udpgw)${RESET}"
    echo -e "${GREEN}  • Credenciais, certs e dados${RESET}"
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

    if ! curl -fsSL "$INSTALL_URL" | bash -s -- "${args[@]}"; then
        print_error "Falha na atualização."
        print_info "Tente manualmente: curl -fsSL ${INSTALL_URL} | bash -s -- --update --yes"
        pause
        return 1
    fi

    print_success "Atualização concluída (binários + menu)."
    echo
    print_info "Proxy: v$(get_installed_proxy_version_label) | Proto: v$(get_installed_proto_version_label) | UDPgw: v$(get_installed_udpgw_version_label)"

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

    local proxy_ver proto_ver udpgw_ver
    proxy_ver=$(get_installed_proxy_version_label)
    proto_ver=$(get_installed_proto_version_label)
    udpgw_ver=$(get_installed_udpgw_version_label)

    print_box_open
    print_box_heading "ATUALIZAR SISTEMA" "$CYAN"
    print_box_divider
    print_box_line "${WHITE}  Proxy instalado: ${GREEN}v${proxy_ver}${RESET}"
    print_box_line "${WHITE}  Proto instalado: ${GREEN}v${proto_ver}${RESET}"
    print_box_line "${WHITE}  UDPgw instalado: ${GREEN}v${udpgw_ver}${RESET}"
    print_box_close
    echo

    show_update_preserve_notice
    echo

    if ! confirm_action "Atualizar binários (proxy/proto/udpgw) e o menu vt agora?" "s"; then
        print_info "Atualização cancelada."
        pause
        return 0
    fi

    run_system_update
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
    echo -e "${WHITE}  • Serviço UDP Gateway (udpgw)${RESET}"
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
    
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    sudo rm -f "/etc/systemd/system/${UDPGW_SERVICE_NAME}.service"
    
    print_info "Removendo binários..."
    sudo rm -f "$PROTO_SERVER_BIN"
    sudo rm -f "$UDPGW_BIN"
    sudo rm -f "$PROXY_EXECUTABLE"
    sudo rm -f "/usr/local/bin/vt"
    sudo rm -f "/usr/local/bin/main"
    sudo rm -f "/usr/local/bin/proto"
    print_info "Removendo configurações e dados..."
    sudo rm -rf "$(dirname "$TOKEN_FILE")"
    sudo rm -rf "$(dirname "$CONFIG_FILE")"
    sudo rm -rf /etc/udpgw
    sudo rm -f "$UDPGW_VERSION_FILE"
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
            print_info "Sincronizando token nos serviços proxy..."
            local updated
            updated=$(sync_all_proxy_tokens "$new_token")
            print_success "Token aplicado em $updated porta(s) proxy."
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
        local proxy_status proto_status
        if [[ -n "$(load_proxy_token)" ]]; then
            proxy_status="$(mark_ok)"
        else
            proxy_status="$(mark_fail)"
        fi
        if [[ -n "$(load_proto_token)" ]]; then
            proto_status="$(mark_ok)"
        else
            proto_status="$(mark_fail)"
        fi

        print_box_open
        print_box_heading "GERENCIAR TOKENS"
        print_box_divider
        print_box_line "${WHITE}  Proxy (licença): ${proxy_status}${RESET}"
        print_box_line "${WHITE}  Proto (protocolo): ${proto_status}${RESET}"
        print_box_divider
        render_menu_option "1 • Configurar token Proxy"
        render_menu_option "2 • Configurar token Proto"
        render_menu_option "0 • Voltar" "red"
        print_box_close
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
        read -rp "$(echo -e "${BLUE}Selecione uma opção [0-7]:${RESET} ")" option
        
        case "$option" in
            1) protocol_main_menu ;;
            2) connection_menu ;;
            3) online_users_menu ;;
            4) tokens_menu ;;
            5) update_system_menu ;;
            6) udpgw_main_menu ;;
            7) remove_completely ;;
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

migrate_legacy_udpgw_if_needed || true
udpgw_fix_all_metrics_collisions || true

initial_menu

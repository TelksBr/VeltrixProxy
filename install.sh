#!/bin/bash
set -euo pipefail

REPO="TelksBr/VeltrixProxy"
PROJECT_NAME="VTProxy"
INSTALL_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh"
MENU_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/vt.sh"
# Artefato proxy no GitHub (padrão original): proxy-linux-amd64
RELEASE_BINARY_PREFIX="proxy"
# Artefato proto: proto-server-linux-amd64
PROTO_RELEASE_BINARY_PREFIX="proto-server"
PROTO_REPO="${PROTO_REPO:-TelksBr/VeltrixProxy}"
PROTO_FALLBACK_REPO="${PROTO_FALLBACK_REPO:-DTunnel0/DTProto-Server-Releases}"
# Binário instalado (novo nome — não sobrescreve /usr/local/bin/proxy legado)
BINARY_NAME="proxy-server"
PROTO_BINARY_NAME="proto-server"
MENU_NAME="vt"
INSTALL_DIR="/usr/local/bin"
PROTO_CONFIG_FILE="/etc/proto-server/config.conf"
PROTO_DATA_DIR="/var/lib/proto-server"
PROTO_CREDENTIALS_FILE="${PROTO_DATA_DIR}/credentials.json"
PROTO_STATS_FILE="${PROTO_DATA_DIR}/stats.json"
PROTO_CERT_FILE="${PROTO_DATA_DIR}/cert.pem"
PROTO_KEY_FILE="${PROTO_DATA_DIR}/key.pem"
INSTALLER_REV="2026-07-14-svc3"
VERSION_FILE="/etc/proxy-version"
PROTO_VERSION_FILE="/etc/proto-server-version"
LEGACY_BINARY_NAME="proxy"
LEGACY_VERSION_FILE="/etc/proxyvt-version"
BOX_WIDTH=51
TMP_DIR=""
ACTIVE_PROXY_SERVICES=()
ACTIVE_PROTO=false
SERVICES_WERE_STOPPED=false
INSTALL_COMPLETED=false

MODE="install"
VERSION=""
PROTO_VERSION=""
INSTALLED_PROTO_VERSION=""
ASSUME_YES=false
BINARY_ONLY=false
SKIP_HEADER=false
MAX_VERSIONS=10
PROXY_TOKEN=""
PROTO_TOKEN=""
INSTALL_IP=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}👉 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

has_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 && return 0
  [[ -x "/usr/bin/$cmd" ]] && return 0
  [[ -x "/bin/$cmd" ]] && return 0
  return 1
}

has_checksum_command() {
  has_command sha256sum || has_command gsha256sum || has_command shasum
}

run_checksum_verify() {
  local sha_file="$1"
  if has_command sha256sum; then
    sha256sum -c "$sha_file"
  elif has_command gsha256sum; then
    gsha256sum -c "$sha_file"
  elif has_command shasum; then
    shasum -a 256 -c "$sha_file"
  else
    log_warn "Comando de checksum indisponível. Pulando verificação..."
    return 0
  fi
}

usage() {
  cat <<EOF
Uso: $0 [opções]

Modos:
  (padrão)        Instalação interativa (detecta e atualiza serviços existentes)
  --install       Mesmo que o padrão
  --update        Atualiza para a versão mais recente (reinicia serviços ativos)
  --reinstall     Reinstala binários e menu vt (interativo ou com --latest)

Opções:
  --latest, -L    Usa a versão mais recente do proxy e do proto (sem menu)
  --version TAG   Versão específica do proxy (ex: v2.1.0)
  --proto-version TAG  Versão específica do proto (ex: v2.0.1)
  --binary-only   Instala/atualiza apenas os binários (não baixa vt.sh)
  --proxy-token T Token da licença proxy (VT)
  --proto-token T Token do servidor de protocolo
  --ip IP         IP da VPS vinculado à licença
  --yes, -y       Sem confirmações interativas
  --quiet, -q     Menos saída visual (não limpa a tela)
  -h, --help      Exibe esta ajuda

Exemplos:
  $0
  $0 --update --yes
  $0 --reinstall --latest --yes
  $0 --version v2.1.0 --proto-version v2.0.1 --yes
  $0 -- --proxy-token 'VT-XXXX' --proto-token 'abc123' --ip '1.2.3.4' --yes
EOF
}

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

  if [[ "$SERVICES_WERE_STOPPED" == true && "$INSTALL_COMPLETED" != true ]]; then
    log_warn "Instalação interrompida — tentando restaurar serviços parados..."
    has_systemd && run_privileged systemctl daemon-reload 2>/dev/null || true
    restart_proxy_services || true
    restart_proto_server || true
  fi
}
trap cleanup EXIT

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --install) MODE="install" ;;
    --update) MODE="update" ;;
    --reinstall) MODE="reinstall" ;;
    --latest | -L)
      VERSION="latest"
      PROTO_VERSION="latest"
      ;;
    --version)
      shift
      VERSION="${1:-}"
      [[ -n "$VERSION" ]] || { log_error "Use --version TAG"; exit 1; }
      ;;
    --proto-version)
      shift
      PROTO_VERSION="${1:-}"
      [[ -n "$PROTO_VERSION" ]] || { log_error "Use --proto-version TAG"; exit 1; }
      ;;
    --binary-only) BINARY_ONLY=true ;;
    --proxy-token)
      shift
      PROXY_TOKEN="${1:-}"
      [[ -n "$PROXY_TOKEN" ]] || { log_error "Use --proxy-token TOKEN"; exit 1; }
      ;;
    --proto-token)
      shift
      PROTO_TOKEN="${1:-}"
      [[ -n "$PROTO_TOKEN" ]] || { log_error "Use --proto-token TOKEN"; exit 1; }
      ;;
    --ip)
      shift
      INSTALL_IP="${1:-}"
      [[ -n "$INSTALL_IP" ]] || { log_error "Use --ip IP"; exit 1; }
      ;;
    --yes | -y) ASSUME_YES=true ;;
    --quiet | -q) SKIP_HEADER=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      ;;
    *)
      log_error "Opção desconhecida: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done

  case "$MODE" in
  update)
    [[ -z "$VERSION" ]] && VERSION="latest"
    [[ -z "$PROTO_VERSION" ]] && PROTO_VERSION="latest"
    ASSUME_YES=true
    ;;
  reinstall)
    BINARY_ONLY=false
    ;;
  esac
}

print_header() {
  [[ "$SKIP_HEADER" == true ]] && return 0
  local title="INSTALADOR ${PROJECT_NAME}"
  clear
  echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" "$title"
  echo -e "${BLUE}╠═══════════════════════════════════════════════════╣${NC}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" " Repositório: ${REPO}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" " Modo:        ${MODE}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" " Binário proxy: ${INSTALL_DIR}/${BINARY_NAME}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" " Binário proto: ${INSTALL_DIR}/${PROTO_BINARY_NAME}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" " Menu:          ${INSTALL_DIR}/${MENU_NAME}"
  printf "${BLUE}║${NC}%-${BOX_WIDTH}s${BLUE}║${NC}\n" " Revisão:       ${INSTALLER_REV}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
  echo
}

run_privileged() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    log_error "Privilégios de root necessários. Execute como root ou instale sudo."
    exit 1
  fi
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo apt
  elif command -v apk >/dev/null 2>&1; then
    echo apk
  elif command -v dnf >/dev/null 2>&1; then
    echo dnf
  elif command -v yum >/dev/null 2>&1; then
    echo yum
  elif command -v pacman >/dev/null 2>&1; then
    echo pacman
  elif command -v zypper >/dev/null 2>&1; then
    echo zypper
  else
    echo unknown
  fi
}

get_missing_commands() {
  local missing=()
  has_command curl || missing+=("curl")
  has_checksum_command || missing+=("sha256sum")
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '%s\n' "${missing[@]}"
  fi
}

commands_to_packages() {
  local cmd packages=() pkg
  for cmd in "$@"; do
    cmd="${cmd//$'\r'/}"
    [[ -z "$cmd" ]] && continue
    case "$cmd" in
    curl) pkg="curl" ;;
    sha256sum) pkg="coreutils" ;;
    *) continue ;;
    esac
    [[ " ${packages[*]} " == *" $pkg "* ]] || packages+=("$pkg")
  done
  if [[ ${#packages[@]} -gt 0 ]]; then
    printf '%s\n' "${packages[@]}"
  fi
}

install_packages() {
  local pm="$1"
  shift
  local packages=("$@")

  case "$pm" in
  apt)
    run_privileged apt-get update -qq
    run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
    ;;
  apk)
    run_privileged apk add --no-cache "${packages[@]}"
    ;;
  dnf)
    run_privileged dnf install -y "${packages[@]}"
    ;;
  yum)
    run_privileged yum install -y "${packages[@]}"
    ;;
  pacman)
    run_privileged pacman -Sy --noconfirm "${packages[@]}"
    ;;
  zypper)
    run_privileged zypper install -y "${packages[@]}"
    ;;
  *)
    return 1
    ;;
  esac
}

read_nonempty_lines() {
  local -n _target=$1
  local line
  _target=()
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    [[ -n "$line" ]] && _target+=("$line")
  done
}

ensure_dependencies() {
  local missing=() packages=() still_missing=() pm line

  read_nonempty_lines missing < <(get_missing_commands)
  [[ ${#missing[@]} -eq 0 ]] && return 0

  log_warn "Dependências ausentes: ${missing[*]}"

  pm=$(detect_package_manager)
  if [[ "$pm" == "unknown" ]]; then
    log_error "Gerenciador de pacotes não suportado."
    log_info "Instale manualmente: curl coreutils"
    exit 1
  fi

  read_nonempty_lines packages < <(commands_to_packages "${missing[@]}")
  if [[ ${#packages[@]} -eq 0 ]]; then
    log_error "Não foi possível mapear pacotes para: ${missing[*]}"
    exit 1
  fi

  log_info "Instalando dependências via ${pm}: ${packages[*]}"

  if ! install_packages "$pm" "${packages[@]}"; then
    log_error "Falha ao instalar dependências automaticamente."
    exit 1
  fi

  hash -r 2>/dev/null || true
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

  has_command curl || still_missing+=("curl")
  has_checksum_command || still_missing+=("sha256sum")

  if [[ ${#still_missing[@]} -gt 0 ]]; then
    log_error "Ainda faltam dependências após instalação: ${still_missing[*]}"
    for line in "${still_missing[@]}"; do
      case "$line" in
      curl) log_info "curl não encontrado em: $(command -v curl 2>/dev/null || echo 'não localizado')" ;;
      sha256sum) log_info "Tente: apt install coreutils (ou reinicie o terminal)" ;;
      esac
    done
    exit 1
  fi

  log_success "Dependências OK (curl + checksum)."
}

detect_platform() {
  case "$(uname -s)" in
  Linux*) OS_NAME=linux ;;
  *)
    log_error "Sistema operacional não suportado."
    exit 1
    ;;
  esac

  case "$(uname -m)" in
  x86_64) ARCH_NAME=amd64 ;;
  aarch64) ARCH_NAME=arm64 ;;
  armv7l) ARCH_NAME=arm ;;
  i386 | i686) ARCH_NAME=386 ;;
  *)
    log_error "Arquitetura não suportada: $(uname -m)"
    exit 1
    ;;
  esac

  log_info "Plataforma detectada: $OS_NAME/$ARCH_NAME"
}

get_installed_version() {
  if [[ -x "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
    "${INSTALL_DIR}/${BINARY_NAME}" --version 2>/dev/null | awk '{print $2}' | tr -d 'v' || true
    return
  fi

  if [[ -x "${INSTALL_DIR}/${LEGACY_BINARY_NAME}" ]]; then
    "${INSTALL_DIR}/${LEGACY_BINARY_NAME}" --version 2>/dev/null | awk '{print $2}' | tr -d 'v' || true
    return
  fi

  if [[ -f "$VERSION_FILE" ]]; then
    tr -d 'v' <"$VERSION_FILE"
    return
  fi

  if [[ -f "$LEGACY_VERSION_FILE" ]]; then
    tr -d 'v' <"$LEGACY_VERSION_FILE"
  fi
}

get_installed_proto_version() {
  if [[ -x "${INSTALL_DIR}/${PROTO_BINARY_NAME}" ]]; then
    "${INSTALL_DIR}/${PROTO_BINARY_NAME}" --version 2>/dev/null | awk '{print $2}' | tr -d 'v' || true
    return
  fi

  if [[ -f "$PROTO_VERSION_FILE" ]]; then
    tr -d 'v' <"$PROTO_VERSION_FILE"
  fi
}

show_current_installation() {
  local current current_proto
  current=$(get_installed_version || true)
  current_proto=$(get_installed_proto_version || true)
  if [[ -n "$current" ]]; then
    log_info "Versão proxy instalada: v${current}"
    if [[ -x "${INSTALL_DIR}/${LEGACY_BINARY_NAME}" && ! -x "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
      log_warn "Instalação legada detectada em ${INSTALL_DIR}/${LEGACY_BINARY_NAME}"
    fi
  else
    log_warn "Nenhuma instalação proxy detectada em ${INSTALL_DIR}/${BINARY_NAME}"
  fi

  if [[ -n "$current_proto" ]]; then
    log_info "Versão proto instalada: v${current_proto}"
  else
    log_warn "Nenhuma instalação proto detectada em ${INSTALL_DIR}/${PROTO_BINARY_NAME}"
  fi
}

fetch_release_tags() {
  local repo="$1"
  local -n out_array=$2
  local releases_json line

  out_array=()
  releases_json=$(curl -fsSL "https://api.github.com/repos/${repo}/releases?per_page=${MAX_VERSIONS}")

  if [[ -z "$releases_json" || "$releases_json" != \[* ]]; then
    log_error "Erro ao buscar releases em ${repo}."
    echo "$releases_json"
    exit 1
  fi

  while IFS= read -r line; do
    line="${line//$'\r'/}"
    [[ -n "$line" ]] && out_array+=("$line")
  done < <(
    echo "$releases_json" \
      | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | sed -E 's/.*"([^"]+)"$/\1/' \
      | head -n "$MAX_VERSIONS"
  )

  if [[ ${#out_array[@]} -eq 0 ]]; then
    log_error "Nenhuma release encontrada em ${repo}."
    exit 1
  fi
}

fetch_releases() {
  fetch_release_tags "$REPO" RELEASES
}

fetch_proto_releases() {
  fetch_release_tags "$PROTO_FALLBACK_REPO" PROTO_RELEASES
}

normalize_version_tag() {
  local value="$1"
  [[ -z "$value" || "$value" == "latest" ]] && return 1
  [[ "$value" == v* ]] || value="v${value}"
  echo "$value"
}

resolve_version_in_list() {
  local requested="$1"
  local -n available=$2
  local -n resolved=$3
  local label="$4"
  local tag normalized

  if [[ "$requested" == "latest" || -z "$requested" ]]; then
    resolved="${available[0]}"
    log_success "Versão ${label} selecionada (mais recente): ${resolved}"
    return 0
  fi

  normalized=$(normalize_version_tag "$requested" || true)
  [[ -n "$normalized" ]] || normalized="$requested"

  for tag in "${available[@]}"; do
    if [[ "$tag" == "$normalized" ]]; then
      resolved="$tag"
      log_success "Versão ${label} selecionada: ${resolved}"
      return 0
    fi
  done

  log_error "Versão ${label} ${requested} não encontrada nas últimas ${MAX_VERSIONS} releases."
  exit 1
}

prompt_version_selection() {
  local label="$1"
  local repo="$2"
  local -n available=$3
  local -n resolved=$4
  local choice

  echo ""
  echo -e "${BLUE}📦 Versões disponíveis (${label} — ${repo}):${NC}"
  for i in "${!available[@]}"; do
    printf " %d) %s\n" $((i + 1)) "${available[$i]}"
  done

  echo ""
  while true; do
    read -rp "Escolha a versão do ${label} [1]: " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && ((choice >= 1 && choice <= ${#available[@]})); then
      resolved="${available[$((choice - 1))]}"
      log_success "Versão ${label} selecionada: ${resolved}"
      break
    fi
    log_error "Escolha inválida. Tente novamente."
  done
}

show_versions_and_select() {
  if [[ -n "$VERSION" ]]; then
    resolve_version_in_list "$VERSION" RELEASES VERSION "proxy"
  elif [[ "$ASSUME_YES" == true ]]; then
    VERSION="${RELEASES[0]}"
    log_success "Versão proxy (automática): ${VERSION}"
  else
    prompt_version_selection "proxy" "$REPO" RELEASES VERSION
  fi

  if [[ -n "$PROTO_VERSION" ]]; then
    resolve_version_in_list "$PROTO_VERSION" PROTO_RELEASES PROTO_VERSION "proto"
  elif [[ "$ASSUME_YES" == true ]]; then
    PROTO_VERSION="${PROTO_RELEASES[0]}"
    log_success "Versão proto (automática): ${PROTO_VERSION}"
  else
    prompt_version_selection "proto" "$PROTO_FALLBACK_REPO" PROTO_RELEASES PROTO_VERSION
  fi
}

confirm_installation() {
  [[ "$ASSUME_YES" == true ]] && return 0

  echo ""
  read -rp "Continuar com proxy ${VERSION} e proto ${PROTO_VERSION}? (s/N): " answer
  case "${answer,,}" in
  s | sim) ;;
  *)
    log_warn "Operação cancelada."
    exit 0
    ;;
  esac
}

download_file() {
  local url="$1"
  local output="$2"
  local http_status

  http_status=$(curl -fsSL -w "%{http_code}" -o "$output" "$url" || true)
  if [[ "$http_status" != "200" ]]; then
    log_error "Falha ao baixar: $url (HTTP $http_status)"
    exit 1
  fi
}

verify_checksum() {
  local filename="$1"
  local sha_file="${filename}.sha256"
  local http_status

  http_status=$(curl -fsSL -w "%{http_code}" -o "$sha_file" "${DOWNLOAD_URL}.sha256" || true)
  if [[ "$http_status" != "200" ]]; then
    log_warn "Arquivo SHA256 não encontrado. Pulando verificação..."
    return 0
  fi

  log_info "Verificando integridade com SHA256..."
  if ! (cd "$TMP_DIR" && run_checksum_verify "$sha_file"); then
    log_error "Checksum inválido para $filename"
    exit 1
  fi
}

get_proto_config_value() {
  local key="$1"
  if [[ -f "$PROTO_CONFIG_FILE" ]]; then
    grep "^${key}=" "$PROTO_CONFIG_FILE" | cut -d'=' -f2- | head -n1
  fi
}

find_service_files_by_exec() {
  local pattern="$1"
  local dir service_file

  for dir in /etc/systemd/system /lib/systemd/system; do
    [[ -d "$dir" ]] || continue
    for service_file in "$dir"/*.service; do
      [[ -f "$service_file" ]] || continue
      grep -qE "$pattern" "$service_file" 2>/dev/null && echo "$service_file"
    done
  done | sort -u
}

has_active_proxy_process() {
  if has_command pgrep; then
    pgrep -f '/usr/local/bin/proxy-server' >/dev/null 2>&1 && return 0
    pgrep -f '/usr/local/bin/proxy ' >/dev/null 2>&1 && return 0
  fi
  return 1
}

has_active_proto_process() {
  if has_command pgrep; then
    pgrep -f '/usr/local/bin/proto-server' >/dev/null 2>&1 && return 0
    pgrep -f 'proto-server.*--token=' >/dev/null 2>&1 && return 0
  fi
  return 1
}

has_active_vtproxy_processes() {
  has_active_proxy_process || has_active_proto_process
}

has_prior_installation() {
  local current current_proto

  current=$(get_installed_version 2>/dev/null || true)
  current_proto=$(get_installed_proto_version 2>/dev/null || true)
  [[ -n "$current" || -n "$current_proto" ]] && return 0
  [[ -f /etc/proxy/token || -f /etc/vtproxy/proxy.token ]] && return 0
  [[ -f /etc/proto-server/token || -f "$PROTO_CONFIG_FILE" ]] && return 0
  [[ -d /etc/proxy/conf.d ]] && return 0
  has_existing_services && return 0
  has_active_vtproxy_processes && return 0
  return 1
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\/&|]/\\&/g'
}

safe_sed_inplace() {
  local service_file="$1"
  shift

  if ! run_privileged sed -Ei "$@" "$service_file"; then
    log_warn "Falha ao atualizar $(basename "$service_file") — continuando..."
    return 1
  fi
}

has_systemd() {
  command -v systemctl >/dev/null 2>&1
}

list_proxy_services() {
  if ! has_systemd; then
    return 0
  fi

  systemctl list-units --type=service --all --no-legend 'proxy-*.service' 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^proxy-[0-9]+\.service$' || true
}

list_all_proxy_services() {
  local services=() service_file service_name

  if ! has_systemd; then
    return 0
  fi

  while IFS= read -r service_file; do
    service_name="$(basename "$service_file")"
    [[ " ${services[*]} " == *" $service_name "* ]] || services+=("$service_name")
  done < <(find_service_files_by_exec 'ExecStart=.*(/usr/local/bin/proxy-server|/usr/local/bin/proxy)( |$)')

  while IFS= read -r service_name; do
    service_name="${service_name//$'\r'/}"
    [[ -n "$service_name" ]] && [[ " ${services[*]} " != *" $service_name "* ]] && services+=("$service_name")
  done < <(
    systemctl list-unit-files --type=service --no-legend 'proxy-*.service' 2>/dev/null \
      | awk '{print $1}' \
      | grep -E '^proxy-[0-9]+\.service$' || true
  )

  for service_file in /etc/systemd/system/proxy-*.service; do
    [[ -f "$service_file" ]] || continue
    service_name="$(basename "$service_file")"
    [[ " ${services[*]} " == *" $service_name "* ]] || services+=("$service_name")
  done

  if [[ ${#services[@]} -gt 0 ]]; then
    printf '%s\n' "${services[@]}"
  fi
}

find_proto_service_file() {
  if [[ -f /etc/systemd/system/proto-server.service ]]; then
    echo /etc/systemd/system/proto-server.service
    return 0
  fi

  find_service_files_by_exec 'ExecStart=.*proto-server' | head -n1
}

has_proto_service() {
  has_systemd || return 1
  [[ -n "$(find_proto_service_file || true)" ]]
}

has_proxy_services() {
  local services=()
  read_nonempty_lines services < <(list_all_proxy_services)
  [[ ${#services[@]} -gt 0 ]]
}

has_existing_services() {
  has_proto_service || has_proxy_services
}

capture_active_services() {
  ACTIVE_PROXY_SERVICES=()
  ACTIVE_PROTO=false

  if ! has_systemd; then
    return 0
  fi

  local services=() service
  read_nonempty_lines services < <(list_all_proxy_services)
  for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      ACTIVE_PROXY_SERVICES+=("$service")
    fi
  done

  if systemctl is-active --quiet proto-server 2>/dev/null; then
    ACTIVE_PROTO=true
  elif has_active_proto_process; then
    ACTIVE_PROTO=true
  fi

  if [[ ${#ACTIVE_PROXY_SERVICES[@]} -eq 0 ]] && has_active_proxy_process; then
    log_warn "Processo proxy em execução detectado sem unit systemd conhecido."
  fi
}

stop_proxy_services() {
  local services=() service
  read_nonempty_lines services < <(list_all_proxy_services)
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Parando ${#services[@]} serviço(s) do proxy..."
  for service in "${services[@]}"; do
    run_privileged systemctl stop "$service" || log_warn "Não foi possível parar $service"
  done
}

restart_proxy_services() {
  local services=() service

  if [[ "$MODE" == "update" || "$MODE" == "reinstall" ]]; then
    read_nonempty_lines services < <(list_all_proxy_services)
  elif [[ ${#ACTIVE_PROXY_SERVICES[@]} -gt 0 ]]; then
    services=("${ACTIVE_PROXY_SERVICES[@]}")
  else
    return 0
  fi
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Reiniciando ${#services[@]} serviço(s) do proxy..."
  for service in "${services[@]}"; do
    run_privileged systemctl restart "$service" || log_warn "Não foi possível reiniciar $service"
  done
}

stop_proto_server() {
  if systemctl is-active --quiet proto-server 2>/dev/null; then
    log_info "Parando serviço proto-server..."
    run_privileged systemctl stop proto-server || log_warn "Não foi possível parar proto-server"
  fi
}

restart_proto_server() {
  if ! has_proto_service; then
    return 0
  fi

  if [[ "$MODE" == "update" || "$MODE" == "reinstall" || "$ACTIVE_PROTO" == true ]]; then
    log_info "Iniciando/reiniciando serviço proto-server..."
    if ! run_privileged systemctl restart proto-server; then
      log_warn "Não foi possível reiniciar proto-server."
      log_info "Verifique: journalctl -u proto-server -n 30 --no-pager"
      return 1
    fi
    if systemctl is-active --quiet proto-server 2>/dev/null; then
      log_success "proto-server ativo."
    else
      log_warn "proto-server não ficou ativo após restart."
    fi
  fi
}

load_saved_proxy_token() {
  local file
  for file in /etc/vtproxy/proxy.token /etc/proxy/token "${HOME:-/root}/.proxy_token"; do
    if [[ -f "$file" ]]; then
      tr -d '\r\n' <"$file"
      return 0
    fi
  done
}

load_saved_proto_token() {
  if [[ -f /etc/proto-server/token ]]; then
    tr -d '\r\n' </etc/proto-server/token
  fi
}

sync_proxy_service_executables() {
  local service_file new_bin="${INSTALL_DIR}/${BINARY_NAME}"

  while IFS= read -r service_file; do
    [[ -f "$service_file" ]] || continue
    safe_sed_inplace "$service_file" \
      -e "s|ExecStart=${INSTALL_DIR}/${LEGACY_BINARY_NAME}([^-a-zA-Z])|ExecStart=${new_bin}\1|g" \
      -e "s|ExecStart=${INSTALL_DIR}/${BINARY_NAME}|ExecStart=${new_bin}|g" || true
  done < <(find_service_files_by_exec 'ExecStart=.*(/usr/local/bin/proxy-server|/usr/local/bin/proxy)( |$)')

  for service_file in /etc/systemd/system/proxy-*.service; do
    [[ -f "$service_file" ]] || continue
    safe_sed_inplace "$service_file" \
      -e "s|ExecStart=${INSTALL_DIR}/${LEGACY_BINARY_NAME}([^-a-zA-Z])|ExecStart=${new_bin}\1|g" \
      -e "s|ExecStart=${INSTALL_DIR}/${BINARY_NAME}|ExecStart=${new_bin}|g" || true
  done
}

sync_proxy_service_tokens() {
  local token="$1"
  local service_file safe_token

  [[ -n "$token" ]] || return 0
  safe_token=$(escape_sed_replacement "$token")

  while IFS= read -r service_file; do
    [[ -f "$service_file" ]] || continue
    if grep -q -- '--token=' "$service_file"; then
      safe_sed_inplace "$service_file" "s|--token=[^ ]+|--token=${safe_token}|g" || true
    fi
  done < <(find_service_files_by_exec 'ExecStart=.*(/usr/local/bin/proxy-server|/usr/local/bin/proxy)( |$)')

  for service_file in /etc/systemd/system/proxy-*.service; do
    [[ -f "$service_file" ]] || continue
    if grep -q -- '--token=' "$service_file"; then
      safe_sed_inplace "$service_file" "s|--token=[^ ]+|--token=${safe_token}|g" || true
    fi
  done
}

normalize_protocol_config() {
  local input="$1"
  local output="" part

  IFS=',' read -ra parts <<<"$input"
  for part in "${parts[@]}"; do
    case "$part" in
    tcp:* | udp:* | quic:*)
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

ensure_proto_systemd_service() {
  local token port subnet tun protocol_config proto_bin service_command service_file auth_flag

  service_file="$(find_proto_service_file || true)"
  [[ -n "$service_file" ]] && return 0

  token="$PROTO_TOKEN"
  if [[ -z "$token" ]]; then
    token=$(load_saved_proto_token || true)
  fi
  [[ -n "$token" ]] || return 0

  port=$(get_proto_config_value "PORT")
  subnet=$(get_proto_config_value "VIRTUAL_SUBNET_CIDR")
  tun=$(get_proto_config_value "TUN_INTERFACE")
  protocol_config=$(get_proto_config_value "PROTOCOL_CONFIG")

  port=${port:-8000}
  subnet=${subnet:-10.10.0.0/16}
  tun=${tun:-tun0}
  protocol_config=$(normalize_protocol_config "${protocol_config:-tcp:$port}")
  [[ -n "$protocol_config" ]] || protocol_config="tcp:$port"
  proto_bin="${INSTALL_DIR}/${PROTO_BINARY_NAME}"
  auth_flag="--auth-file=${PROTO_CREDENTIALS_FILE}"

  run_privileged mkdir -p "$(dirname "$PROTO_CONFIG_FILE")" "$PROTO_DATA_DIR"

  service_command="${proto_bin} \\
    --token=${token} \\
    --virtual-subnet-cidr=${subnet} \\
    --tun=${tun} \\
    --quic-cert=${PROTO_CERT_FILE} \\
    --quic-key=${PROTO_KEY_FILE} \\
    --stats-file=${PROTO_STATS_FILE} \\
    --protocol=${protocol_config} \\
    ${auth_flag}"

  log_info "Criando proto-server.service a partir da configuração existente..."

  run_privileged tee /etc/systemd/system/proto-server.service >/dev/null <<EOF
[Unit]
Description=${PROJECT_NAME} Proto Server
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${service_command}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

sync_proto_service() {
  local token="$1"
  local service_file safe_token proto_bin="${INSTALL_DIR}/${PROTO_BINARY_NAME}"

  ensure_proto_systemd_service
  service_file="$(find_proto_service_file || true)"
  [[ -n "$service_file" && -f "$service_file" ]] || return 0

  run_privileged sed -Ei "s|/usr/local/bin/proto-server|${proto_bin}|g" "$service_file" || {
    log_warn "Falha ao atualizar binário em $(basename "$service_file")"
    return 0
  }

  [[ -n "$token" ]] || return 0
  safe_token=$(escape_sed_replacement "$token")
  safe_sed_inplace "$service_file" "s|--token=[^ ]+|--token=${safe_token}|g" || true
}

refresh_existing_services() {
  local proxy_token proto_token

  if ! should_manage_services; then
    return 0
  fi

  log_info "Atualizando serviços systemd existentes..."

  proxy_token="$PROXY_TOKEN"
  if [[ -z "$proxy_token" ]]; then
    proxy_token=$(load_saved_proxy_token || true)
  fi

  proto_token="$PROTO_TOKEN"
  if [[ -z "$proto_token" ]]; then
    proto_token=$(load_saved_proto_token || true)
  fi

  sync_proxy_service_executables
  [[ -n "$proxy_token" ]] && sync_proxy_service_tokens "$proxy_token"
  [[ -n "$proto_token" ]] && sync_proto_service "$proto_token"

  if has_systemd; then
    run_privileged systemctl daemon-reload || log_warn "Falha ao recarregar systemd"
  fi
}

should_manage_services() {
  [[ "$MODE" == "update" || "$MODE" == "reinstall" ]] && return 0
  has_prior_installation
}

report_existing_services() {
  local proxy_services=() count=0

  if ! should_manage_services; then
    return 0
  fi

  log_info "Instalação prévia detectada — serviços serão sincronizados após a atualização."

  read_nonempty_lines proxy_services < <(list_all_proxy_services)
  count=${#proxy_services[@]}

  if has_proto_service || has_active_proto_process || [[ -f "$PROTO_CONFIG_FILE" ]]; then
    if [[ "$ACTIVE_PROTO" == true ]]; then
      log_warn "Proto ativo detectado — unit file/token será atualizado e o serviço reiniciado."
    else
      log_warn "Configuração proto detectada — unit file será criado/atualizado se necessário."
    fi
  fi

  if [[ $count -gt 0 ]]; then
    if [[ ${#ACTIVE_PROXY_SERVICES[@]} -gt 0 ]]; then
      log_warn "${#ACTIVE_PROXY_SERVICES[@]} serviço(s) proxy ativo(s): ${ACTIVE_PROXY_SERVICES[*]//.service/}"
    else
      log_warn "${count} serviço(s) proxy configurado(s) — unit files serão atualizados."
    fi
  elif has_active_proxy_process; then
    log_warn "Processo proxy ativo detectado — reinicie manualmente se não houver unit systemd."
  fi
}

configure_sysctl() {
  log_info "Configurando ip_forward (sysctl)..."
  local sysctl_conf="/etc/sysctl.d/99-vtproxy.conf"
  echo 'net.ipv4.ip_forward=1' | run_privileged tee "$sysctl_conf" >/dev/null
  run_privileged sysctl --system >/dev/null 2>&1 || run_privileged sysctl -p "$sysctl_conf" >/dev/null 2>&1 || true
  log_success "Regras sysctl aplicadas."
}

download_and_install_binary() {
  local filename="${RELEASE_BINARY_PREFIX}-${OS_NAME}-${ARCH_NAME}"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${filename}"

  TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR"

  log_info "Baixando binário proxy: $filename ($VERSION)"
  download_file "$DOWNLOAD_URL" "$filename"
  verify_checksum "$filename"

  log_info "Instalando binário em ${INSTALL_DIR}/${BINARY_NAME}..."
  run_privileged install -m 755 "$filename" "${INSTALL_DIR}/${BINARY_NAME}"
  echo "${VERSION#v}" | run_privileged tee "$VERSION_FILE" >/dev/null

  log_success "Binário proxy instalado: ${INSTALL_DIR}/${BINARY_NAME} ($VERSION)"
}

download_and_install_proto_binary() {
  local filename="${PROTO_RELEASE_BINARY_PREFIX}-${OS_NAME}-${ARCH_NAME}"
  local fallback_repo="${PROTO_FALLBACK_REPO:-DTunnel0/DTProto-Server-Releases}"
  local repos=("$PROTO_REPO")
  local repo url http_status used_url=""

  [[ "$PROTO_REPO" != "$fallback_repo" ]] && repos+=("$fallback_repo")

  log_info "Baixando binário proto: $filename (${PROTO_VERSION})"

  for repo in "${repos[@]}"; do
    url="https://github.com/${repo}/releases/download/${PROTO_VERSION}/${filename}"
    log_info "Tentativa: ${repo} (${PROTO_VERSION})"
    http_status=$(curl -fsSL -w "%{http_code}" -o "$filename" "$url" 2>/dev/null || true)
    if [[ "$http_status" == "200" ]]; then
      used_url="$url"
      break
    fi
    if [[ "$repo" == "$PROTO_REPO" ]]; then
      log_warn "Binário proto não encontrado em ${PROTO_REPO} (${PROTO_VERSION})."
    fi
  done

  if [[ -z "$used_url" ]]; then
    log_error "Falha ao baixar binário proto ${PROTO_VERSION} (HTTP ${http_status:-404})"
    log_info "Verifique releases em: ${PROTO_REPO} e ${fallback_repo}"
    exit 1
  fi

  DOWNLOAD_URL="$used_url"
  verify_checksum "$filename"

  log_info "Instalando binário em ${INSTALL_DIR}/${PROTO_BINARY_NAME}..."
  run_privileged install -m 755 "$filename" "${INSTALL_DIR}/${PROTO_BINARY_NAME}"
  INSTALLED_PROTO_VERSION="${PROTO_VERSION#v}"
  echo "$INSTALLED_PROTO_VERSION" | run_privileged tee "$PROTO_VERSION_FILE" >/dev/null

  log_success "Binário proto instalado: ${INSTALL_DIR}/${PROTO_BINARY_NAME} (${PROTO_VERSION})"
}

install_menu_script() {
  if [[ "$BINARY_ONLY" == true ]]; then
    log_info "Pulando instalação do menu (--binary-only)."
    return 0
  fi

  log_info "Baixando menu unificado (vt.sh)..."
  local menu_tmp="${TMP_DIR}/vt.sh"
  download_file "$MENU_URL" "$menu_tmp"
  run_privileged install -m 755 "$menu_tmp" "${INSTALL_DIR}/${MENU_NAME}"
  run_privileged ln -sf "${MENU_NAME}" "${INSTALL_DIR}/main"
  run_privileged ln -sf "${MENU_NAME}" "${INSTALL_DIR}/proto"
  log_success "Menu instalado: ${INSTALL_DIR}/${MENU_NAME} (symlinks: main, proto)"
}

install_provided_tokens() {
  [[ -z "$PROXY_TOKEN" && -z "$PROTO_TOKEN" ]] && return 0

  log_info "Configurando tokens fornecidos pelo instalador..."

  if [[ -n "$PROXY_TOKEN" ]]; then
    run_privileged mkdir -p /etc/vtproxy /etc/proxy
    printf '%s' "$PROXY_TOKEN" | run_privileged tee /etc/vtproxy/proxy.token >/dev/null
    printf '%s' "$PROXY_TOKEN" | run_privileged tee /etc/proxy/token >/dev/null
    chmod 600 /etc/vtproxy/proxy.token /etc/proxy/token 2>/dev/null || true

    if [[ -n "${HOME:-}" ]]; then
      printf '%s' "$PROXY_TOKEN" >"$HOME/.proxy_token"
      chmod 600 "$HOME/.proxy_token" 2>/dev/null || true
    fi

    log_success "Token proxy salvo."
  fi

  if [[ -n "$PROTO_TOKEN" ]]; then
    run_privileged mkdir -p /etc/proto-server
    printf '%s' "$PROTO_TOKEN" | run_privileged tee /etc/proto-server/token >/dev/null
    chmod 600 /etc/proto-server/token 2>/dev/null || true
    log_success "Token proto salvo."
  fi

  if [[ -n "$INSTALL_IP" ]]; then
    run_privileged mkdir -p /etc/vtproxy
    printf '%s' "$INSTALL_IP" | run_privileged tee /etc/vtproxy/ip >/dev/null
    log_info "IP vinculado registrado: $INSTALL_IP"
  fi
}

print_finish_message() {
  echo ""
  log_success "Operação concluída com sucesso!"
  log_info "Versão proxy: $VERSION"
  if [[ -n "$INSTALLED_PROTO_VERSION" ]]; then
    log_info "Versão proto: v${INSTALLED_PROTO_VERSION}"
  fi
  if [[ "$BINARY_ONLY" == false ]]; then
    log_info "Execute o menu com: ${MENU_NAME}  (ou main / proto)"
    if [[ -n "$PROXY_TOKEN" ]]; then
      log_info "Token proxy já configurado — não será solicitado na primeira execução."
    fi
  fi
  if should_manage_services; then
    log_info "Serviços existentes foram sincronizados (tokens/binários) e reiniciados quando ativos."
  fi
  echo ""
  log_info "Para reinstalar/atualizar depois:"
  echo -e "  ${CYAN}curl -fsSL ${INSTALL_URL} | bash -s -- --update --yes${NC}"
}

main() {
  parse_args "$@"
  print_header
  ensure_dependencies
  detect_platform
  show_current_installation
  capture_active_services
  report_existing_services
  fetch_releases
  fetch_proto_releases
  show_versions_and_select
  confirm_installation

  if should_manage_services; then
    SERVICES_WERE_STOPPED=true
    stop_proxy_services
    stop_proto_server
  fi

  download_and_install_binary
  download_and_install_proto_binary
  configure_sysctl
  install_menu_script
  install_provided_tokens
  refresh_existing_services

  if should_manage_services; then
    restart_proxy_services
    restart_proto_server
  fi

  INSTALL_COMPLETED=true
  print_finish_message
}

main "$@"

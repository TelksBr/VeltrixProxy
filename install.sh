#!/bin/bash
set -euo pipefail

RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

REPO="TelksBr/VeltrixProxy"
PROJECT_NAME="VTProxy"
INSTALL_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh"
MENU_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/vt.sh"
RELEASE_BINARY_PREFIX="proxy"
UDPGW_REPO="${UDPGW_REPO:-TelksBr/VeltrixUPGW}"
BINARY_NAME="proxy-server"
UDPGW_BINARY_NAME="udpgw"
MENU_NAME="vt"
INSTALL_DIR="/usr/local/bin"
INSTALLER_REV="45"
MENU_REV_EXPECTED="55"
MENU_REV_FILE="/etc/vt-menu-revision"
VERSION_FILE="/etc/proxy-version"
UDPGW_VERSION_FILE="/etc/udpgw-version"
LEGACY_BINARY_NAME="proxy"
LEGACY_VERSION_FILE="/etc/proxyvt-version"
BOX_WIDTH=51
TMP_DIR=""
MENU_COMMIT_SHA=""
ACTIVE_PROXY_SERVICES=()
ACTIVE_UDPGW=false
ACTIVE_UDPGW_SERVICES=()
SERVICES_WERE_STOPPED=false
INSTALL_COMPLETED=false

MODE="install"
VERSION=""
UDPGW_VERSION=""
INSTALLED_UDPGW_VERSION=""
ASSUME_YES=false
BINARY_ONLY=false
SKIP_HEADER=false
MAX_VERSIONS=10
PROXY_TOKEN=""
INSTALL_IP=""
SKIP_UDPGW=false


STEP_TITLES=(
  "Privilégios de Root e Sudo"
  "Dependências (curl, checksum, iptables)"
  "Sincronização de Relógio do Sistema (NTP)"
  "Plataforma e Releases do GitHub"
  "Baixando e Instalando Binários (proxy & udpgw)"
  "Otimizações de Kernel, BBR e OpenSSH"
  "Instalando Script do Menu (vt.sh)"
  "Sincronizando e Reiniciando Serviços Systemd"
)

STEP_STATUSES=(0 0 0 0 0 0 0 0)
STEP_SUBTITLES=("" "" "" "" "" "" "" "")

set_step_status() {
  local step_idx="$1"
  local status="$2"
  local sub="${3:-}"

  STEP_STATUSES[$step_idx]="$status"
  [[ -n "$sub" ]] && STEP_SUBTITLES[$step_idx]="$sub"

  render_step_dashboard
}

log_info() {
  if [[ "$SKIP_HEADER" == true ]]; then
    echo -e "${CYAN}👉 $1${NC}"
  fi
}

log_success() {
  if [[ "$SKIP_HEADER" == true ]]; then
    echo -e "${GREEN}✅ $1${NC}"
  fi
}

log_warn() {
  if [[ "$SKIP_HEADER" == true ]]; then
    echo -e "${YELLOW}⚠️  $1${NC}"
  else
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
  fi
}

log_error() {
  echo -e "${RED}❌ $1${NC}" >&2
}

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
  --update        Atualiza proxy (latest) e udpgw (latest)
  --reinstall     Reinstala binários e menu vt (interativo ou com --latest)

Opções:
  --latest, -L    Usa a versão mais recente do proxy e udpgw (também atualiza o menu)
  --version TAG   Versão específica do proxy (ex: v2.1.0)
  --udpgw-version TAG  Versão específica do UDP Gateway (ex: v1.0.1)
  --no-udpgw           Não instala/atualiza o binário udpgw
  --binary-only   Instala/atualiza apenas os binários (não baixa vt.sh)
  --proxy-token T Token da licença proxy (VT)
  --ip IP         IP da VPS vinculado à licença
  --yes, -y       Sem confirmações interativas
  --quiet, -q     Menos saída visual (não limpa a tela)
  -h, --help      Exibe esta ajuda

Exemplos:
  $0
  $0 --update --yes
  $0 --reinstall --latest --yes
  $0 --version v2.1.0 --yes
  $0 -- --proxy-token 'VT-XXXX' --ip '1.2.3.4' --yes
EOF
}

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

  if [[ "$SERVICES_WERE_STOPPED" == true && "$INSTALL_COMPLETED" != true ]]; then
    log_warn "Instalação interrompida — tentando restaurar serviços parados..."
    has_systemd && run_privileged systemctl daemon-reload 2>/dev/null || true
    restart_proxy_services || true
    restart_udpgw_server || true
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
      UDPGW_VERSION="latest"
      ;;
    --version)
      shift
      VERSION="${1:-}"
      [[ -n "$VERSION" ]] || { log_error "Use --version TAG"; exit 1; }
      ;;
    --udpgw-version)
      shift
      UDPGW_VERSION="${1:-}"
      [[ -n "$UDPGW_VERSION" ]] || { log_error "Use --udpgw-version TAG"; exit 1; }
      ;;
    --no-udpgw) SKIP_UDPGW=true ;;
    --binary-only) BINARY_ONLY=true ;;
    --proxy-token)
      shift
      PROXY_TOKEN="${1:-}"
      [[ -n "$PROXY_TOKEN" ]] || { log_error "Use --proxy-token TOKEN"; exit 1; }
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
    [[ -z "$UDPGW_VERSION" ]] && UDPGW_VERSION="latest"
    ASSUME_YES=true
    ;;
  reinstall)
    BINARY_ONLY=false
    ;;
  esac
}

strip_ansi_text() {
  echo -e "$1" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g'
}

print_dash_rule() {
  local fill
  fill=$(printf '%*s' 59 "" | tr ' ' '-')
  echo -e "${BLUE:-\033[0;34m}+${fill}+${NC:-\033[0m}"
}

print_dashboard_center() {
  local text="$1"
  local color="${2:-$NC}"
  local inner_width=59
  local plain
  plain=$(strip_ansi_text "$text")
  local len=${#plain}
  local left=$(( (inner_width - len) / 2 ))
  local right=$((inner_width - len - left))
  ((left < 0)) && left=0
  ((right < 0)) && right=0

  printf "%b%*s%b%s%b%*s%b\n" "${BLUE:-\033[0;34m}|${NC:-\033[0m}" "$left" "" "$color" "$plain" "${NC:-\033[0m}" "$right" "" "${BLUE:-\033[0;34m}|${NC:-\033[0m}"
}

print_dashboard_item() {
  local tag="$1"
  local text="$2"
  local inner_width=59

  local plain_tag
  plain_tag=$(strip_ansi_text "$tag")
  local plain_text
  plain_text=$(strip_ansi_text "$text")

  local tag_len=${#plain_tag}
  local text_len=${#plain_text}
  local used_len=$((2 + tag_len + 1 + text_len))

  if ((used_len > inner_width - 2)); then
    local max_len=$((inner_width - 2 - 2 - tag_len - 1 - 3))
    text="${text:0:$max_len}..."
    plain_text=$(strip_ansi_text "$text")
    text_len=${#plain_text}
    used_len=$((2 + tag_len + 1 + text_len))
  fi

  local right_pad=$((inner_width - used_len))
  ((right_pad < 0)) && right_pad=0

  printf "%b  %b %s%*s%b\n" "${BLUE:-\033[0;34m}|${NC:-\033[0m}" "$tag" "$text" "$right_pad" "" "${BLUE:-\033[0;34m}|${NC:-\033[0m}"
}

render_step_dashboard() {
  [[ "${SKIP_HEADER:-false}" == true ]] && return 0

  if [[ -t 1 ]]; then
    printf '\033[H'
  fi

  local title="INSTALADOR & ATUALIZADOR ${PROJECT_NAME:-VTProxy}"
  local sub="Repositório: ${REPO:-} | Modo: ${MODE:-install}"

  print_dash_rule
  print_dashboard_center "$title" "${CYAN:-\033[0;36m}"
  print_dashboard_center "$sub" "${BLUE:-\033[0;34m}"
  print_dash_rule

  for i in "${!STEP_TITLES[@]}"; do
    local st_title="${STEP_TITLES[$i]}"
    local st_status="${STEP_STATUSES[$i]}"
    local st_sub="${STEP_SUBTITLES[$i]}"
    local tag=""

    case "$st_status" in
    0) tag="${BLUE:-\033[0;34m}[  ]${NC:-\033[0m}" ;;
    1) tag="${YELLOW:-\033[1;33m}[➜ ]${NC:-\033[0m}" ;;
    2) tag="${GREEN:-\033[0;32m}[OK]${NC:-\033[0m}" ;;
    3) tag="${YELLOW:-\033[1;33m}[!!]${NC:-\033[0m}" ;;
    4) tag="${RED:-\033[0;31m}[X ]${NC:-\033[0m}" ;;
    esac

    local line_str="${st_title}"
    if [[ -n "$st_sub" ]]; then
      line_str="${st_title} (${st_sub})"
    fi

    print_dashboard_item "$tag" "$line_str"
  done

  print_dash_rule
  echo
}

print_header() {
  [[ "$SKIP_HEADER" == true ]] && return 0
  clear
  render_step_dashboard
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
  has_command iptables || missing+=("iptables")
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '%s\n' "${missing[@]}"
  fi
}

needs_sudo_install() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && ! has_command sudo
}

ensure_sudo() {
  local pm

  needs_sudo_install || return 0

  pm=$(detect_package_manager)
  if [[ "$pm" == "unknown" ]]; then
    log_warn "sudo não encontrado e gerenciador de pacotes desconhecido — instale sudo manualmente."
    return 0
  fi

  log_info "sudo não encontrado — instalando via ${pm}..."
  if install_packages "$pm" sudo; then
    hash -r 2>/dev/null || true
    if has_command sudo; then
      log_success "sudo instalado."
    else
      log_warn "Pacote sudo instalado, mas comando ainda não disponível no PATH."
    fi
  else
    log_warn "Falha ao instalar sudo automaticamente."
  fi
}

commands_to_packages() {
  local pm="$1"
  shift
  local cmd packages=() pkg
  for cmd in "$@"; do
    cmd="${cmd//$'\r'/}"
    [[ -z "$cmd" ]] && continue
    case "$cmd" in
    curl) pkg="curl" ;;
    sha256sum) pkg="coreutils" ;;
    iptables) pkg="iptables" ;;
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
    log_info "Instale manualmente: curl coreutils iptables"
    exit 1
  fi

  read_nonempty_lines packages < <(commands_to_packages "$pm" "${missing[@]}")
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
  has_command iptables || still_missing+=("iptables")

  if [[ ${#still_missing[@]} -gt 0 ]]; then
    log_error "Ainda faltam dependências após instalação: ${still_missing[*]}"
    for line in "${still_missing[@]}"; do
      case "$line" in
      curl) log_info "curl não encontrado em: $(command -v curl 2>/dev/null || echo 'não localizado')" ;;
      sha256sum) log_info "Tente: apt install coreutils (ou reinicie o terminal)" ;;
      iptables) log_info "Tente: apt install iptables (ou equivalente no seu distro)" ;;
      esac
    done
    exit 1
  fi

  log_success "Dependências OK (curl + checksum + iptables)."
}

# License v2 rejects client_ts outside ±5 minutes of API time. Local timezone
# (e.g. America/Sao_Paulo) is fine — Unix timestamps are absolute. We only need
# the wall clock synchronized via NTP.
#
# Must not abort install/update on NTP/network glitches (set -euo pipefail).
ensure_system_clock() {
  local pm http_date local_epoch remote_epoch skew=0

  log_info "Sincronizando relógio do sistema (NTP) — necessário para validação de licença..."

  pm=$(detect_package_manager)

  if ! command -v chronyd >/dev/null 2>&1 && ! command -v chronyc >/dev/null 2>&1; then
    case "$pm" in
    apt)
      install_packages apt chrony 2>/dev/null || log_warn "Falha ao instalar chrony; tentando systemd-timesyncd."
      hash -r 2>/dev/null || true
      ;;
    apk)
      install_packages apk chrony 2>/dev/null || true
      ;;
    dnf | yum)
      install_packages "$pm" chrony 2>/dev/null || true
      ;;
    pacman)
      install_packages pacman chrony 2>/dev/null || true
      ;;
    zypper)
      install_packages zypper chrony 2>/dev/null || true
      ;;
    esac
  fi

  if command -v chronyd >/dev/null 2>&1 || systemctl list-unit-files chrony.service 2>/dev/null | grep -q chrony; then
    run_privileged systemctl enable chrony 2>/dev/null || run_privileged systemctl enable chronyd 2>/dev/null || true
    run_privileged systemctl restart chrony 2>/dev/null || run_privileged systemctl restart chronyd 2>/dev/null || true
    sleep 2
    if command -v chronyc >/dev/null 2>&1; then
      run_privileged chronyc -a makestep >/dev/null 2>&1 || true
      sleep 1
      run_privileged chronyc -a makestep >/dev/null 2>&1 || true
    fi
  elif has_systemd; then
    case "$pm" in
    apt)
      install_packages apt systemd-timesyncd 2>/dev/null || true
      ;;
    esac
    if command -v timedatectl >/dev/null 2>&1; then
      run_privileged timedatectl set-ntp true 2>/dev/null || true
    fi
    run_privileged systemctl enable --now systemd-timesyncd 2>/dev/null || true
    sleep 3
  else
    log_warn "Nenhum cliente NTP disponível (chrony/timesyncd). Ajuste o relógio manualmente se a licença falhar."
    return 0
  fi

  local_epoch=$(date -u +%s 2>/dev/null || echo 0)
  http_date=$(curl -sSI --max-time 8 https://www.cloudflare.com 2>/dev/null | tr -d '\r' | awk -F': ' 'tolower($1)=="date"{print $2; exit}' || true)
  if [[ -z "$http_date" ]]; then
    http_date=$(curl -sSI --max-time 8 https://www.google.com 2>/dev/null | tr -d '\r' | awk -F': ' 'tolower($1)=="date"{print $2; exit}' || true)
  fi

  remote_epoch=""
  if [[ -n "$http_date" ]]; then
    remote_epoch=$(date -u -d "$http_date" +%s 2>/dev/null || true)
  fi

  if [[ -n "${remote_epoch}" && "$local_epoch" =~ ^[0-9]+$ && "$remote_epoch" =~ ^[0-9]+$ ]]; then
    skew=$((local_epoch - remote_epoch))
    if ((skew < 0)); then
      skew=$((-skew))
    fi
    if ((skew > 240)); then
      log_warn "Relógio ainda desalinhado (~${skew}s vs HTTP Date). Tentando makestep novamente..."
      if command -v chronyc >/dev/null 2>&1; then
        run_privileged chronyc -a makestep >/dev/null 2>&1 || true
        sleep 1
        local_epoch=$(date -u +%s 2>/dev/null || echo 0)
        skew=$((local_epoch - remote_epoch))
        if ((skew < 0)); then
          skew=$((-skew))
        fi
      fi
    fi
    if ((skew > 240)); then
      log_warn "Offset ~${skew}s (>4min). A API de licença exige ±5min — corrija NTP/firewall UDP 123."
      log_info "Hora local UTC: $(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true) | HTTP Date: ${http_date}"
    else
      log_success "Relógio sincronizado (offset ~${skew}s). Fuso local pode permanecer (ex.: America/Sao_Paulo)."
      log_info "UTC agora: $(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    fi
  else
    if command -v chronyc >/dev/null 2>&1; then
      log_success "Chrony ativo (não foi possível cruzar com HTTP Date)."
    else
      log_warn "Não foi possível validar o horário via HTTP Date; confira com: date -u && chronyc tracking"
    fi
    log_info "UTC agora: $(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
  fi

  return 0
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

detect_udpgw_arch() {
  case "$ARCH_NAME" in
  arm) echo "armv7" ;;
  *) echo "$ARCH_NAME" ;;
  esac
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

show_current_installation() {
  local current current_udpgw
  current=$(get_installed_version || true)
  current_udpgw=$(get_installed_udpgw_version || true)
  if [[ -n "$current" ]]; then
    log_info "Versão proxy instalada: v${current}"
    if [[ -x "${INSTALL_DIR}/${LEGACY_BINARY_NAME}" && ! -x "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
      log_warn "Instalação legada detectada em ${INSTALL_DIR}/${LEGACY_BINARY_NAME}"
    fi
  else
    log_warn "Nenhuma instalação proxy detectada em ${INSTALL_DIR}/${BINARY_NAME}"
  fi

  if [[ -n "$current_udpgw" ]]; then
    log_info "Versão udpgw instalada: v${current_udpgw}"
  else
    log_warn "Nenhuma instalação udpgw detectada em ${INSTALL_DIR}/${UDPGW_BINARY_NAME}"
  fi
}

get_installed_udpgw_version() {
  if [[ -x "${INSTALL_DIR}/${UDPGW_BINARY_NAME}" ]]; then
    "${INSTALL_DIR}/${UDPGW_BINARY_NAME}" -version 2>/dev/null | tr -d 'v\r\n' || true
    return
  fi

  if [[ -f "$UDPGW_VERSION_FILE" ]]; then
    tr -d 'v' <"$UDPGW_VERSION_FILE"
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

fetch_udpgw_releases() {
  fetch_release_tags "$UDPGW_REPO" UDPGW_RELEASES
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
  local repo="${5:-}"
  local tag normalized latest_tag

  if [[ "$requested" == "latest" || -z "$requested" ]]; then
    if [[ -n "$repo" ]]; then
      latest_tag=$(fetch_latest_release_tag "$repo" || true)
      if [[ -n "$latest_tag" ]]; then
        resolved="$latest_tag"
        log_success "Versão ${label} selecionada (releases/latest): ${resolved}"
        return 0
      fi
      log_warn "API releases/latest indisponível para ${repo}; usando lista recente."
    fi
    resolved="${available[0]}"
    log_success "Versão ${label} selecionada (mais recente da lista): ${resolved}"
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
    resolve_version_in_list "$VERSION" RELEASES VERSION "proxy" "$REPO"
  elif [[ "$ASSUME_YES" == true ]]; then
    resolve_version_in_list "latest" RELEASES VERSION "proxy" "$REPO"
  else
    prompt_version_selection "proxy" "$REPO" RELEASES VERSION
  fi

  if [[ "$SKIP_UDPGW" == true ]]; then
    UDPGW_VERSION=""
  elif [[ -n "$UDPGW_VERSION" ]]; then
    resolve_version_in_list "$UDPGW_VERSION" UDPGW_RELEASES UDPGW_VERSION "udpgw" "$UDPGW_REPO"
  elif [[ "$ASSUME_YES" == true ]]; then
    resolve_version_in_list "latest" UDPGW_RELEASES UDPGW_VERSION "udpgw" "$UDPGW_REPO"
  else
    prompt_version_selection "udpgw" "$UDPGW_REPO" UDPGW_RELEASES UDPGW_VERSION
  fi
}

confirm_installation() {
  [[ "$ASSUME_YES" == true ]] && return 0

  echo ""
  local confirm_msg="Continuar com proxy ${VERSION}"
  [[ "$SKIP_UDPGW" != true && -n "$UDPGW_VERSION" ]] && confirm_msg+=" e udpgw ${UDPGW_VERSION}"
  confirm_msg+="?"
  read -rp "${confirm_msg} (s/N): " answer
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

  # Evita cache CDN do raw.githubusercontent.com (max-age=300).
  http_status=$(
    curl -fsSL \
      -H "Cache-Control: no-cache" \
      -H "Pragma: no-cache" \
      -w "%{http_code}" \
      -o "$output" \
      "$url" || true
  )
  if [[ "$http_status" != "200" ]]; then
    log_error "Falha ao baixar: $url (HTTP $http_status)"
    exit 1
  fi
  if [[ ! -s "$output" ]]; then
    log_error "Download vazio: $url"
    exit 1
  fi
}

file_sha256() {
  local file="$1"
  if has_command sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  elif has_command shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    wc -c <"$file" | tr -d ' '
  fi
}

extract_json_string_field() {
  local json="$1"
  local field="$2"
  echo "$json" \
    | grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" \
    | head -n1 \
    | sed -E "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/"
}

fetch_latest_release_tag() {
  local repo="$1"
  local json tag

  json=$(curl -fsSL \
    -H "Cache-Control: no-cache" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${repo}/releases/latest" || true)

  tag=$(extract_json_string_field "$json" "tag_name")
  if [[ -z "$tag" ]]; then
    return 1
  fi
  echo "$tag"
}

resolve_repo_main_sha() {
  local json sha
  json=$(curl -fsSL \
    -H "Cache-Control: no-cache" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/commits/main" || true)
  sha=$(extract_json_string_field "$json" "sha")
  if [[ -z "$sha" || ${#sha} -lt 7 ]]; then
    return 1
  fi
  echo "$sha"
}

verify_checksum() {
  local filename="$1"
  local sha_file="${filename}.sha256"
  local http_status

  http_status=$(curl -fsSL -w "%{http_code}" -o "$sha_file" "${DOWNLOAD_URL}.sha256" 2>/dev/null || true)
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

normalize_udpgw_release_tag() {
  local tag="$1"
  tag="${tag//$'\r'/}"
  tag="${tag#"${tag%%[![:space:]]*}"}"
  tag="${tag%"${tag##*[![:space:]]}"}"
  [[ -z "$tag" ]] && return 1
  [[ "$tag" == v* ]] || tag="v${tag}"
  echo "$tag"
}

verify_udpgw_checksum() {
  local filename="$1"
  local tag="$2"
  local sums_file="SHA256SUMS"
  local sums_url expected actual http_status

  tag=$(normalize_udpgw_release_tag "$tag" || echo "$tag")
  sums_url="https://github.com/${UDPGW_REPO}/releases/download/${tag}/${sums_file}"

  http_status=$(curl -fsSL -w "%{http_code}" -o "$sums_file" "$sums_url" 2>/dev/null || true)
  if [[ "$http_status" != "200" ]]; then
    log_warn "SHA256SUMS não encontrado em ${tag}. Pulando verificação..."
    return 0
  fi

  expected=$(grep -E "[[:space:]]${filename}$" "$sums_file" | awk '{print $1}' | head -n1)
  if [[ -z "$expected" ]]; then
    log_warn "Entrada SHA256 não encontrada para ${filename}. Pulando verificação..."
    return 0
  fi

  actual=$(file_sha256 "$filename")
  if [[ "$actual" != "$expected" ]]; then
    log_error "Checksum inválido para ${filename}"
    log_info "Esperado: ${expected}"
    log_info "Obtido:   ${actual}"
    exit 1
  fi

  log_success "Integridade SHA256 verificada (${filename})."
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

has_prior_installation() {
  local current

  current=$(get_installed_version 2>/dev/null || true)
  [[ -n "$current" ]] && return 0
  [[ -f /etc/proxy/token || -f /etc/vtproxy/proxy.token ]] && return 0
  [[ -d /etc/proxy/conf.d ]] && return 0
  has_existing_services && return 0
  has_active_proxy_process && return 0
  return 1
}
has_udpgw_service() {
  has_systemd || return 1
  [[ -f /etc/systemd/system/udpgw.service ]] && return 0
  local services=()
  read_nonempty_lines services < <(list_all_udpgw_services)
  [[ ${#services[@]} -gt 0 ]]
}

list_all_udpgw_services() {
  local services=() service_file service_name

  if ! has_systemd; then
    return 0
  fi

  while IFS= read -r service_file; do
    service_name="$(basename "$service_file")"
    [[ " ${services[*]} " == *" $service_name "* ]] || services+=("$service_name")
  done < <(find_service_files_by_exec 'ExecStart=.*/udpgw( |$)')

  for service_file in /etc/systemd/system/udpgw-*.service; do
    [[ -f "$service_file" ]] || continue
    service_name="$(basename "$service_file")"
    [[ " ${services[*]} " == *" $service_name "* ]] || services+=("$service_name")
  done

  if [[ -f /etc/systemd/system/udpgw.service ]]; then
    [[ " ${services[*]} " == *" udpgw.service "* ]] || services+=("udpgw.service")
  fi

  if [[ ${#services[@]} -gt 0 ]]; then
    printf '%s\n' "${services[@]}"
  fi
}

has_active_udpgw_process() {
  if has_command pgrep; then
    pgrep -f '/usr/local/bin/udpgw' >/dev/null 2>&1 && return 0
  fi
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

  systemctl list-units --type=service --all --no-legend 'proxy-*.service' 'vtproxy.service' 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^(proxy-[0-9]+\.service|vtproxy\.service)$' || true
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

  for service_file in /etc/systemd/system/proxy-*.service /etc/systemd/system/vtproxy.service; do
    [[ -f "$service_file" ]] || continue
    service_name="$(basename "$service_file")"
    [[ " ${services[*]} " == *" $service_name "* ]] || services+=("$service_name")
  done

  if [[ ${#services[@]} -gt 0 ]]; then
    printf '%s\n' "${services[@]}"
  fi
}

has_proxy_services() {
  local services=()
  read_nonempty_lines services < <(list_all_proxy_services)
  [[ ${#services[@]} -gt 0 ]]
}

has_existing_services() {
  has_proxy_services || has_udpgw_service
}

capture_active_services() {
  ACTIVE_PROXY_SERVICES=()
  ACTIVE_UDPGW=false
  ACTIVE_UDPGW_SERVICES=()

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

  read_nonempty_lines services < <(list_all_udpgw_services)
  for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      ACTIVE_UDPGW_SERVICES+=("$service")
      ACTIVE_UDPGW=true
    fi
  done

  if [[ "$ACTIVE_UDPGW" != true ]] && has_active_udpgw_process; then
    ACTIVE_UDPGW=true
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

  # Se qualquer serviço proxy estava ativo antes, ou em modo update/reinstall, reinicia os serviços existentes atuais
  if [[ "$MODE" == "update" || "$MODE" == "reinstall" || ${#ACTIVE_PROXY_SERVICES[@]} -gt 0 ]]; then
    read_nonempty_lines services < <(list_all_proxy_services)
  else
    return 0
  fi
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Reiniciando ${#services[@]} serviço(s) do proxy..."
  for service in "${services[@]}"; do
    run_privileged systemctl restart "$service" || log_warn "Não foi possível reiniciar $service"
  done
}


stop_udpgw_server() {
  local services=() service
  read_nonempty_lines services < <(list_all_udpgw_services)
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Parando ${#services[@]} serviço(s) udpgw..."
  for service in "${services[@]}"; do
    run_privileged systemctl stop "$service" || log_warn "Não foi possível parar $service"
  done
}

restart_udpgw_server() {
  local services=() service has_port_services=false

  if ! has_udpgw_service; then
    return 0
  fi

  for service_file in /etc/systemd/system/udpgw-*.service; do
    [[ -f "$service_file" ]] && has_port_services=true && break
  done

  if [[ "$MODE" == "update" || "$MODE" == "reinstall" ]]; then
    read_nonempty_lines services < <(list_all_udpgw_services)
  elif [[ ${#ACTIVE_UDPGW_SERVICES[@]} -gt 0 ]]; then
    services=("${ACTIVE_UDPGW_SERVICES[@]}")
  elif [[ "$ACTIVE_UDPGW" == true ]]; then
    read_nonempty_lines services < <(list_all_udpgw_services)
  else
    return 0
  fi
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Reiniciando ${#services[@]} serviço(s) udpgw..."
  for service in "${services[@]}"; do
    if [[ "$service" == "udpgw.service" && "$has_port_services" == true ]]; then
      run_privileged systemctl disable udpgw 2>/dev/null || true
      run_privileged systemctl stop udpgw 2>/dev/null || true
      continue
    fi
    run_privileged systemctl enable "$service" 2>/dev/null || true
    if ! run_privileged systemctl restart "$service"; then
      log_warn "Não foi possível reiniciar $service."
      log_info "Verifique: journalctl -u ${service%.service} -n 30 --no-pager"
      continue
    fi
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      log_success "${service} ativo."
    else
      log_warn "${service} não ficou ativo após restart."
    fi
  done
}

sync_udpgw_service() {
  local udpgw_bin="${INSTALL_DIR}/${UDPGW_BINARY_NAME}"
  local services=() service_file

  read_nonempty_lines services < <(list_all_udpgw_services)
  [[ ${#services[@]} -eq 0 ]] && return 0

  for service_file in "${services[@]}"; do
    service_file="/etc/systemd/system/${service_file}"
    [[ -f "$service_file" ]] || continue
    safe_sed_inplace "$service_file" \
      -e "s|/usr/local/bin/udpgw|${udpgw_bin}|g" \
      -e "s|${INSTALL_DIR}/udpgw|${udpgw_bin}|g" || true
  done
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

# --domain was removed from the proxy binary; old units still carry it and fail
# with "flag provided but not defined". Strip on every update/reinstall.
strip_legacy_proxy_flags() {
  local service_file conf_file stripped=0

  while IFS= read -r service_file; do
    [[ -f "$service_file" ]] || continue
    if grep -qE -- '--domain(=[^[:space:]]*)?' "$service_file"; then
      safe_sed_inplace "$service_file" -e 's/[[:space:]]+--domain(=[^[:space:]]*)?//g' || true
      stripped=$((stripped + 1))
    fi
  done < <(find_service_files_by_exec 'ExecStart=.*(/usr/local/bin/proxy-server|/usr/local/bin/proxy)( |$)')

  for service_file in /etc/systemd/system/proxy-*.service; do
    [[ -f "$service_file" ]] || continue
    if grep -qE -- '--domain(=[^[:space:]]*)?' "$service_file"; then
      safe_sed_inplace "$service_file" -e 's/[[:space:]]+--domain(=[^[:space:]]*)?//g' || true
      stripped=$((stripped + 1))
    fi
  done

  for conf_file in /etc/proxy/conf.d/proxy-*.conf; do
    [[ -f "$conf_file" ]] || continue
    if grep -qE '^DOMAIN=' "$conf_file"; then
      safe_sed_inplace "$conf_file" -e 's/^DOMAIN=.*/DOMAIN=false/' || true
    fi
  done

  if [[ "$stripped" -gt 0 ]]; then
    log_info "Removida flag legada --domain de ${stripped} unit(s) systemd."
  fi
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

  for service_file in /etc/systemd/system/proxy-*.service /etc/systemd/system/vtproxy.service; do
    [[ -f "$service_file" ]] || continue
    if grep -q -- '--token=' "$service_file"; then
      safe_sed_inplace "$service_file" "s|--token=[^ ]+|--token=${safe_token}|g" || true
    fi
  done
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

ensure_service_limit_nofile() {
  local service_file
  for service_file in /etc/systemd/system/proxy-*.service /etc/systemd/system/vtproxy.service /etc/systemd/system/udpgw-*.service /etc/systemd/system/udpgw.service; do
    [[ -f "$service_file" ]] || continue
    if grep -qE '^[[:space:]]*LimitNOFILE=' "$service_file"; then
      safe_sed_inplace "$service_file" -e 's/^[[:space:]]*LimitNOFILE=.*/LimitNOFILE=65536/' || true
    else
      safe_sed_inplace "$service_file" -e '/^\[Service\]/a LimitNOFILE=65536' || true
    fi
  done

  local gomemlimit
  gomemlimit=$(calculate_dynamic_gomemlimit 2>/dev/null || echo "620MiB")

  for service_file in /etc/systemd/system/proxy-*.service /etc/systemd/system/vtproxy.service; do
    [[ -f "$service_file" ]] || continue
    if grep -q 'GOMEMLIMIT' "$service_file"; then
      safe_sed_inplace "$service_file" -e 's/Environment="GOMEMLIMIT=[^"]*"/Environment="GOMEMLIMIT='"${gomemlimit}"'"/' || true
      safe_sed_inplace "$service_file" -e 's/Environment="GOGC=[^"]*"/Environment="GOGC=100"/' || true
    else
      safe_sed_inplace "$service_file" -e '/^\[Service\]/a Environment="GOMEMLIMIT='"${gomemlimit}"'"\nEnvironment="GOGC=100"' || true
    fi
  done
}

extract_or_ensure_proxy_conf() {
  local port="$1"
  local service_file="$2"
  local conf_file="/etc/proxy/conf.d/proxy-${port}.conf"

  run_privileged mkdir -p "/etc/proxy/conf.d" "/var/log/proxy" 2>/dev/null || true

  if [[ -f "$conf_file" ]]; then
    if grep -q '^ENABLED=' "$conf_file"; then
      safe_sed_inplace "$conf_file" -e 's/^ENABLED=.*/ENABLED=true/' || true
    else
      echo "ENABLED=true" | run_privileged tee -a "$conf_file" >/dev/null || true
    fi
    return 0
  fi

  local exec_line=""
  if [[ -f "$service_file" ]]; then
    exec_line=$(grep -E '^ExecStart=' "$service_file" 2>/dev/null | head -n1 | sed 's/^ExecStart=//')
  fi

  local ssl="false" cert="" cert_internal="true" ssh_only="false"
  local response="VTProxy" buffer="32768"

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

  cat <<EOF | run_privileged tee "$conf_file" >/dev/null
PORT=$port
ENABLED=true
SSL_ENABLED=$ssl
SSL_CERT_PATH=$cert
CERT_INTERNAL=$cert_internal
SSH_ONLY=$ssh_only
HTTP_RESPONSE=$response
BUFFER_SIZE=$buffer
DOMAIN=false
MAX_CONNECTIONS=0
WRITE_TIMEOUT=60
IDLE_TIMEOUT=120
LOG_LEVEL=info
SSH_PORT=22
OPENVPN_PORT=1194
V2RAY_PORT=1080
DISPLAY_BANNER=true
EOF
}

generate_standalone_unified_service() {
  local token proxy_bin port_args=() f port
  token="$PROXY_TOKEN"
  [[ -z "$token" ]] && token=$(load_saved_proxy_token || true)
  [[ -z "$token" ]] && return 0

  proxy_bin="/usr/local/bin/proxy-server"
  [[ -x "$proxy_bin" ]] || proxy_bin="/usr/local/bin/proxy"
  [[ -x "$proxy_bin" ]] || return 0

  for f in /etc/proxy/conf.d/proxy-*.conf; do
    [[ -f "$f" ]] || continue
    port=$(basename "$f" .conf | sed -n 's/^proxy-\([0-9]\+\)$/\1/p')
    [[ -z "$port" ]] && continue

    local enabled ssl
    enabled=$(grep '^ENABLED=' "$f" 2>/dev/null | cut -d= -f2 || echo "true")
    [[ "$enabled" == "false" ]] && continue
    ssl=$(grep '^SSL_ENABLED=' "$f" 2>/dev/null | cut -d= -f2 || echo "false")

    if [[ "$ssl" == "true" ]]; then
      port_args+=("--port=$port:ssl")
    else
      port_args+=("--port=$port")
    fi
  done

  [[ ${#port_args[@]} -eq 0 ]] && return 0

  local gomemlimit
  gomemlimit=$(calculate_dynamic_gomemlimit 2>/dev/null || echo "620MiB")

  cat <<EOF | run_privileged tee "/etc/systemd/system/vtproxy.service" >/dev/null
[Unit]
Description=VTProxy Unified Proxy Server
After=network.target

[Service]
Environment="GOMEMLIMIT=${gomemlimit}"
Environment="GOGC=100"
ExecStart=$proxy_bin --token=$token ${port_args[*]} --buffer-size=32768 --response=VTProxy --log-file=/var/log/proxy/proxy.log --log-level=info --ssh-port=22 --openvpn-port=1194 --v2ray-port=1080 --max-connections=0 --write-timeout=60 --idle-timeout=120 --cert-internal=true
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  run_privileged systemctl daemon-reload || true
  run_privileged systemctl enable vtproxy.service 2>/dev/null || true
}

migrate_legacy_proxy_services() {
  if ! has_systemd; then
    return 0
  fi

  local legacy_files=() service_file port
  for service_file in /etc/systemd/system/proxy-*.service; do
    [[ -f "$service_file" ]] || continue
    port=$(basename "$service_file" .service | sed -n 's/^proxy-\([0-9]\+\)$/\1/p')
    [[ -n "$port" ]] && legacy_files+=("$service_file")
  done

  [[ ${#legacy_files[@]} -eq 0 ]] && return 0

  log_info "Detectados ${#legacy_files[@]} serviço(s) proxy legados (separados por porta)."
  log_info "Iniciando migração de serviços para 'vtproxy.service'..."

  for service_file in "${legacy_files[@]}"; do
    port=$(basename "$service_file" .service | sed -n 's/^proxy-\([0-9]\+\)$/\1/p')
    [[ -z "$port" ]] && continue

    extract_or_ensure_proxy_conf "$port" "$service_file"

    log_info "Desativando e removendo serviço legado: proxy-$port.service"
    run_privileged systemctl stop "proxy-$port.service" 2>/dev/null || true
    run_privileged systemctl disable "proxy-$port.service" 2>/dev/null || true
    run_privileged rm -f "$service_file"
  done

  run_privileged systemctl daemon-reload || true

  if [[ -x "/usr/local/bin/vt" ]]; then
    /usr/local/bin/vt --migrate >/dev/null 2>&1 || true
  fi

  if [[ ! -f "/etc/systemd/system/vtproxy.service" ]]; then
    generate_standalone_unified_service
  fi

  log_info "Migração concluída com sucesso! Serviço 'vtproxy.service' configurado."
}

refresh_existing_services() {
  local proxy_token

  if ! should_manage_services; then
    return 0
  fi

  log_info "Atualizando serviços systemd existentes..."

  # Migração inteligente de serviços legados proxy-*.service para vtproxy.service
  migrate_legacy_proxy_services

  proxy_token="$PROXY_TOKEN"
  if [[ -z "$proxy_token" ]]; then
    proxy_token=$(load_saved_proxy_token || true)
  fi

  sync_proxy_service_executables
  strip_legacy_proxy_flags
  [[ -n "$proxy_token" ]] && sync_proxy_service_tokens "$proxy_token"
  sync_udpgw_service
  ensure_service_limit_nofile

  if [[ -x "/usr/local/bin/vt" ]]; then
    /usr/local/bin/vt --migrate >/dev/null 2>&1 || true
  fi

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

  mapfile -t proxy_services < <(list_proxy_services)
  count=${#proxy_services[@]}

  if [[ $count -gt 0 ]]; then
    log_info "Serviço(s) proxy existente(s) detectado(s): ${proxy_services[*]}"
  elif has_active_proxy_process; then
    log_warn "Processo proxy ativo detectado — reinicie manualmente se não houver unit systemd."
  fi

  if [[ "$SKIP_UDPGW" != true ]]; then
    if [[ ${#ACTIVE_UDPGW_SERVICES[@]} -gt 0 ]]; then
      log_warn "${#ACTIVE_UDPGW_SERVICES[@]} serviço(s) udpgw ativo(s): ${ACTIVE_UDPGW_SERVICES[*]//.service/}"
    elif [[ "$ACTIVE_UDPGW" == true ]]; then
      log_warn "UDP Gateway ativo detectado — unit files serão atualizados e os serviços reiniciados."
    else
      log_warn "Serviço(s) udpgw configurado(s) — unit files serão atualizados se necessário."
    fi
  fi
}

set_limit_entry() {
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
    safe_sed_inplace "$file" -e "s|^([[:space:]]*)${esc_domain}([[:space:]]+)${type}([[:space:]]+)${item}([[:space:]]+)[0-9]+|\1${domain}\2${type}\3${item}\4${val}|g" || true
  else
    printf '%s\t%s\t%s\t%s\n' "$domain" "$type" "$item" "$val" | run_privileged tee -a "$file" >/dev/null
  fi
}

configure_limits() {
  log_info "Configurando limites de arquivos (limits.d / File Descriptors: 65536)..."

  if [[ -d /etc/security ]]; then
    run_privileged mkdir -p /etc/security/limits.d 2>/dev/null || true
    run_privileged rm -f /etc/security/limits.d/99-veltrix-proxy.conf 2>/dev/null || true
    cat << 'EOF' | run_privileged tee /etc/security/limits.d/99-proxy.conf >/dev/null
# VeltrixProxy / VTProxy - File Descriptors & Sockets Limits (65536 conexões)
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
  fi

  if [[ -f /etc/security/limits.conf ]]; then
    set_limit_entry "/etc/security/limits.conf" "*" "soft" "nofile" "65536"
    set_limit_entry "/etc/security/limits.conf" "*" "hard" "nofile" "65536"
    set_limit_entry "/etc/security/limits.conf" "root" "soft" "nofile" "65536"
    set_limit_entry "/etc/security/limits.conf" "root" "hard" "nofile" "65536"
  fi

  if [[ -d /etc/profile.d ]]; then
    echo 'ulimit -n 65536 2>/dev/null || true' | run_privileged tee /etc/profile.d/99-proxy-limits.sh >/dev/null
    run_privileged chmod 644 /etc/profile.d/99-proxy-limits.sh 2>/dev/null || true
  fi

  ulimit -n 65536 2>/dev/null || true
  log_success "Limites de File Descriptors configurados (65536)."
}

configure_sysctl() {
  log_info "Otimizando parâmetros de Kernel e Rede (TCP / BBR / sysctl)..."
  local sysctl_conf="/etc/sysctl.d/99-proxy.conf"

  run_privileged rm -f /etc/sysctl.d/99-vtproxy.conf /etc/sysctl.d/99-veltrix-proxy.conf /etc/sysctl.d/zz-custom-network.conf 2>/dev/null || true
  run_privileged mkdir -p /etc/sysctl.d 2>/dev/null || true

  if [[ -f /etc/sysctl.conf ]]; then
    safe_sed_inplace "/etc/sysctl.conf" -e '/^(net\.core\.(somaxconn|rmem_max|wmem_max|rmem_default|wmem_default|netdev_max_backlog|default_qdisc)|net\.ipv4\.(tcp_tw_reuse|tcp_fin_timeout|tcp_max_tw_buckets|ip_local_port_range|tcp_max_syn_backlog|tcp_slow_start_after_idle|tcp_fastopen|tcp_rmem|tcp_wmem|tcp_congestion_control|tcp_keepalive_time|tcp_keepalive_intvl|tcp_keepalive_probes)|vm\.swappiness)/d' || true
  fi

  cat << 'EOF' | run_privileged tee "$sysctl_conf" >/dev/null
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

  run_privileged modprobe tcp_bbr 2>/dev/null || true
  run_privileged modprobe sch_fq 2>/dev/null || true

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
    run_privileged sysctl -w "$kv" >/dev/null 2>&1 || true
  done

  run_privileged sysctl -p "$sysctl_conf" >/dev/null 2>&1 || true
  run_privileged sysctl --system >/dev/null 2>&1 || true

  local active_cc
  active_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "bbr")
  log_success "Otimizações de Kernel aplicadas (Algoritmo TCP ativo: ${active_cc})."
}

configure_locale_tuning() {
  if [[ -d /etc/profile.d ]]; then
    cat << 'EOF' | run_privileged tee /etc/profile.d/99-utf8.sh >/dev/null
export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"
export LC_CTYPE="C.UTF-8"
EOF
    run_privileged chmod 644 /etc/profile.d/99-utf8.sh 2>/dev/null || true
  fi

  if [[ -f /etc/bash.bashrc ]] && ! grep -q "LANG=C.UTF-8" /etc/bash.bashrc 2>/dev/null; then
    echo 'export LANG="C.UTF-8" LC_ALL="C.UTF-8"' | run_privileged tee -a /etc/bash.bashrc >/dev/null || true
  fi

  if [[ -f /etc/environment ]] && ! grep -q "LANG=" /etc/environment 2>/dev/null; then
    echo 'LANG="C.UTF-8"' | run_privileged tee -a /etc/environment >/dev/null || true
  fi

  export LANG="C.UTF-8"
  export LC_ALL="C.UTF-8"
  export LC_CTYPE="C.UTF-8"
  log_success "Configuração global de locale UTF-8 aplicada (C.UTF-8)."
}

configure_ssh_tuning() {
  local sshd_config="/etc/ssh/sshd_config"
  local sshd_dropin_dir="/etc/ssh/sshd_config.d"
  local sshd_dropin_conf="${sshd_dropin_dir}/99-proxy.conf"
  local keys_regex="LogLevel|AcceptEnv|MaxStartups|MaxSessions|MaxAuthTries|LoginGraceTime|UsePAM|UseDNS|GSSAPIAuthentication|TCPKeepAlive|ClientAliveInterval|ClientAliveCountMax|AllowTcpForwarding|GatewayPorts|PermitTunnel|X11Forwarding|Compression|PrintMotd|PrintLastLog"

  # 1. Configura drop-in modular em /etc/ssh/sshd_config.d/
  if [[ -d /etc/ssh ]]; then
    run_privileged mkdir -p "$sshd_dropin_dir" 2>/dev/null || true
    run_privileged rm -f "${sshd_dropin_dir}/99-vtproxy.conf" "${sshd_dropin_dir}/99-veltrix-proxy.conf" 2>/dev/null || true

    cat << 'EOF' | run_privileged tee "$sshd_dropin_conf" >/dev/null
# VTProxy / VeltrixProxy OpenSSH Optimizations for High Concurrency Tunnels
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
    run_privileged chmod 644 "$sshd_dropin_conf" 2>/dev/null || true
  fi

  # 2. Garante o Include e remove duplicatas do /etc/ssh/sshd_config principal
  if [[ -f "$sshd_config" ]]; then
    if ! grep -qiE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$sshd_config"; then
      safe_sed_inplace "$sshd_config" -e '1i Include /etc/ssh/sshd_config.d/*.conf\n' || true
    fi

    # Remove qualquer ocorrência duplicada/antiga das chaves gerenciadas de forma case-insensitive
    safe_sed_inplace "$sshd_config" -e "/^[[:space:]]*(${keys_regex})([[:space:]=]|$)/Id" || true
  fi

  # 3. Systemd Limits & TasksMax Override para ssh / sshd
  for svc_dir in /etc/systemd/system/ssh.service.d /etc/systemd/system/sshd.service.d; do
    run_privileged mkdir -p "$svc_dir" 2>/dev/null || true
    cat << 'EOF' | run_privileged tee "${svc_dir}/99-proxy-limits.conf" >/dev/null
[Service]
LimitNOFILE=1048576
LimitNPROC=65536
TasksMax=infinity
EOF
  done

  # 4. Validação segura antes de recarregar
  if sshd -t >/dev/null 2>&1; then
    has_systemd && run_privileged systemctl daemon-reload >/dev/null 2>&1 || true
    run_privileged systemctl reload ssh >/dev/null 2>&1 || run_privileged systemctl reload sshd >/dev/null 2>&1 || run_privileged service ssh reload >/dev/null 2>&1 || run_privileged service sshd reload >/dev/null 2>&1 || true
    log_success "Otimizações do OpenSSH aplicadas com sucesso (MaxStartups 2000, Anti-Ghosting, NoDNS)."
  else
    log_warn "Validação do sshd -t encontrou avisos. Mantendo configuração sem forçar reload."
  fi
}

configure_system_tuning() {
  configure_limits
  configure_sysctl
  configure_locale_tuning
  configure_ssh_tuning
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

download_and_install_udpgw_binary() {
  local udpgw_arch filename tag url

  udpgw_arch=$(detect_udpgw_arch)
  filename="udpgw-${OS_NAME}-${udpgw_arch}"
  tag=$(normalize_udpgw_release_tag "$UDPGW_VERSION" || echo "$UDPGW_VERSION")
  url="https://github.com/${UDPGW_REPO}/releases/download/${tag}/${filename}"

  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] || TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR"

  log_info "Baixando binário udpgw: $filename (${tag})"
  log_info "URL: $url"
  download_file "$url" "$filename"
  verify_udpgw_checksum "$filename" "$tag"

  log_info "Instalando binário em ${INSTALL_DIR}/${UDPGW_BINARY_NAME}..."
  run_privileged install -m 755 "$filename" "${INSTALL_DIR}/${UDPGW_BINARY_NAME}"
  INSTALLED_UDPGW_VERSION="${tag#v}"
  echo "$INSTALLED_UDPGW_VERSION" | run_privileged tee "$UDPGW_VERSION_FILE" >/dev/null

  log_success "Binário udpgw instalado: ${INSTALL_DIR}/${UDPGW_BINARY_NAME} (${tag})"
}

install_menu_script() {
  if [[ "$BINARY_ONLY" == true ]]; then
    log_info "Pulando instalação do menu (--binary-only)."
    return 0
  fi

  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] || TMP_DIR=$(mktemp -d)

  local menu_tmp="${TMP_DIR}/vt.sh"
  local menu_dest="${INSTALL_DIR}/${MENU_NAME}"
  local old_hash="(ausente)" new_hash menu_url menu_sha menu_bytes menu_rev_found

  if [[ -f "$menu_dest" ]]; then
    old_hash=$(file_sha256 "$menu_dest")
    log_info "Menu atual: ${menu_dest} (sha256=${old_hash:0:12}…)"
  fi

  log_info "Baixando menu unificado (vt.sh) do branch main (sem cache)..."
  MENU_COMMIT_SHA=$(resolve_repo_main_sha || true)
  if [[ -n "$MENU_COMMIT_SHA" ]]; then
    # URL por commit SHA evita cache do path /main/
    menu_url="https://raw.githubusercontent.com/${REPO}/${MENU_COMMIT_SHA}/vt.sh"
    log_info "Commit main: ${MENU_COMMIT_SHA:0:12}"
  else
    menu_url="${MENU_URL}?$(date +%s)"
    log_warn "Não foi possível resolver SHA do main; usando URL com cache-bust."
  fi

  download_file "$menu_url" "$menu_tmp"

  if ! grep -q "MENU_REV=" "$menu_tmp" 2>/dev/null && ! grep -q "prompt_proxy_advanced_options" "$menu_tmp" 2>/dev/null; then
    log_warn "Menu baixado parece antigo/incompleto — tentando URL alternativa."
    download_file "${MENU_URL}?ts=$(date +%s)&nocache=1" "$menu_tmp"
  fi

  if ! head -n1 "$menu_tmp" | grep -qE '^#!'; then
    log_error "Menu baixado inválido (sem shebang)."
    exit 1
  fi

  menu_rev_found=$(
    grep -oE 'MENU_REV="[^"]+"' "$menu_tmp" 2>/dev/null \
      | head -n1 \
      | sed -E 's/MENU_REV="([^"]+)"/\1/' || true
  )

  # Remove destino (symlink ou arquivo) antes de instalar — evita escrever através de symlink antigo.
  run_privileged rm -f "$menu_dest"
  run_privileged install -m 755 "$menu_tmp" "$menu_dest"

  # Garante que o shell não use hash antigo do comando vt
  hash -r 2>/dev/null || true

  new_hash=$(file_sha256 "$menu_dest")
  menu_bytes=$(wc -c <"$menu_dest" | tr -d ' ')
  echo "${menu_rev_found:-unknown}" | run_privileged tee "$MENU_REV_FILE" >/dev/null

  if [[ "$old_hash" == "$new_hash" ]]; then
    log_warn "Hash do menu igual ao anterior (${new_hash:0:12}…). Se esperava mudanças, limpe cache CDN ou force push do vt.sh."
  else
    log_success "Menu substituído (${old_hash:0:12}… → ${new_hash:0:12}…)"
  fi

  if [[ -n "$menu_rev_found" ]]; then
    log_success "Menu instalado: ${menu_dest} (${menu_bytes} bytes, rev=${menu_rev_found})"
    if [[ -n "$MENU_REV_EXPECTED" && "$menu_rev_found" != "$MENU_REV_EXPECTED" ]]; then
      log_warn "Revisão do menu (${menu_rev_found}) difere da esperada pelo instalador (${MENU_REV_EXPECTED})."
      log_warn "Faça push do vt.sh no GitHub main e rode o update de novo."
    fi
  else
    log_success "Menu instalado: ${menu_dest} (${menu_bytes} bytes)"
    log_warn "MENU_REV não encontrado no vt.sh baixado — confirme se o main está atualizado."
  fi

  if command -v "$MENU_NAME" >/dev/null 2>&1; then
    local resolved
    resolved=$(command -v "$MENU_NAME")
    if [[ "$resolved" != "$menu_dest" ]]; then
      log_warn "Comando '${MENU_NAME}' resolve para ${resolved} (esperado: ${menu_dest}). Ajuste o PATH."
    fi
  fi
}

install_provided_tokens() {
  [[ -z "$PROXY_TOKEN" ]] && return 0

  log_info "Configurando token proxy fornecido pelo instalador..."

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

  if [[ -n "$INSTALL_IP" ]]; then
    run_privileged mkdir -p /etc/vtproxy
    printf '%s' "$INSTALL_IP" | run_privileged tee /etc/vtproxy/ip >/dev/null
    log_info "IP vinculado registrado: $INSTALL_IP"
  fi
}

print_finish_message() {
  if [[ "${SKIP_HEADER:-false}" == true ]]; then
    log_success "Operação concluída com sucesso! (proxy: $VERSION)"
    return 0
  fi

  clear
  render_step_dashboard

  print_dash_rule
  print_dashboard_center "✅  INSTALAÇÃO CONCLUÍDA COM SUCESSO!" "${GREEN:-\033[0;32m}"
  print_dash_rule
  print_dashboard_item "" "  Versão Proxy:   $VERSION"
  if [[ -n "$INSTALLED_UDPGW_VERSION" ]]; then
    print_dashboard_item "" "  Versão UDPgw:   v${INSTALLED_UDPGW_VERSION#v}"
  fi
  if [[ "$BINARY_ONLY" == false ]]; then
    local rev="-"
    [[ -f "$MENU_REV_FILE" ]] && rev=$(tr -d '\r\n' <"$MENU_REV_FILE")
    print_dashboard_item "" "  Menu vt:        rev ${rev} (${INSTALL_DIR}/${MENU_NAME})"
  fi
  print_dashboard_item "" "  Serviços:       Sincronizados e Ativos (vtproxy)"
  print_dash_rule
  print_dashboard_center "Execute o menu a qualquer momento com o comando:" "${YELLOW:-\033[1;33m}"
  print_dashboard_center "👉  vt" "${GREEN:-\033[0;32m}"
  print_dash_rule
  echo
}

main() {
  parse_args "$@"
  print_header

  # Step 0: Root & Sudo
  set_step_status 0 1
  ensure_sudo
  set_step_status 0 2 "Root OK"

  # Step 1: Dependências
  set_step_status 1 1
  ensure_dependencies
  set_step_status 1 2 "OK"

  # Step 2: Sincronização de Relógio
  set_step_status 2 1
  ensure_system_clock || true
  set_step_status 2 2 "NTP OK"

  # Step 3: Plataforma & Releases
  set_step_status 3 1
  detect_platform
  capture_active_services
  fetch_releases
  if [[ "$SKIP_UDPGW" != true ]]; then
    fetch_udpgw_releases
  fi
  show_versions_and_select
  confirm_installation
  set_step_status 3 2 "Proxy ${VERSION}"

  # Parar serviços ativos se necessário
  if should_manage_services; then
    SERVICES_WERE_STOPPED=true
    stop_proxy_services
    stop_udpgw_server
  fi

  # Step 4: Binários
  set_step_status 4 1
  download_and_install_binary
  if [[ "$SKIP_UDPGW" != true && -n "$UDPGW_VERSION" ]]; then
    download_and_install_udpgw_binary
  fi
  set_step_status 4 2 "${VERSION} / v${INSTALLED_UDPGW_VERSION#v}"

  # Step 5: Kernel & Sysctl
  set_step_status 5 1
  configure_system_tuning
  set_step_status 5 2 "BBR OK"

  # Step 6: Script do Menu
  set_step_status 6 1
  install_menu_script
  install_provided_tokens
  local rev_installed="-"
  [[ -f "$MENU_REV_FILE" ]] && rev_installed=$(tr -d '\r\n' <"$MENU_REV_FILE")
  set_step_status 6 2 "vt rev ${rev_installed}"

  # Step 7: Serviços Systemd
  set_step_status 7 1
  refresh_existing_services
  if should_manage_services; then
    restart_proxy_services
    restart_udpgw_server
  fi
  set_step_status 7 2 "vtproxy OK"

  INSTALL_COMPLETED=true
  print_finish_message
}

main "$@"

#!/bin/bash
set -euo pipefail

REPO="TelksBr/VeltrixProxy"
PROJECT_NAME="VTProxy"
MAIN_URL="https://raw.githubusercontent.com/TelksBr/VeltrixProxy/refs/heads/main/main.sh"
BINARY_NAME="proxy"
MAIN_NAME="main"
INSTALL_DIR="/usr/local/bin"
VERSION_FILE="/etc/proxyvt-version"
TMP_DIR=""

MODE="install"
VERSION=""
ASSUME_YES=false
BINARY_ONLY=false
SKIP_HEADER=false
MAX_VERSIONS=10

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

usage() {
  cat <<EOF
Uso: $0 [opções]

Modos:
  (padrão)        Instalação interativa com escolha de versão
  --install       Mesmo que o padrão
  --update        Atualiza para a versão mais recente (reinicia serviços ativos)
  --reinstall     Reinstala binário e main.sh (interativo ou com --latest)

Opções:
  --latest, -L    Usa a versão mais recente sem menu
  --version TAG   Instala uma versão específica (ex: v2.1.0)
  --binary-only   Instala/atualiza apenas o binário (não baixa main.sh)
  --yes, -y       Sem confirmações interativas
  --quiet, -q     Menos saída visual (não limpa a tela)
  -h, --help      Exibe esta ajuda

Exemplos:
  $0
  $0 --update --yes
  $0 --reinstall --latest --yes
  $0 --version v2.1.0 --binary-only -y
EOF
}

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --install) MODE="install" ;;
    --update) MODE="update" ;;
    --reinstall) MODE="reinstall" ;;
    --latest | -L) VERSION="latest" ;;
    --version)
      shift
      VERSION="${1:-}"
      [[ -n "$VERSION" ]] || { log_error "Use --version TAG"; exit 1; }
      ;;
    --binary-only) BINARY_ONLY=true ;;
    --yes | -y) ASSUME_YES=true ;;
    --quiet | -q) SKIP_HEADER=true ;;
    -h | --help)
      usage
      exit 0
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
    ASSUME_YES=true
    ;;
  reinstall)
    BINARY_ONLY=false
    ;;
  esac
}

print_header() {
  [[ "$SKIP_HEADER" == true ]] && return 0
  clear
  echo -e "${BLUE}╔═══════════════════════════════════════════════════╗"
  echo -e "║              INSTALADOR ${PROJECT_NAME}$(printf '%*s' $((19 - ${#PROJECT_NAME})) '')║"
  echo -e "╠═══════════════════════════════════════════════════╣"
  echo -e "║ Repositório: $(printf '%-36s' "$REPO") ║"
  echo -e "║ Modo:        $(printf '%-36s' "$MODE") ║"
  echo -e "║ Binário:     $(printf '%-36s' "$INSTALL_DIR/$BINARY_NAME") ║"
  echo -e "╚═══════════════════════════════════════════════════╝${NC}"
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
  command -v curl >/dev/null 2>&1 || missing+=("curl")
  command -v jq >/dev/null 2>&1 || missing+=("jq")
  command -v sha256sum >/dev/null 2>&1 || missing+=("sha256sum")
  printf '%s\n' "${missing[@]}"
}

commands_to_packages() {
  local cmd packages=() pkg
  for cmd in "$@"; do
    case "$cmd" in
    curl) pkg="curl" ;;
    jq) pkg="jq" ;;
    sha256sum) pkg="coreutils" ;;
    *) continue ;;
    esac
    [[ " ${packages[*]} " == *" $pkg "* ]] || packages+=("$pkg")
  done
  printf '%s\n' "${packages[@]}"
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

ensure_dependencies() {
  local missing=() packages=() pm

  mapfile -t missing < <(get_missing_commands)
  [[ ${#missing[@]} -eq 0 ]] && return 0

  log_warn "Dependências ausentes: ${missing[*]}"

  pm=$(detect_package_manager)
  if [[ "$pm" == "unknown" ]]; then
    log_error "Gerenciador de pacotes não suportado."
    log_info "Instale manualmente: curl jq coreutils"
    exit 1
  fi

  mapfile -t packages < <(commands_to_packages "${missing[@]}")
  log_info "Instalando dependências via ${pm}: ${packages[*]}"

  if ! install_packages "$pm" "${packages[@]}"; then
    log_error "Falha ao instalar dependências automaticamente."
    exit 1
  fi

  mapfile -t missing < <(get_missing_commands)
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Ainda faltam dependências após instalação: ${missing[*]}"
    exit 1
  fi

  log_success "Dependências instaladas com sucesso."
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

  if [[ -f "$VERSION_FILE" ]]; then
    tr -d 'v' <"$VERSION_FILE"
  fi
}

show_current_installation() {
  local current
  current=$(get_installed_version || true)
  if [[ -n "$current" ]]; then
    log_info "Versão instalada atualmente: v${current}"
  else
    log_warn "Nenhuma instalação detectada em ${INSTALL_DIR}/${BINARY_NAME}"
  fi
}

fetch_releases() {
  local releases_json
  releases_json=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases?per_page=${MAX_VERSIONS}")

  if ! echo "$releases_json" | jq -e 'type == "array"' >/dev/null; then
    log_error "Erro ao buscar releases no GitHub."
    echo "$releases_json"
    exit 1
  fi

  mapfile -t RELEASES < <(echo "$releases_json" | jq -r '.[].tag_name')

  if [[ ${#RELEASES[@]} -eq 0 ]]; then
    log_error "Nenhuma release encontrada em ${REPO}."
    exit 1
  fi
}

resolve_version() {
  if [[ "$VERSION" == "latest" || -z "$VERSION" ]]; then
    VERSION="${RELEASES[0]}"
    log_success "Versão selecionada (mais recente): $VERSION"
    return
  fi

  if [[ "$VERSION" != v* ]]; then
    VERSION="v${VERSION}"
  fi

  local tag
  for tag in "${RELEASES[@]}"; do
    if [[ "$tag" == "$VERSION" ]]; then
      log_success "Versão selecionada: $VERSION"
      return
    fi
  done

  log_error "Versão $VERSION não encontrada nas últimas ${MAX_VERSIONS} releases."
  exit 1
}

show_versions_and_select() {
  if [[ -n "$VERSION" ]]; then
    resolve_version
    return
  fi

  echo ""
  echo -e "${BLUE}📦 Versões disponíveis:${NC}"
  for i in "${!RELEASES[@]}"; do
    printf " %d) %s\n" $((i + 1)) "${RELEASES[$i]}"
  done

  echo ""
  while true; do
    read -rp "Escolha uma versão [1]: " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && ((choice >= 1 && choice <= ${#RELEASES[@]})); then
      VERSION="${RELEASES[$((choice - 1))]}"
      log_success "Versão selecionada: $VERSION"
      break
    fi
    log_error "Escolha inválida. Tente novamente."
  done
}

confirm_installation() {
  [[ "$ASSUME_YES" == true ]] && return 0

  echo ""
  read -rp "Continuar com a instalação de ${VERSION}? (s/N): " answer
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
  if ! (cd "$TMP_DIR" && sha256sum -c "$sha_file"); then
    log_error "Checksum inválido para $filename"
    exit 1
  fi
}

list_proxy_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi

  systemctl list-units --type=service --all --no-legend 'proxy-*.service' 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^proxy-[0-9]+\.service$' || true
}

stop_proxy_services() {
  local services
  mapfile -t services < <(list_proxy_services)
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Parando ${#services[@]} serviço(s) do proxy..."
  for service in "${services[@]}"; do
    sudo systemctl stop "$service" || log_warn "Não foi possível parar $service"
  done
}

restart_proxy_services() {
  local services
  mapfile -t services < <(list_proxy_services)
  [[ ${#services[@]} -eq 0 ]] && return 0

  log_info "Reiniciando ${#services[@]} serviço(s) do proxy..."
  for service in "${services[@]}"; do
    sudo systemctl restart "$service" || log_warn "Não foi possível reiniciar $service"
  done
}

download_and_install_binary() {
  local filename="${BINARY_NAME}-${OS_NAME}-${ARCH_NAME}"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${filename}"

  TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR"

  log_info "Baixando binário: $filename ($VERSION)"
  download_file "$DOWNLOAD_URL" "$filename"
  verify_checksum "$filename"

  log_info "Instalando binário em ${INSTALL_DIR}/${BINARY_NAME}..."
  sudo install -m 755 "$filename" "${INSTALL_DIR}/${BINARY_NAME}"
  echo "${VERSION#v}" | sudo tee "$VERSION_FILE" >/dev/null

  log_success "Binário instalado: ${INSTALL_DIR}/${BINARY_NAME} ($VERSION)"
}

install_main_script() {
  if [[ "$BINARY_ONLY" == true ]]; then
    log_info "Pulando instalação do main.sh (--binary-only)."
    return 0
  fi

  log_info "Baixando script main.sh..."
  local main_tmp="${TMP_DIR}/main.sh"
  download_file "$MAIN_URL" "$main_tmp"
  sudo install -m 755 "$main_tmp" "${INSTALL_DIR}/${MAIN_NAME}"
  log_success "main.sh instalado em: ${INSTALL_DIR}/${MAIN_NAME}"
}

print_finish_message() {
  echo ""
  log_success "Operação concluída com sucesso!"
  log_info "Versão instalada: $VERSION"
  if [[ "$BINARY_ONLY" == false ]]; then
    log_info "Execute o menu com: ${MAIN_NAME}"
  fi
}

main() {
  parse_args "$@"
  print_header
  ensure_dependencies
  detect_platform
  show_current_installation
  fetch_releases
  show_versions_and_select
  confirm_installation

  if [[ "$MODE" == "update" || "$MODE" == "reinstall" ]]; then
    stop_proxy_services
  fi

  download_and_install_binary
  install_main_script

  if [[ "$MODE" == "update" || "$MODE" == "reinstall" ]]; then
    restart_proxy_services
  fi

  print_finish_message
}

main "$@"

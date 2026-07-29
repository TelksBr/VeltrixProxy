# VeltrixProxy

Repositório de releases dos binários do **VTProxy**.

Os arquivos são publicados automaticamente pelo CI/CD.

## Instalação

O comando abaixo verifica/instala `curl` antes de baixar o instalador (evita falha imediata em VPS mínima):

```bash
if ! command -v curl >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y curl
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm curl
  elif command -v zypper >/dev/null 2>&1; then
    zypper install -y curl
  fi
fi
command -v curl >/dev/null 2>&1 || { echo "Instale curl manualmente e tente novamente."; exit 1; }
curl -fsSL "https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh?$(date +%s)" | bash
```

## Atualizar

```bash
command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; }
curl -fsSL "https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh?$(date +%s)" | bash -s -- --update --yes
```

## Reinstalar

```bash
command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; }
curl -fsSL "https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh?$(date +%s)" | bash -s -- --reinstall --latest --yes
```

## Menu

Após instalar, execute:

```bash
vt
```

(`main` e `proto` são symlinks para `vt` na instalação padrão.)

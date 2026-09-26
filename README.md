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

(`main` é symlink para `vt` na instalação padrão.)

Tela inicial:

| Tecla | Menu | Conteúdo |
|---|---|---|
| 1 | Proxy | portas, serviço (iniciar/parar/reiniciar), logs e métricas ao vivo |
| 2 | Xray | gerar link VLESS/VMess, ativar, geral, TLS, JSON legado |
| 3 | DNSTT | ativar, domínio, chaves, UDP, fallback, upstream, MTU, porta 53 |
| 4 | BadVPN / UDPGW | motor interno e faixa de portas |
| 5 | Usuários | conexões online, desconectar, limites e expiração |
| 6 | Token de Licença | definir e validar |
| 7 | Configurações Avançadas | protocolos (SSH, BTUN, XHTTP, Ztun, HCR), TLS/SSL, desempenho, HTTP/banner/logs, ver `config.json` |
| 8 | Atualizar | proxy e menu |
| 9 | Idioma | PT / EN / ES |
| D | Desinstalar | remove o VTProxy |

Ao sair de um submenu que alterou o `config.json`, o menu pergunta uma única vez se deve reiniciar o proxy.

# 🌐 VeltrixProxy (VTProxy)

Repositório oficial de distribuição e releases dos binários do **VTProxy** — Servidor proxy de tunelamento TCP/TLS, SSH e WebSocket de alto desempenho para Linux.

Os binários deste repositório são compilados e selados automaticamente via CI/CD.

---

## 📋 Sumário

- [Instalação Rápida](#-instalação-rápida)
- [Atualização e Manutenção](#-atualização-e-manutenção)
- [Menu Administrativo (`vt`)](#-menu-administrativo-vt)
- [Integração para Painéis e Scripts](#-integração-para-painéis-e-scripts)
  - [1. Leitura via Arquivo de Linhas (`proxy-onlines.txt`)](#1-leitura-via-arquivo-de-linhas-proxy-onlinestxt)
  - [2. Leitura via Arquivo JSON (`proxy-onlines.json`)](#2-leitura-via-arquivo-json-proxy-onlinesjson)
  - [3. Consultas Diretas via CLI (`proxy-server`)](#3-consultas-diretas-via-cli-proxy-server)
  - [4. IPC UNIX Domain Socket (`/run/proxy.sock`)](#4-ipc-unix-domain-socket-runproxysock)
- [Gerenciamento de Sessões (Kick e Expiração)](#-gerenciamento-de-sessões-kick-e-expiração)
- [Limites e Autenticação de Usuários](#-limites-e-autenticação-de-usuários)
- [Exemplos Práticos de Código](#-exemplos-práticos-de-código)
- [Serviço Systemd e Logs](#-serviço-systemd-e-logs)

---

## 📥 Instalação Rápida

O comando abaixo verifica e instala dependências básicas (`curl`) antes de iniciar o assistente de instalação interativo:

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

---

## 🔄 Atualização e Manutenção

### Atualizar para a versão mais recente
```bash
command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; }
curl -fsSL "https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh?$(date +%s)" | bash -s -- --update --yes
```

### Reinstalar / Reparar
```bash
command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; }
curl -fsSL "https://raw.githubusercontent.com/TelksBr/VeltrixProxy/main/install.sh?$(date +%s)" | bash -s -- --reinstall --latest --yes
```

---

## 🖥️ Menu Administrativo (`vt`)

Após a instalação, abra o console interativo do proxy executando:

```bash
vt
```
*(O atalho `main` também aponta para o menu `vt`).*

Estrutura de menus:

| Tecla | Menu | Descrição |
|:---:|:---|:---|
| **1** | **Proxy** | Portas de escuta, iniciar/parar/reiniciar serviço, logs e métricas ao vivo |
| **2** | **Xray** | Gerador de links VLESS/VMess, configurações gerais, TLS, splitHTTP e WebSocket |
| **3** | **DNSTT** | Túnel DNS na porta 53 UDP, chaves criptográficas, domínio e fallback |
| **4** | **BadVPN / UDPGW** | Motor interno integrado e faixa de portas UDP |
| **5** | **Usuários** | Conexões online em tempo real, desconectar usuários, limites e expiração |
| **6** | **Token de Licença** | Configuração e validação do token de acesso |
| **7** | **Avançado** | Transportes adicionais (SSH, BTUN, XHTTP, Ztun, HCR), otimizações de rede e `config.json` |
| **8** | **Atualizar** | Atualização do binário proxy e do menu interativo |
| **9** | **Idioma** | Português (PT) / English (EN) / Español (ES) |
| **D** | **Desinstalar** | Remoção completa e segura do VTProxy do sistema |

---

## 🔌 Integração para Painéis e Scripts

O **VTProxy** foi projetado para permitir integração total com painéis web (PHP, Node.js, Python), bots do Telegram/WhatsApp e scripts Shell/Bash sem necessidade de bibliotecas proprietárias.

O rastreamento de conexões é feito em memória e exportado de forma atômica em múltiplos formatos para garantir compatibilidade e máxima performance.

```
┌─────────────────────────────────────────────────────────────┐
│                       VTProxy Daemon                        │
│                   (Rastreamento em Memória)                 │
└──────┬──────────────────────┬────────────────────────┬──────┘
       │                      │                        │
       ▼                      ▼                        ▼
  UNIX Socket            Arquivo Texto            Arquivo JSON
 /run/proxy.sock     /run/proxy-onlines.txt   /run/proxy-onlines.json
 (IPC Ultrarrápido)   (Scripts Shell/Grep)     (Painéis Web / APIs)
```

> **Nota sobre caminhos:** Em sistemas Linux modernos, os arquivos e o socket são criados em `/run/`. Se o diretório `/run/` não estiver disponível, o proxy utiliza automaticamente `/tmp/` como fallback.

---

### 1. Leitura via Arquivo de Linhas (`proxy-onlines.txt`)

O arquivo `/run/proxy-onlines.txt` lista **um nome de usuário por linha para cada conexão ativa**. É o método mais rápido e compatível para scripts Shell tradicionais (estilo SSHPlus, DTel, Conecta4G, etc.).

Exemplo de conteúdo:
```text
alice
alice
bob
carlos
```
*(No exemplo acima: `alice` tem 2 conexões ativas, `bob` tem 1 e `carlos` tem 1).*

#### Exemplos em Shell / Bash:

- **Total de conexões ativas:**
  ```bash
  [ -f /run/proxy-onlines.txt ] && wc -l < /run/proxy-onlines.txt || echo 0
  ```

- **Quantidade de conexões de um usuário específico:**
  ```bash
  USUARIO="alice"
  [ -f /run/proxy-onlines.txt ] && grep -F -x -c "$USUARIO" /run/proxy-onlines.txt || echo 0
  ```

- **Lista de usuários únicos online:**
  ```bash
  [ -f /run/proxy-onlines.txt ] && sort -u /run/proxy-onlines.txt || true
  ```

---

### 2. Leitura via Arquivo JSON (`proxy-onlines.json`)

O arquivo `/run/proxy-onlines.json` é atualizado atomicamente pelo proxy a cada conexão e desconexão. Ele fornece um sumário pronto para consumo por linguagens de backend.

Exemplo de estrutura:
```json
{
  "total": 3,
  "users": {
    "alice": 2,
    "bob": 1
  },
  "updatedAt": "2026-10-01T05:30:00Z"
}
```

#### Exemplo em PHP:
```php
<?php
$jsonPath = '/run/proxy-onlines.json';
if (!file_exists($jsonPath)) {
    $jsonPath = '/tmp/proxy-onlines.json';
}

$data = json_decode(@file_get_contents($jsonPath), true) ?: ['total' => 0, 'users' => []];

$totalOnlines = $data['total'];
$aliceConns   = $data['users']['alice'] ?? 0;

echo "Total online: {$totalOnlines} | Alice: {$aliceConns}\n";
```

#### Exemplo em Python:
```python
import json, os

path = '/run/proxy-onlines.json' if os.path.exists('/run/proxy-onlines.json') else '/tmp/proxy-onlines.json'

try:
    with open(path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {'total': 0, 'users': {}}

print(f"Total: {data.get('total', 0)}")
print(f"Conexões do usuário bob: {data.get('users', {}).get('bob', 0)}")
```

---

### 3. Consultas Diretas via CLI (`proxy-server`)

O binário `proxy-server` oferece comandos diretos de consulta para uso em automações e cronjobs:

| Comando | Saída | Descrição |
|---|---|---|
| `proxy-server --onlines-total` | Número inteiro (ex: `42`) | Retorna apenas o total numérico de conexões ativas |
| `proxy-server --onlines-user=<usuario> --onlines-total` | Número inteiro (ex: `2`) | Retorna apenas a contagem numérica de conexões do usuário |
| `proxy-server --onlines` | Tabela formatada | Exibe lista de usuários com tempo online e detalhes dos túneis |
| `proxy-server --onlines=<usuario>` | Tabela formatada | Exibe detalhes detalhados (IP, porta, uptime) do usuário |
| `proxy-server --onlines-json` | JSON completo | Exporta JSON com total, mapa de contadores e detalhes de sessão |

---

### 4. IPC UNIX Domain Socket (`/run/proxy.sock`)

Para integrações de alta frequência (APIs REST, painéis web em tempo real, bots de alta demanda), o VTProxy oferece um **UNIX Domain Socket** de alta performance em `/run/proxy.sock`.

A comunicação é baseada em texto simples (comandos terminados em `\n`), respondendo em microssegundos sem acessar o disco:

#### Tabela de Comandos IPC:

| Comando | Resposta | Descrição |
|---|---|---|
| `GET_TOTAL\n` | `N\n` (ex: `5\n`) | Retorna a quantidade total de túneis ativos |
| `GET_USER <username>\n` | `N\n` (ex: `2\n`) | Retorna a quantidade de conexões ativas do usuário |
| `GET_USER_DETAILS <username>\n` | JSON | Objeto com uptime, IP remoto e túneis do usuário |
| `GET_SUMMARY\n` | JSON | Resumo com total e mapa `{ "usuario": qtd }` |
| `GET_SESSIONS\n` | JSON | Lista com todas as sessões ativas no servidor |
| `KILL_USER <username>\n` | `N\n` (ex: `2\n`) | Desconecta imediatamente todas as sessões do usuário |
| `KILL_EXPIRED\n` | `N\n` (ex: `1\n`) | Varre o `/etc/shadow` e encerra sessões de contas expiradas |
| `RELOAD_PASSWD\n` | `OK\n` | Recarrega instantaneamente o `/etc/passwd` (UUIDs e limites) |

#### Como consultar via linha de comando:

```bash
# Obter total de conexões
echo "GET_TOTAL" | nc -U /run/proxy.sock

# Obter conexões de um usuário específico
echo "GET_USER alice" | nc -U /run/proxy.sock

# Obter resumo JSON completo
echo "GET_SUMMARY" | nc -U /run/proxy.sock
```

---

## ⚡ Gerenciamento de Sessões (Kick e Expiração)

### Desconectar um usuário específico (Kick / Desconexão Forçada)

Ideal para botões de "Derrubar Usuário" em painéis administrativos ou encerramento de testes:

- **Via CLI:**
  ```bash
  # Desconecta o usuário e exibe mensagem
  proxy-server --kill-user=alice

  # Retorna apenas o número de conexões derrubadas (ideal para scripts)
  proxy-server --kill-user=alice --onlines-total
  ```

- **Via Socket IPC:**
  ```bash
  echo "KILL_USER alice" | nc -U /run/proxy.sock
  ```

---

### Desconectar usuários expirados ou bloqueados (`kill-expired`)

O VTProxy possui integração nativa com o `/etc/shadow`. Ao executar a verificação de expirados, contas com data vencida ou senha desativada (`!`, `*`) têm suas conexões derrubadas imediatamente:

- **Via CLI:**
  ```bash
  proxy-server --kill-expired
  ```

- **Via Socket IPC:**
  ```bash
  echo "KILL_EXPIRED" | nc -U /run/proxy.sock
  ```

- **Verificação automática em segundo plano:**
  O VTProxy já inclui um *Auto-Expire Reaper* em segundo plano configurado via `--expire-check-interval=1m` (ou através do menu `vt`).

---

## 👥 Limites e Autenticação de Usuários

### Limite de Conexões Simultâneas por Usuário

O VTProxy suporta controle atômico de limite de conexões simultâneas por usuário diretamente no campo **GECOS** do `/etc/passwd`.

Para definir um limite para uma conta Linux:
```bash
# Define limite de 2 conexões simultâneas para o usuário 'alice'
usermod -c "limit=2" alice
```

Se o usuário tentar abrir mais conexões do que o permitido em `limit=N`, o proxy rejeita a conexão excedente automaticamente.

### Contas VLESS / VMess (Xray) integradas ao Sistema

Você pode configurar o UUID do Xray para uma conta do sistema no mesmo campo GECOS:
```bash
# Configura limite de 1 conexão e associa um UUID para VLESS/VMess
usermod -c "limit=1,uuid=e3b0c442-98fc-1c14-9afb-f4c59638706d" bob
```

**Vantagem exclusiva:** O usuário `bob` terá sua validade de data e limite sincronizados no `/etc/shadow` e `/etc/passwd`. Quando a conta expirar no sistema, o acesso via VLESS/VMess também é bloqueado na hora!

### Recarregar Contas sem Reiniciar o Proxy

Sempre que seu painel adicionar ou modificar um usuário no `/etc/passwd`, envie o sinal de recarga para o proxy atualizar o cache em memória instantaneamente:

```bash
echo "RELOAD_PASSWD" | nc -U /run/proxy.sock
```

---

## 💻 Exemplos Práticos de Código

### Exemplo em Shell Script (Para Crons de Limite / Verificação)

```bash
#!/bin/bash
# script-painel-sync.sh

SOCKET="/run/proxy.sock"
ONLINE_FILE="/run/proxy-onlines.txt"

# 1. Derrubar usuários vencidos no shadow
if [ -S "$SOCKET" ]; then
    KILLED=$(echo "KILL_EXPIRED" | nc -U "$SOCKET" 2>/dev/null || echo 0)
    [ "$KILLED" -gt 0 ] && echo "Usuários expirados desconectados: $KILLED"
fi

# 2. Verificar conexões de um cliente
USER="cliente01"
if [ -f "$ONLINE_FILE" ]; then
    CONNS=$(grep -F -x -c "$USER" "$ONLINE_FILE")
    echo "O usuário $USER possui $CONNS conexões ativas."
fi
```

### Exemplo em PHP (Para Painéis Web)

```php
<?php
// Exemplo de classe utilitária para conectar ao VTProxy via UNIX Socket

class VTProxyClient {
    private $socketPath;

    public function __construct($socketPath = '/run/proxy.sock') {
        if (!file_exists($socketPath) && file_exists('/tmp/proxy.sock')) {
            $socketPath = '/tmp/proxy.sock';
        }
        $this->socketPath = $socketPath;
    }

    private function sendCommand($cmd) {
        $fp = @stream_socket_client("unix://{$this->socketPath}", $errno, $errstr, 2);
        if (!$fp) return null;
        fwrite($fp, $cmd . "\n");
        $response = trim(fgets($fp));
        fclose($fp);
        return $response;
    }

    public function getTotalOnlines() {
        return (int) $this->sendCommand("GET_TOTAL");
    }

    public function getUserOnlines($username) {
        return (int) $this->sendCommand("GET_USER {$username}");
    }

    public function killUser($username) {
        return (int) $this->sendCommand("KILL_USER {$username}");
    }

    public function reloadPasswd() {
        return $this->sendCommand("RELOAD_PASSWD") === 'OK';
    }
}

// Uso:
$vt = new VTProxyClient();
echo "Total de online agora: " . $vt->getTotalOnlines();
```

---

## 🛠️ Serviço Systemd e Logs

O instalador configura o proxy como serviço gerenciado pelo `systemd`:

- **Status do serviço:**
  ```bash
  systemctl status proxy
  ```

- **Reiniciar o serviço:**
  ```bash
  systemctl restart proxy
  ```

- **Acompanhar logs em tempo real:**
  ```bash
  journalctl -u proxy -f
  # ou pelo arquivo de log padrão:
  tail -f /var/log/proxy/proxy.log
  ```

- **Arquivo de configuração principal:**
  `/etc/proxy/config.json`

---

## 📄 Licença e Direitos

Desenvolvido por **Telks** ([@telks13](https://github.com/telks13)).  
Todos os direitos reservados. Distribuído sob licença comercial protegida.
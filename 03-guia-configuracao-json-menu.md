# Guia de Integração para o Menu: Configuração JSON & CLI do ProxyVT-Go

> **Documento de especificação técnica para refatoração do menu de gerenciamento, instalador e serviço systemd.**

---

## 1. Visão Geral da Nova Arquitetura

O **ProxyVT-Go** agora suporta configuração nativa via arquivo **JSON (`config.json`)**, eliminando a necessidade de passar dezenas de flags na linha de comando (`ExecStart` do systemd).

### Principais Características

1. **Caminho Padrão Automático**: Se iniciado sem parâmetros de arquivo, o binário procura automaticamente por `/etc/proxyvt/config.json`.
2. **Flag Explícita**: Também pode ser passado explicitamente via `--config /caminho/config.json` ou `-c /caminho/config.json`.
3. **Geração Rápida de Modelo**: O próprio binário pode gerar o modelo padrão de JSON com o comando:

   ```bash
   proxy-server --dump-config > /etc/proxyvt/config.json
   ```

4. **Precedência em Cascata**:
   * *Defaults Internos* $\to$ Sobrescritos pelo *`config.json`* $\to$ Sobrescritos por *Flags de Linha de Comando* (se fornecidas).
5. **Retrocompatibilidade**: Nenhuma flag antiga foi removida. O menu pode mesclar JSON com flags se desejar.

---

## 2. Modelo do Arquivo de Serviço Systemd

O arquivo de serviço no Linux (`/etc/systemd/system/proxyvt.service`) deve ser configurado de forma limpa e padronizada:

```ini
[Unit]
Description=ProxyVT Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/proxy-server --config /etc/proxyvt/config.json
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

---

## 3. Estrutura Completa do `config.json`

Abaixo está o modelo completo recomendado com todas as seções e valores padrão:

```json
{
  "token": "SEU_TOKEN_AQUI",
  "ports": [
    "80",
    "443:ssl"
  ],
  "log_level": "info",
  "log_file": "",
  "buffer_size": 32768,
  "max_connections": 0,
  "idle_timeout": 0,
  "write_timeout": 0,
  "cert": "",
  "cert_internal": true,
  "display_banner": true,
  "response": "VeltrixProxy",
  "ssh_only": false,
  "ulimit": 65536,

  "ssh": {
    "internal": true,
    "internal_port": 0,
    "port": 22,
    "auth": "shadow",
    "auth_file": "",
    "allow_root": true,
    "banner": "SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3"
  },

  "btun": {
    "enable": true,
    "tun": "btun0",
    "subnet": "10.77.0.0/16",
    "auth": "shadow",
    "auth_file": "/etc/btun/users",
    "udp_port": 0
  },

  "limits": {
    "default_user_limit": 0,
    "passwd_file": "/etc/passwd",
    "expire_check_interval": "1m"
  },

  "connectors": {
    "openvpn_port": 1194,
    "v2ray_port": 1080
  },

  "xhttp": {
    "path": "/ssh",
    "grace": 120,
    "idle": 120
  }
}
```

---

## 4. Dicionário Completo de Campos

### A. Seção Principal (Raiz)

| Campo | Tipo | Default | Descrição |
| :--- | :--- | :--- | :--- |
| `token` | `string` | `""` | **Obrigatório.** Token de acesso validado na API de licenciamento. |
| `ports` | `array` | `["80", "443:ssl"]` | Portas de escuta do proxy. Aceita formatos flexíveis (ver seção 5). |
| `log_level` | `string` | `"info"` | Nível de log: `"debug"`, `"info"`, `"warn"`, `"error"`. |
| `log_file` | `string` | `""` | Caminho do arquivo para salvar o banner de inicialização (opcional). |
| `buffer_size` | `int` | `32768` | Tamanho do buffer de cópia I/O em bytes (32 KB). |
| `max_connections` | `int` | `0` | Máximo de conexões simultâneas por porta (`0` = ilimitado). |
| `idle_timeout` | `int` | `0` | Timeout sem tráfego em segundos para derrubar túneis (`0` = desligado). |
| `write_timeout` | `int` | `0` | Timeout para escritas bloqueadas em segundos (`0` = desligado). |
| `cert` | `string` | `""` | Caminho para certificado TLS externo `.crt` / `.pem` (opcional). |
| `cert_internal` | `bool` | `true` | Se `true`, usa o certificado Cloudflare TLS embutido nas portas `:ssl`. |
| `display_banner`| `bool` | `true` | Exibe o banner informativo com portas e status na inicialização. |
| `response` | `string` | `"VeltrixProxy"` | Mensagem da resposta HTTP 200/101 do payload falso. |
| `ssh_only` | `bool` | `false` | Se `true`, ignora checagens de OpenVPN/V2Ray e força tudo para SSH. |
| `ulimit` | `int` | `65536` | Limite de descritores de arquivos (`RLIMIT_NOFILE`) no Linux. |

---

### B. Seção `ssh` (Servidor SSH Nativo Embutido)

> Substitui o OpenSSH externo na porta 22 por um servidor SSH nativo em Go (Zero-Fork), economizando até 98% de memória RAM e eliminando processos no Linux.

| Campo | Tipo | Default | Descrição |
| :--- | :--- | :--- | :--- |
| `internal` | `bool` | `true` | **Recomendado `true`**. Ativa o servidor SSH nativo em Go embutido no proxy. |
| `port` | `int` | `22` | Porta do SSH externo legado (usado apenas se `internal: false`). |
| `internal_port` | `int` | `0` | Porta TCP direta opcional para o SSH embutido (`0` = apenas via túnel HTTP/WS). |
| `auth` | `string` | `"shadow"` | Mecanismo de autenticação: `"shadow"` (lê `/etc/shadow`), `"file"` ou `"allow"`. |
| `auth_file` | `string` | `""` | Caminho do arquivo de senhas caso `auth` seja `"file"`. |
| `allow_root` | `bool` | `true` | Permite login com usuário `root` no SSH interno. |
| `banner` | `string` | `"SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u3"` | Identificador/Banner de versão SSH retornado ao cliente. |

---

### C. Seção `btun` (Servidor DT-Proto / UDP Nativo)

> Servidor de dispositivo TUN nativo para aplicativos DT-Proto.

| Campo | Tipo | Default | Descrição |
| :--- | :--- | :--- | :--- |
| `enable` | `bool` | `true` | Habilita o servidor BTUN nativo via dispositivo TUN. |
| `tun` | `string` | `"btun0"` | Nome da interface de rede virtual TUN criada no Linux. |
| `subnet` | `string` | `"10.77.0.0/16"` | Sub-rede IPv4 atribuída aos clientes conectados via BTUN. |
| `auth` | `string` | `"shadow"` | Mecanismo de autenticação: `"shadow"`, `"file"` ou `"allow"`. |
| `auth_file` | `string` | `"/etc/btun/users"` | Caminho do arquivo de senhas caso `auth` seja `"file"`. |
| `udp_port` | `int` | `0` | Porta UDP direta para datagramas (`0` = desativado). |

---

### D. Seção `limits` (Controle de Conexões e Expiração de Usuários)

> Controle nativo de conexões simultâneas por conta e desconexão de expirados.

| Campo | Tipo | Default | Descrição |
| :--- | :--- | :--- | :--- |
| `default_user_limit` | `int` | `0` | Limite padrão de conexões simultâneas por usuário (`0` = ilimitado). |
| `passwd_file` | `string` | `"/etc/passwd"` | Caminho do `/etc/passwd` onde os limites individuais são lidos. |
| `expire_check_interval` | `string` ou `int` | `"1m"` | Intervalo da varredura periódica e desconexão automática de usuários expirados (`"0"` para desativar). |

---

### E. Seção `connectors` (Redirecionamento para Backends Externos)

| Campo | Tipo | Default | Descrição |
| :--- | :--- | :--- | :--- |
| `openvpn_port` | `int` | `1194` | Porta local do serviço OpenVPN. |
| `v2ray_port` | `int` | `1080` | Porta local do serviço V2Ray / Xray. |

---

### F. Seção `xhttp` (Transporte HTTP com Chunking)

| Campo | Tipo | Default | Descrição |
| :--- | :--- | :--- | :--- |
| `path` | `string` | `"/ssh"` | Prefixo da URL para transporte SplitHTTP (VOID). |
| `grace` | `int` | `120` | Segundos para manter a sessão aberta após o download cair. |
| `idle` | `int` | `120` | Segundos para manter sessões ociosas sem tráfego. |

---

## 5. Flexibilidade do Formato JSON

Para que o menu/script em bash/python não quebre com facilidade, o parser aceita variações:

### Formato de Portas (`ports`)

O menu pode escrever o array de portas de 3 formas válidas:

1. **Strings com ou sem `:ssl`** (Recomendado):

   ```json
   "ports": ["80", "443:ssl", "8080"]
   ```

2. **Números puros** (todas em HTTP sem SSL):

   ```json
   "ports": [80, 8080, 8888]
   ```

3. **Objetos estruturados**:

   ```json
   "ports": [
     {"port": 80},
     {"port": 443, "ssl": true}
   ]
   ```

### Formato Plano (Flat) Alternativo

O menu pode optar por usar campos planos sem objetos aninhados, e o proxy reconhecerá normalmente:

```json
{
  "token": "MEU_TOKEN",
  "ports": ["80", "443:ssl"],
  "ssh_internal": true,
  "ssh_internal_port": 0,
  "btun_enable": true,
  "default_user_limit": 2,
  "expire_check_interval": "1m"
}
```

---

## 6. Sistema de Limite de Conexões por Usuário

### Como persistir o limite no Linux

O menu pode definir o limite de conexões simultâneas de um cliente diretamente no campo GECOS (campo 5) do `/etc/passwd`:

```text
usuario:x:1001:1001:limit=2:/home/usuario:/bin/false
```

* **Exemplos válidos**: `limit=1`, `limit=2`, `limit=5`, `Nome do Cliente,limit=2`.
* **Sem Limite (Ilimitado)**:
  * Se o `/etc/passwd` tiver `limit=0` ou **não contiver** `limit=`, o usuário terá conexões ilimitadas.
* **Comando bash para definir limite**:

  ```bash
  # Define limit=2 para o usuário 'joao'
  chfn -o "limit=2" joao
  # Ou editando diretamente o /etc/passwd com usermod
  usermod -c "limit=2" joao
  ```

### Liveness Probe de 5 Segundos (Anti-Túnel Fantasma 4G)

* **Comportamento 100% automático**: Não requer configuração extra.
* Se um cliente móvel (4G/Wi-Fi) cair repentinamente e tentar reconectar logo em seguida, o proxy realiza um ping probe (`keepalive@openssh.com`) de 5 segundos no túnel anterior.
* Se o túnel antigo não responder, o servidor encerra o túnel fantasma e autoriza a nova conexão do cliente sem dar erro de "limite atingido".
* Se o túnel antigo responder (segundo aparelho tentando usar a mesma conta), o novo login é recusado com delay de proteção (anti-flood).

---

## 7. Comandos de Linha de Comando (CLI) para o Menu

O menu pode interagir diretamente com o proxy em execução usando o binário:

### Consultar Conexões Online

```bash
# 1. Total numérico de conexões (perfeito para exibir no cabeçalho do menu)
TOTAL=$(proxy-server --onlines-total)
echo "Conexões ativas no momento: $TOTAL"

# 2. Conexões ativas de um usuário específico
USER_COUNT=$(proxy-server --onlines-user joao)
echo "O usuário joao está usando $USER_COUNT conexão(ões)"

# 3. Lista detalhada formatada para humanos
proxy-server --onlines

# 4. Lista em formato JSON para processamento via jq ou Python
proxy-server --onlines-json
```

### Desconectar Usuários (Kick / Kill Tunnel)

```bash
# Derruba imediatamente todas as conexões ativas do usuário 'joao'
proxy-server --kill-user joao

# Derruba com 1 comando todos os usuários expirados ou desativados no Linux
proxy-server --kill-expired
```

### Validar Token sem subir o servidor

```bash
proxy-server --token MEU_TOKEN --validate
if [ $? -eq 0 ]; then
    echo "Token válido!"
else
    echo "Token inválido ou expirado!"
fi
```

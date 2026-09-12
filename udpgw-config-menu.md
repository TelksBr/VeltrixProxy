# UDPGW (BadVPN) embutido — configs para o menu de controle

Brief para atualizar o menu/instalador após o udpgw nativo no `ProxyVT-Go`.

O proxy passa a tratar **BadVPN udpgw** in-process: quando o cliente SSH
(HTTP Custom, NPV, etc.) abre `direct-tcpip` para loopback na faixa
configurada (`port_min`–`port_max`, default `7100`–`7900`), o sshd interno
entrega o canal ao motor embutido — **sem** processo `udpgw` separado e
**sem** Dial em `127.0.0.1:porta` (quando `internal=true`).

Precedência: **defaults internos → `config.json` → flags CLI**.

---

## JSON canônico (usar este formato no menu)

```json
"udpgw": {
  "internal": true,
  "port_min": 7100,
  "port_max": 7900
}
```

Aliases flat também válidos: `udpgw_internal`, `udpgw_port_min`, `udpgw_port_max`.

Flags equivalentes: `--udpgw-internal`, `--udpgw-port-min`, `--udpgw-port-max`.

---

## Campos

| JSON | Tipo | Default | UI sugerida | Efeito |
| --- | --- | --- | --- | --- |
| `internal` | bool | `true` | toggle **UDPGW interno** / **BadVPN embutido** | `true` = motor in-process na faixa via SSH. `false` = sshd disca `127.0.0.1:porta` (binário VeltrixUPGW / `udpgw` externo). |
| `port_min` | int | `7100` | input numérico | Início da faixa interceptada em loopback. |
| `port_max` | int | `7900` | input numérico | Fim da faixa interceptada em loopback. |

Não há listen público, metrics nem buffers. Não inventar `udpgw.port` único nem serviço systemd embutido.

---

## Dependência do SSH interno

O intercept só funciona com **SSH interno ligado**:

```json
"ssh": {
  "internal": true
}
```

| `ssh.internal` | `udpgw.internal` | Comportamento |
| --- | --- | --- |
| `true` | `true` (default) | `direct-tcpip` loopback **port_min–port_max** → motor embutido. |
| `true` | `false` | `direct-tcpip` loopback na faixa → Dial `127.0.0.1:porta` (serviço externo). |
| `false` | qualquer | Motor udpgw **não sobe**. Quem usa OpenSSH externo continua precisando do `udpgw` separado na VPS. |

No menu: se o toggle de SSH interno estiver **off**, mostre aviso: “requer SSH nativo”.

---

## Faixa de portas (configurável)

| Campo | Default |
| --- | --- |
| `port_min` | `7100` |
| `port_max` | `7900` |

Exemplos típicos nos apps: `7300`, `7200`, `7400`. Qualquer porta na faixa
configurada em **loopback** (`127.0.0.1`, `localhost`, `::1`, `0.0.0.0`) é
interceptada.

**Não** intercepta IP público nessa faixa (ex.: `8.8.8.8:7300` continua Dial).

Não adicione a faixa em `ports[]` do proxy.

---

## O que o menu **não** deve expor

Não existem (e **não inventar**):

- `udpgw.port` / `--udpgw-port` / listen `0.0.0.0:N`
- criar serviço systemd `udpgw-7400` “porque o proxy precisa”
- métricas Prometheus do VeltrixUPGW
- `max_clients`, `map_ttl`, buffers UDP, `udp_bind`

Com `udpgw.internal=true` + `ssh.internal=true`, o usuário **pode desligar** o
binário/serviço VeltrixUPGW na VPS para esses clientes. Com `internal=false`,
mantém o daemon externo como antes.

---

## Exemplo no `config.json`

```json
{
  "token": "SEU_TOKEN",
  "ports": ["80", "443:ssl"],
  "ssh": {
    "internal": true,
    "auth": "shadow",
    "allow_root": true
  },
  "udpgw": {
    "internal": true,
    "port_min": 7100,
    "port_max": 7900
  }
}
```

Flat equivalente:

```json
{
  "ssh_internal": true,
  "udpgw_internal": true,
  "udpgw_port_min": 7100,
  "udpgw_port_max": 7900
}
```

CLI:

```bash
--ssh-internal --udpgw-internal --udpgw-port-min 7100 --udpgw-port-max 7900
# ou desligar o motor e usar o udpgw externo:
--ssh-internal --udpgw-internal=false
```

---

## Texto sugerido na UI

- **Título:** UDP Gateway (BadVPN) embutido  
- **Ajuda:** Trata UDP dos apps SSH (faixa configurável em 127.0.0.1) dentro do
  proxy, sem instalar o `udpgw` separado. Requer SSH nativo ativo.  
- **On:** motor interno (recomendado).  
- **Off:** encaminha para `127.0.0.1:<porta>` (serviço externo).
- **port_min / port_max:** inputs numéricos (default 7100 / 7900).

---

## Checklist rápido para o menu

1. Adicionar seção/toggle `udpgw.internal` (default **ligado**).
2. Adicionar `port_min` / `port_max` editáveis (defaults 7100 / 7900).
3. Remover qualquer campo de “porta única do udpgw” / listen / serviço embutido no proxy.
4. Amarrar o toggle ao SSH interno (só faz sentido se `ssh.internal=true`).
5. Não alterar `ports[]` do proxy por causa do udpgw.
6. Opcional: se `udpgw.internal=true`, sugerir ao admin que pode parar o
   `udpgw-*.service` antigo.

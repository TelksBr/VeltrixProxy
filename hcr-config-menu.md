# HCR — configs para o menu de controle

Brief para o agente do menu/instalador. Chaves aceitas pelo `ProxyVT-Go` para
o transporte **HCR** (HTTP Custom Relay / HTTP Custom). Entra nas **mesmas
portas TCP** do proxy (`80`, `443:ssl`, …) via classify (header 62 B / opcodes
`1..6`). Em portas plaintext, `transport=auto|tls` aceita ClientHello `0x16`
com cert HCR próprio.

Precedência: **defaults internos → `config.json` → flags CLI**.

---

## JSON canônico

```json
"hcr": {
  "enable": true,
  "target": "",
  "transport": "auto",
  "tls_cert": "",
  "tls_key": "",
  "tls_internal": true,
  "max_sessions": 32,
  "max_source_sessions": 0,
  "poll_timeout": 10,
  "idle": 300,
  "max_download_frame": 16384
}
```

Flags: `--hcr-enable`, `--hcr-target`, `--hcr-transport`, `--hcr-tls-cert`,
`--hcr-tls-key`, `--hcr-tls-internal`, `--hcr-max-sessions`,
`--hcr-max-source-sessions`, `--hcr-poll-timeout`, `--hcr-idle`,
`--hcr-max-download-frame`.

---

## Campos

| JSON | Tipo | Default | UI | Efeito |
| --- | --- | --- | --- | --- |
| `enable` | bool | `true` | toggle | Liga o motor HCR |
| `target` | string | `""` | input opcional | Se setado, dial TCP forçado (bypass zero-fork). Vazio = ssh-internal ou `127.0.0.1:ssh-port` |
| `transport` | string | `"auto"` | select | `plain` \| `tls` \| `auto` (sniff `0x16`) |
| `tls_cert` / `tls_key` | string | `""` | path | PEM; se ambos setados, usam arquivo |
| `tls_internal` | bool | `true` | toggle | Cert ECDSA autoassinado **só em memória** quando paths vazios |
| `max_sessions` | int | `32` | número | Limite global de sessões |
| `max_source_sessions` | int | `0` | número | Limite por IP (`0` = ilimitado) |
| `poll_timeout` | int | `10` | segundos | Timeout do ReqPoll |
| `idle` | int | `300` | segundos | Reaper de sessões ociosas |
| `max_download_frame` | int | `16384` | bytes | Tamanho máx. de frame de download |

Em `:ssl` do proxy o TLS é o do proxy; HCR não aninha segundo TLS.

---

## Update / install

O `install.sh` e o `Manager.Load` do menu **injetam** a seção `hcr` (e chaves
faltantes) em `config.json` antigos, com os defaults acima.

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
  "max_sessions": 128,
  "max_source_sessions": 128,
  "max_connections": 2048,
  "poll_timeout": 8,
  "idle": 120,
  "max_download_frame": 6144,
  "max_replay_bytes": 8388608,
  "session_stats_interval": 10
}
```

Flags: `--hcr-enable`, `--hcr-target`, `--hcr-transport`, `--hcr-tls-cert`,
`--hcr-tls-key`, `--hcr-tls-internal`, `--hcr-max-sessions`,
`--hcr-max-source-sessions`, `--hcr-max-connections`, `--hcr-poll-timeout`,
`--hcr-idle`, `--hcr-max-download-frame`, `--hcr-max-replay-bytes`,
`--hcr-session-stats-interval`.

---

## Campos

| JSON | Tipo | Default | UI | Efeito |
| --- | --- | --- | --- | --- |
| `enable` | bool | `true` | toggle | Liga o motor HCR |
| `target` | string | `""` | input opcional | Se setado, dial TCP forçado (bypass zero-fork). Vazio = ssh-internal ou `127.0.0.1:ssh-port` |
| `transport` | string | `"auto"` | select | `plain` \| `tls` \| `auto` (sniff `0x16`) |
| `tls_cert` / `tls_key` | string | `""` | path | PEM; se ambos setados, usam arquivo |
| `tls_internal` | bool | `true` | toggle | Cert ECDSA autoassinado **só em memória** quando paths vazios |
| `max_sessions` | int | `128` | número | Limite global de sessões |
| `max_source_sessions` | int | `128` | número | Limite por IP (`0` = ilimitado) |
| `max_connections` | int | `2048` | número | TCPs HCR simultâneas |
| `poll_timeout` | int | `8` | segundos | Timeout do ReqPoll |
| `idle` | int | `120` | segundos | Reaper de sessões ociosas |
| `max_download_frame` | int | `6144` | bytes | Tamanho máx. de frame de download |
| `max_replay_bytes` | int | `8388608` | bytes | Replay sem ACK antes de fechar target |
| `session_stats_interval` | int | `10` | segundos | Log `hcr session_stats` (`0` = off) |

Em `:ssl` do proxy o TLS é o do proxy; HCR não aninha segundo TLS.

---

## Update / install

O `install.sh` e o `Manager.Load` do menu **injetam** a seção `hcr` (e chaves
faltantes) em `config.json` antigos, com os defaults acima.

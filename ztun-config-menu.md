# Ztun Binary — configs para o menu de controle

Brief para o agente do menu/instalador. São **as únicas** chaves que o
`ProxyVT-Go` aceita para Ztun. Não inventar SMUX, janela, chunk, porta UDP
nem listen próprio: o Ztun entra nas **mesmas portas TCP** do proxy
(`80`, `443:ssl`, …) pelo magic `ZTM1`.

Precedência: **defaults internos → `config.json` → flags CLI**.

---

## JSON canônico (usar este formato no menu)

```json
"ztun": {
  "enable": true,
  "upstream": "",
  "auth": "shadow",
  "auth_file": "",
  "idle": 180
}
```

Alias flat também válidos (não misturar no mesmo arquivo se der para evitar):
`ztun_enable`, `ztun_upstream`, `ztun_auth`, `ztun_auth_file`, `ztun_idle`.

Flags equivalentes: `--ztun-enable`, `--ztun-upstream`, `--ztun-auth`,
`--ztun-auth-file`, `--ztun-idle`.

---

## Campos

| JSON | Tipo | Default | UI sugerida | Efeito |
| --- | --- | --- | --- | --- |
| `enable` | bool | `true` | toggle **Ztun Binary** | Motor in-process (Auth + carrier + SMUX nesta fatia). |
| `upstream` | string | `""` | input `host:port`, opcional, avançado | Se **não vazio**, desliga o motor e faz passthrough para um `ztun-tcp` externo. |
| `auth` | string | `"shadow"` | select | `shadow` \| `file` \| `allow`. |
| `auth_file` | string | `""` | path, visível se `auth=file` (opcional em `shadow`) | Arquivo `user:password`. Em `file`, vazio cai em `/etc/proxy/users`. Em `shadow`, é fallback se o user não estiver no `/etc/shadow`. |
| `idle` | int | `180` | número (segundos) | Reaper de tokens/carriers ociosos. `≤0` no binário volta para 180. |

### Auth (mesmo vocabulário do SSH/BTUN)

| Valor | Comportamento |
| --- | --- |
| `shadow` | `/etc/shadow` (aliases CLI: `system` ou vazio). |
| `file` | só o arquivo `user:password`. |
| `allow` | aceita qualquer senha (debug; aliases: `allow-insecure`, `none`). |

### `enable` vs `upstream`

- Produção: `enable=true` e `upstream=""`.
- A/B com binário Rust: preencher `upstream` (`127.0.0.1:PORTA`). O motor **não** sobe mesmo com `enable=true`.
- `enable=false` e `upstream=""`: classifica `ZTM1`, loga, **não** encaminha.

Não precisa de porta extra no `ports[]`. UDP do Ztun é no protocolo, não é campo de config.

---

## O que o menu **não** deve expor

Não existem chaves para: SMUX, `max_frame`, window, chunk, `outbound_limit`,
lanes, TFO, backlog, `max_connections` específico do Ztun. Isso é constante
do binário.

---

## Exemplo no `config.json`

```json
{
  "token": "SEU_TOKEN",
  "ports": ["80", "443:ssl"],
  "ztun": {
    "enable": true,
    "upstream": "",
    "auth": "shadow",
    "auth_file": "",
    "idle": 180
  }
}
```

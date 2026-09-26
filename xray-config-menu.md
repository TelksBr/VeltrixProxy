# Xray no menu e no instalador

Motor in-process VLESS/VMess no path único `/vtxray` (WS e SplitHTTP no
mesmo prefixo). Contas: `uuid=` no GECOS de `/etc/passwd`. Fallback
opcional: lista `clients` de um `config.json` Xray/V2Ray/3x-ui.

Precedência no proxy: **defaults internos → `config.json` → flags CLI**.

## JSON (`xray`)

```json
"xray": {
  "enable": true,
  "path": "/vtxray",
  "protocols": ["vless", "vmess"],
  "transports": ["ws", "splithttp"],
  "tls": {
    "inherit_port": true,
    "cert_file": "",
    "key_file": "",
    "cert_internal": true
  },
  "legacy": {
    "enable": true,
    "config_file": "/usr/local/etc/xray/config.json"
  }
}
```

| Campo | Default | Notas |
| --- | --- | --- |
| `enable` | `true` | Liga o motor. |
| `path` | `/vtxray` | WS no path exato; SplitHTTP = `path/{session}/{seq}`. |
| `protocols` | `vless,vmess` | |
| `transports` | `ws,splithttp` | `xhttp` no menu vira `splithttp`. |
| `tls.inherit_port` | `true` | v1 usa o TLS da porta do proxy. |
| `legacy.enable` | `true` | UUID do JSON se não estiver no passwd. |
| `legacy.config_file` | detectado ou `/usr/local/etc/xray/config.json` | |

Idle Xray **não** é exposto (desligado no motor).

## Detecção no install/update

Ordem (primeiro arquivo regular não vazio):

1. `/usr/local/etc/xray/config.json` (Xray-core / script oficial)
2. `/etc/xray/config.json`
3. `/usr/local/x-ui/bin/config.json` (3x-ui / x-ui)
4. `/usr/local/etc/v2ray/config.json`
5. `/etc/v2ray/config.json`
6. `/etc/x-ui/x-ui.json` (painel)

Se nenhum existir: cria `/usr/local/etc/xray/config.json` com inbound
VLESS `vless-in` em `0.0.0.0:443`, WS `/vtxray` e um client de exemplo.
Arquivo existente **não** é sobrescrito.

O `install.sh` e o `Manager.Load` do menu **injetam** a seção `xray`
(e chaves faltantes) em `config.json` antigos, com os defaults acima.
`legacy.enable=false` explícito é preservado.

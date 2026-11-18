# Xray no menu e no instalador

Motor in-process VLESS/VMess/Trojan no path único `/vtxray` (WS, SplitHTTP,
HTTPUpgrade, gRPC e Raw TCP). Contas: `uuid=` no GECOS de `/etc/passwd`
(Trojan autentica via SHA-224(UUID)). Fallback opcional: lista `clients` de um `config.json` Xray/V2Ray/3x-ui.

Precedência no proxy: **defaults internos → `config.json` → flags CLI**.

## JSON (`xray`)

```json
"xray": {
  "enable": true,
  "path": "/vtxray",
  "ws_path": "",
  "splithttp_path": "",
  "httpupgrade_path": "",
  "splithttp_config": "",
  "protocols": ["vless", "vmess", "trojan", "socks", "http", "shadowsocks"],
  "transports": ["ws", "splithttp", "httpupgrade", "grpc", "tcp", "mkcp", "hysteria"],
  "grpc_service": "vtxray",
  "h3": true,
  "h3_config": "",
  "udp_listen": "",
  "tcp_finalmask_listen": "",
  "tcp_finalmask_config": "",
  "kcp_listen": "",
  "kcp_tls": false,
  "kcp_cert_file": "",
  "kcp_key_file": "",
  "kcp_config": "",
  "hysteria_listen": "",
  "hysteria_config": "",
  "udp_finalmask_config": "",
  "ss2022_listen": "",
  "ss2022_method": "2022-blake3-aes-128-gcm",
  "ss2022_master_key": "",
  "masque_listen": "",
  "masque_subnet": "10.13.0.1/24",
  "masque_path": "/.well-known/masque/ip/*/*/",
  "wireguard_config": "",
  "xdrive_config": "",
  "native_config": "",
  "sync_passwd": false,
  "traffic_usage_file": "/var/lib/vtproxy/xray-traffic-usage.json",
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
| `path` | `/vtxray` | Path padrão/fallback para WS, SplitHTTP e HTTPUpgrade. |
| `ws_path` / `splithttp_path` / `httpupgrade_path` | `""` | Overrides de rota por transporte (vazio herda `path`). |
| `splithttp_config` | `""` | JSON de `splithttpSettings`; seu `path` prevalece sobre `splithttp_path`. |
| `protocols` | `vless,vmess,trojan,socks,http,shadowsocks` | Protocolos aceitos pelo motor custom. |
| `transports` | `ws,splithttp,httpupgrade,grpc,tcp,mkcp,hysteria` | Transportes suportados (`xhttp` vira `splithttp`). |
| `grpc_service` | `vtxray` | Nome do serviço gRPC Tun. |
| `h3` / `h3_config` | `true` / `""` | HTTP/3 (QUIC) para SplitHTTP nas portas TLS + `QuicParams` opcional. |
| `udp_listen` | `""` | Listener UDP dedicado para Shadowsocks AEAD (ex: `:8388`). |
| `kcp_listen` / `kcp_tls` / `kcp_cert_file` / `kcp_key_file` / `kcp_config` | `""` / `false` | Listener UDP mKCP opcional + TLS/config. |
| `hysteria_listen` / `hysteria_config` | `""` | Listener UDP Hysteria 2 QUIC opcional + `hysteriaSettings`. |
| `udp_finalmask_config` | `""` | Fragmento `StreamConfig` com `finalmask.udp` para mKCP/Hysteria. |
| `tcp_finalmask_listen` / `tcp_finalmask_config` | `""` | Listener TCP dedicado aplicando `finalmask.tcp`. |
| `ss2022_listen` / `ss2022_method` / `ss2022_master_key` | `""` / `2022-blake3-aes-128-gcm` | Listener TCP+UDP SS2022 integrado ao `/etc/passwd` (auto-ativa `sync_passwd`). |
| `masque_listen` / `masque_subnet` / `masque_path` | `""` / `10.13.0.1/24` / `/.well-known/masque/ip/*/*/` | Listener HTTP/3 MASQUE dedicado (auto-ativa `sync_passwd`). |
| `wireguard_config` / `xdrive_config` | `""` | Listeners dedicados WireGuard e VLESS/X-Drive (auto-ativam `sync_passwd`). |
| `native_config` / `sync_passwd` | `""` / `false` | Core Xray oficial adicional + sincronização de contas/cota `/etc/passwd`. |
| `traffic_usage_file` | `/var/lib/vtproxy/xray-traffic-usage.json` | Ledger persistente de cota por usuário (`traffic_limit_bytes=N` no GECOS). |
| `tls.inherit_port` | `true` | Usa o TLS da porta do proxy. |
| `legacy.enable` / `legacy.config_file` | `true` / detectado | UUID do JSON se não estiver no passwd. |

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

## Gerar link (tela inicial → 2 Xray → 1 Gerar link)

Fluxo do wizard:

1. **Proxy** — sempre primeiro; vai no `@` do link (VMess `add`)
2. **VLESS ou VMess**
3. **TLS ou Direct** — TLS pede SNI; Direct **não** inclui SNI
4. **Porta**
5. **Host do servidor** — domínio que aponta para a VPS; vai em `host=`
   (VMess `host`). Obrigatório.
6. **SNI** (só TLS) — `serverName` do handshake (VMess `sni`, VLESS `sni=`).
   Enter repete o host do servidor; precisa ser domínio, não IP.

Exemplo Direct (proxy `104.18.7.41`, host `bhttp.sshproject.com`):

```
vless://UUID@104.18.7.41:80?type=ws&security=none&host=bhttp.sshproject.com&path=%2Fvtxray
```
7. **Gerar com pcs? (s/N)** — só no TLS. Se sim, consulta
   `https://xray.nulled.pp.ua/api/fingerprint?domain=<host do servidor>`
   (sempre o host, nunca o proxy nem o SNI; host IP não gera pcs) e inclui
   o SHA-256 do certificado: VLESS
   `pcs=<hex>`, VMess campo `"pcs"`. Se a API falhar, pergunta se gera
   sem pcs.
8. Path = `xray.path` (não se digita)
9. UUID = fixo `8fc81ef3-0156-4888-a89d-4520c38d7a3a` (não se configura)

Se a porta escolhida **não** estiver em `ports` do proxy, o menu gera o
link e só avisa (informativo).

No link do cliente o transporte é **`xhttp`** (nunca `SplitHTTP`): VLESS
`type=xhttp`, VMess v2 `net=xhttp`. VLESS é URI padrão; VMess é
`vmess://` + JSON v2 (`aid=0`).

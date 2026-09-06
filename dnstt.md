# Pacote `dnstt`

> Caminho: `src/dnstt/`  
> Arquivos-fonte: `server.go`, `conn.go`, `fallback.go`, `keys.go`, subpacotes `dns/`, `noise/`, `turbotunnel/`

O pacote `dnstt` implementa o servidor **DNS Tunneling (DNSTT)** integrado nativamente ao VTProxy. Ele escuta em UDP (geralmente porta 53 ou 5300), decodifica consultas DNS do tipo `TXT` contendo pacotes KCP encodificados em Base32, descriptografa o canal com a cifra `Noise_NK_25519_ChaChaPoly_BLAKE2s`, multiplexa fluxos com `smux` e despacha cada stream diretamente como `net.Conn` para a esteira de sessões do VTProxy (com suporte a SSH, HTTP Injectors, DTProto, OpenVPN e V2Ray).

Ele também inclui o **`FallbackManager`**, que encaminha pacotes UDP não-DNS que chegam à mesma porta para um serviço UDP local secundário (via NAT reverso), e utilitários para geração de chaves criptográficas (`--dnstt-gen-key`).

---

## Tipos e Estruturas Principais

### `Config` (`server.go`)

```go
type Config struct {
    Domain       string
    ListenUDP    string
    Privkey      []byte
    FallbackAddr string
    UpstreamAddr string
    MTU          int
    Handler      func(conn net.Conn)
}
```

Configuração de inicialização do servidor DNSTT.

- `Domain`: Domínio raiz da zona DNS reservada para o túnel (ex.: `t.exemplo.com`).
- `ListenUDP`: Endereço/porta UDP de escuta (padrão `:53`).
- `Privkey`: Chave privada de 32 bytes (Curve25519).
- `FallbackAddr`: Endereço UDP opcional para onde pacotes não-DNS são roteados (ex.: `127.0.0.1:8888`).
- `UpstreamAddr`: Endereço TCP opcional. Se vazio, utiliza `Handler` em memória.
- `MTU`: Tamanho máximo do payload de resposta DNS (padrão `1232`).
- `Handler`: Callback executado para cada stream aceita do túnel.

### `Server` (`server.go`)

```go
type Server struct { /* ... */ }
```

Instância ativa do servidor DNSTT.

- `func NewServer(cfg Config) (*Server, error)`: Inicializa o socket UDP, KCP, Turbotunnel e as goroutines de leitura/escrita e sessão.
- `func (s *Server) LocalAddr() net.Addr`: Retorna o endereço UDP local associado.
- `func (s *Server) Pubkey() string`: Retorna a chave pública em hexadecimal (64 caracteres).
- `func (s *Server) Close() error`: Encerra o listener UDP, listener KCP e todas as filas de forma graciosa.

### `StreamConn` (`conn.go`)

```go
type StreamConn struct {
    *smux.Stream
    local  net.Addr
    remote net.Addr
}
```

Adaptador que expõe o `*smux.Stream` como uma implementação completa de `net.Conn`.
Implementa a interface `earlyProber` (`CanProbeEarly() bool { return true }`), permitindo que a sessão transparente do VTProxy sonde os primeiros bytes do cliente ou envie o banner SSH com antecipação.

### `FallbackManager` (`fallback.go`)

```go
type FallbackManager struct {
    sessions     *ttlcache.Cache[UDPAddrKey, net.PacketConn]
    mainConn     net.PacketConn
    fallbackAddr net.Addr
}
```

Gerenciador de NAT UDP para tráfego não-DNS na porta de escuta do DNSTT.

- `func NewFallbackManager(mainConn net.PacketConn, fallbackAddr net.Addr) *FallbackManager`
- `func (m *FallbackManager) HandlePacket(packet []byte, clientAddr net.Addr)`: Identifica ou cria um socket UDP efêmero para a sessão do cliente e faz proxy bidirecional com `fallbackAddr`.
- `func (m *FallbackManager) Close()`: Limpa o cache TTL e encerra as conexões de proxy ativas.

---

## Funções de Chaves (`keys.go`)

- `func GenerateKeypair(privkeyFilename, pubkeyFilename string) (privkey, pubkey []byte, err error)`: Gera um par de chaves Noise Curve25519 de 32 bytes e opcionalmente salva em arquivos.
- `func ReadKeyFromFile(filename string) ([]byte, error)`: Lê uma chave em formato hexadecimal de um arquivo.
- `func DecodeKey(hexStr string) ([]byte, error)`: Converte uma string hexadecimal de 64 dígitos em 32 bytes.
- `func PubkeyHex(privkey []byte) string`: Deriva a chave pública a partir da chave privada e retorna em hexadecimal.

---

## Subpacotes

### `dns/` (`dns.go`)
Parser de wire format RFC 1035 e RFC 6891 (EDNS0). Constrói mensagens de resposta `TXT` e `OPT` e calcula o MTU dinâmico admissível para o túnel.

### `noise/` (`noise.go`)
Implementa o protocolo `Noise_NK_25519_ChaChaPoly_BLAKE2s` sobre streams com prefixo de tamanho de 16 bits. Criptografa dados em trânsito com ChaCha20-Poly1305 autenticado pela chave pública do servidor.

### `turbotunnel/` (`queuepacketconn.go`, `clientid.go`, `remotemap.go`)
Camada de multiplexação virtual de pacotes. Mapeia clientes por `ClientID` (8 bytes) e cria uma interface `net.PacketConn` sobre a qual o KCP opera de forma contínua.

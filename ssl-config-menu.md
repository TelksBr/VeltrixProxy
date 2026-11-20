# Certificados grátis no menu VT

O menu e o proxy devem ser atualizados juntos. A entrada **Proxy → S** e a opção
**SSL grátis / Let's Encrypt** no submenu TLS chamam o gerenciador nativo do
ProxyVT; o menu não armazena nem transporta chaves privadas.

O fluxo verifica DNS e rota local na porta 80, oferece staging e só seleciona
`ssl.domain` depois que o proxy devolve um certificado de produção válido.
A comprovação do domínio é feita pelo desafio externo do Let's Encrypt.
HTTP-01 exige TCP 80 publicamente acessível e não suporta wildcard.

Schema persistido, com compatibilidade para configurações antigas:

```json
"ssl": {
  "domain": "proxy.exemplo.com",
  "state_dir": "/var/lib/vtproxy/certificates",
  "auto_renew": true
}
```

Omitir `auto_renew` ativa a renovação por padrão. Domínio vazio deixa o modo
legado. Escolher um certificado externo limpa a seleção gerenciada; desativar
o domínio volta ao certificado interno e preserva os arquivos ACME.

A seleção inicial e mudanças de configuração exigem reiniciar ao sair do menu.
Renovações posteriores são feitas pelo daemon sem o menu aberto. É necessário
manter o proxy ativo e a porta 80 acessível; não há agendador externo nesta
entrega. O cadastro não cria uma porta TLS automaticamente.

TLS comum, HCR herdado, H3 e FinalMask TLS recarregam em novos handshakes.
mKCP TLS herdado, Hysteria e MASQUE dedicados recarregam pelo Xray-core em até
uma hora. Certificados explícitos HCR/mKCP e JSON Xray nativo externo continuam
independentes. Links de clientes com fingerprint/PCS podem exigir atualização
após renovar.

As ações `--ssl-action check|issue|renew|status` retornam JSON. O menu verifica
código de saída e conteúdo, recusando respostas de binários antigos ou emissão
staging como sucesso de produção. Configurações SSL sobrevivem ao `vt --migrate`.
O instalador preserva as chaves existentes do JSON e `/var/lib/vtproxy`; a
desinstalação completa já remove esse diretório, incluindo os certificados.

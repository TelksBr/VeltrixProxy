package system

import (
	"path/filepath"
	"testing"
)

func TestDNSTTKeys(t *testing.T) {
	privHex, pubHex, err := GenerateDNSTTKeypair()
	if err != nil {
		t.Fatalf("erro ao gerar par de chaves DNSTT: %v", err)
	}

	if len(privHex) != 64 {
		t.Fatalf("esperado privHex de 64 caracteres, obtido %d", len(privHex))
	}
	if len(pubHex) != 64 {
		t.Fatalf("esperado pubHex de 64 caracteres, obtido %d", len(pubHex))
	}

	derivedPub, err := PubkeyFromPrivkeyHex(privHex)
	if err != nil {
		t.Fatalf("falha ao derivar pubkey de privHex: %v", err)
	}
	if derivedPub != pubHex {
		t.Fatalf("pubkey derivada (%s) diferente da gerada (%s)", derivedPub, pubHex)
	}

	// Teste com chave inválida
	if _, err := PubkeyFromPrivkeyHex("invalid_hex_string"); err == nil {
		t.Fatalf("esperado erro para chave hexadecimal inválida")
	}
	if _, err := PubkeyFromPrivkeyHex("1234"); err == nil {
		t.Fatalf("esperado erro para chave com tamanho diferente de 64")
	}
}

func TestSaveAndReadPrivateKey(t *testing.T) {
	tempDir := t.TempDir()
	keyFile := filepath.Join(tempDir, "dnstt", "server.key")

	privHex, pubHex, err := GenerateDNSTTKeypair()
	if err != nil {
		t.Fatalf("erro ao gerar chave: %v", err)
	}

	if err := SavePrivateKeyToFile(privHex, keyFile); err != nil {
		t.Fatalf("falha ao salvar chave: %v", err)
	}

	loadedPriv, err := ReadPrivateKeyFromFile(keyFile)
	if err != nil {
		t.Fatalf("falha ao ler chave salva: %v", err)
	}
	if loadedPriv != privHex {
		t.Fatalf("chave lida (%s) diferente da original (%s)", loadedPriv, privHex)
	}

	// Teste LoadOrCreateDNSTTKeys
	p, pub, created, err := LoadOrCreateDNSTTKeys("", keyFile)
	if err != nil || created {
		t.Fatalf("deveria ter carregado a chave existente sem criar nova: %v", err)
	}
	if p != privHex || pub != pubHex {
		t.Fatalf("chaves carregadas incorretas")
	}
}

package system

import (
	"crypto/ecdh"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	DefaultDNSTTKeyFile = "/etc/dnstt/server.key"
)

// GenerateDNSTTKeypair gera um novo par de chaves Curve25519 (32 bytes) para o protocolo Noise do DNSTT.
// Retorna a chave privada e a chave pública em formato hexadecimal de 64 caracteres.
func GenerateDNSTTKeypair() (privHex string, pubHex string, err error) {
	curve := ecdh.X25519()
	priv, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		return "", "", fmt.Errorf("falha ao gerar chave X25519: %w", err)
	}

	privHex = hex.EncodeToString(priv.Bytes())
	pubHex = hex.EncodeToString(priv.PublicKey().Bytes())
	return privHex, pubHex, nil
}

// PubkeyFromPrivkeyHex deriva a chave pública Curve25519 (64 hex) a partir de uma chave privada (64 hex).
func PubkeyFromPrivkeyHex(privHex string) (string, error) {
	clean := strings.TrimSpace(privHex)
	if len(clean) != 64 {
		return "", fmt.Errorf("a chave privada deve ter exatamente 64 caracteres hexadecimais (obtido %d)", len(clean))
	}

	privBytes, err := hex.DecodeString(clean)
	if err != nil {
		return "", fmt.Errorf("chave privada contém caracteres hexadecimais inválidos: %w", err)
	}

	curve := ecdh.X25519()
	priv, err := curve.NewPrivateKey(privBytes)
	if err != nil {
		return "", fmt.Errorf("chave privada Curve25519 inválida: %w", err)
	}

	return hex.EncodeToString(priv.PublicKey().Bytes()), nil
}

// DerivePubkeyFilePath deriva o caminho do arquivo de chave pública (.pub) a partir do caminho da chave privada.
func DerivePubkeyFilePath(privkeyFile string) string {
	clean := strings.TrimSpace(privkeyFile)
	if clean == "" {
		return ""
	}
	ext := filepath.Ext(clean)
	if ext != "" {
		return strings.TrimSuffix(clean, ext) + ".pub"
	}
	return clean + ".pub"
}

// SavePublicKeyToFile salva a chave pública em formato hexadecimal no arquivo especificado, com permissão 0644.
func SavePublicKeyToFile(pubHex string, filePath string) error {
	clean := strings.TrimSpace(pubHex)
	if len(clean) != 64 {
		return fmt.Errorf("a chave pública deve ter exatamente 64 caracteres hexadecimais (obtido %d)", len(clean))
	}

	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("falha ao criar diretório %s: %w", dir, err)
	}

	data := []byte(clean + "\n")
	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return fmt.Errorf("falha ao gravar chave pública em %s: %w", filePath, err)
	}

	return nil
}

// SavePrivateKeyToFile salva a chave privada em formato hexadecimal no arquivo especificado, com permissão 0600.
func SavePrivateKeyToFile(privHex string, filePath string) error {
	clean := strings.TrimSpace(privHex)
	if _, err := PubkeyFromPrivkeyHex(clean); err != nil {
		return err
	}

	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("falha ao criar diretório %s: %w", dir, err)
	}

	data := []byte(clean + "\n")
	if err := os.WriteFile(filePath, data, 0600); err != nil {
		return fmt.Errorf("falha ao gravar chave privada em %s: %w", filePath, err)
	}

	return nil
}

// ReadPrivateKeyFromFile lê uma chave privada hexadecimal de um arquivo.
func ReadPrivateKeyFromFile(filePath string) (string, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("falha ao ler arquivo de chave %s: %w", filePath, err)
	}

	clean := strings.TrimSpace(string(data))
	if _, err := PubkeyFromPrivkeyHex(clean); err != nil {
		return "", fmt.Errorf("conteúdo de %s inválido: %w", filePath, err)
	}

	return clean, nil
}

// LoadOrCreateDNSTTKeys obtém o par de chaves ativo (privada/pública) baseado na configuração.
// Se uma chave já estiver definida ou salva em arquivo, a carrega e deriva a chave pública.
// Se não existir nenhuma chave, gera um novo par e opcionalmente o salva em privkeyFile.
func LoadOrCreateDNSTTKeys(privkeyHex string, privkeyFile string) (privHex string, pubHex string, created bool, err error) {
	// 1. Tenta carregar privkeyHex diretamente se fornecida
	if strings.TrimSpace(privkeyHex) != "" {
		pub, err := PubkeyFromPrivkeyHex(privkeyHex)
		if err == nil {
			if privkeyFile != "" {
				if pubPath := DerivePubkeyFilePath(privkeyFile); pubPath != "" {
					_ = SavePublicKeyToFile(pub, pubPath)
				}
			}
			return strings.TrimSpace(privkeyHex), pub, false, nil
		}
	}

	// 2. Tenta ler do arquivo se especificado e existente
	if privkeyFile != "" {
		if _, statErr := os.Stat(privkeyFile); statErr == nil {
			keyFromFile, err := ReadPrivateKeyFromFile(privkeyFile)
			if err == nil {
				pub, errPub := PubkeyFromPrivkeyHex(keyFromFile)
				if errPub == nil {
					if pubPath := DerivePubkeyFilePath(privkeyFile); pubPath != "" {
						_ = SavePublicKeyToFile(pub, pubPath)
					}
					return keyFromFile, pub, false, nil
				}
			}
		}
	}

	// 3. Nenhuma chave encontrada: gera novo par
	newPriv, newPub, err := GenerateDNSTTKeypair()
	if err != nil {
		return "", "", false, err
	}

	// Salva em arquivo se privkeyFile foi definido
	if privkeyFile != "" {
		_ = SavePrivateKeyToFile(newPriv, privkeyFile)
		if pubPath := DerivePubkeyFilePath(privkeyFile); pubPath != "" {
			_ = SavePublicKeyToFile(newPub, pubPath)
		}
	}

	return newPriv, newPub, true, nil
}

package system

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestUUIDHelpers(t *testing.T) {
	uuid := GenerateUUIDv4()
	if len(uuid) != 36 {
		t.Fatalf("esperado tamanho 36, obtido %d (%s)", len(uuid), uuid)
	}

	norm, ok := NormalizeUUID(uuid)
	if !ok || norm != strings.ToLower(uuid) {
		t.Fatalf("NormalizeUUID falhou para canônico: %s", uuid)
	}

	rawHex := strings.ReplaceAll(uuid, "-", "")
	norm2, ok2 := NormalizeUUID(rawHex)
	if !ok2 || norm2 != norm {
		t.Fatalf("NormalizeUUID falhou para hex 32: %s", rawHex)
	}

	if _, ok := NormalizeUUID("invalido"); ok {
		t.Fatalf("NormalizeUUID deveria falhar para string inválida")
	}
}

func TestGeneratePassword(t *testing.T) {
	pass := GenerateSecurePassword(12)
	if len(pass) != 12 {
		t.Fatalf("esperado 12 caracteres, obtido %d", len(pass))
	}
}

func TestIsValidUsername(t *testing.T) {
	valid := []string{"cliente01", "user_ssh", "joao-vpn", "ora4c"}
	for _, u := range valid {
		if !IsValidUsername(u) {
			t.Errorf("esperado username válido para '%s'", u)
		}
	}

	invalid := []string{"", "a", "root", "nobody", "daemon", "123user", "UserWithCaps", "user@special!"}
	for _, u := range invalid {
		if IsValidUsername(u) {
			t.Errorf("esperado username inválido para '%s'", u)
		}
	}
}

func TestGecosHelpers(t *testing.T) {
	gecos1 := "limit=2,uuid=550e8400-e29b-41d4-a716-446655440000"
	lim, ok := ParseLimitFromGecos(gecos1)
	if !ok || lim != 2 {
		t.Fatalf("ParseLimitFromGecos falhou: %d, %v", lim, ok)
	}
	id, ok := ParseUUIDFromGecos(gecos1)
	if !ok || id != "550e8400-e29b-41d4-a716-446655440000" {
		t.Fatalf("ParseUUIDFromGecos falhou: %s, %v", id, ok)
	}

	// Invertido
	gecos2 := "uuid=550e8400-e29b-41d4-a716-446655440000,limit=5"
	lim2, ok2 := ParseLimitFromGecos(gecos2)
	if !ok2 || lim2 != 5 {
		t.Fatalf("ParseLimitFromGecos falhou inverso: %d, %v", lim2, ok2)
	}
	id2, ok2 := ParseUUIDFromGecos(gecos2)
	if !ok2 || id2 != "550e8400-e29b-41d4-a716-446655440000" {
		t.Fatalf("ParseUUIDFromGecos falhou inverso: %s, %v", id2, ok2)
	}

	// Sem uuid
	gecos3 := "limit=3"
	lim3, ok3 := ParseLimitFromGecos(gecos3)
	if !ok3 || lim3 != 3 {
		t.Fatalf("ParseLimitFromGecos falhou sem uuid: %d, %v", lim3, ok3)
	}
	if _, ok := ParseUUIDFromGecos(gecos3); ok {
		t.Fatalf("ParseUUIDFromGecos deveria falhar para gecos sem uuid")
	}

	// BuildGecos
	b1 := BuildGecos(3, "550e8400-e29b-41d4-a716-446655440000")
	if b1 != "limit=3,uuid=550e8400-e29b-41d4-a716-446655440000" {
		t.Fatalf("BuildGecos falhou: %s", b1)
	}
	b2 := BuildGecos(0, "550e8400-e29b-41d4-a716-446655440000")
	if b2 != "uuid=550e8400-e29b-41d4-a716-446655440000" {
		t.Fatalf("BuildGecos falhou apenas uuid: %s", b2)
	}
	b3 := BuildGecos(5, "")
	if b3 != "limit=5" {
		t.Fatalf("BuildGecos falhou apenas limit: %s", b3)
	}
}

func TestAccountManagerMock(t *testing.T) {
	tmpDir := t.TempDir()
	passwdPath := filepath.Join(tmpDir, "passwd")
	shadowPath := filepath.Join(tmpDir, "shadow")

	nowDays := time.Now().Unix() / 86400

	passwdContent := `root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
cliente01:x:1001:1001:limit=2,uuid=550e8400-e29b-41d4-a716-446655440000:/home/cliente01:/bin/false
cliente02:x:1002:1002:limit=1:/home/cliente02:/bin/false
bloqueado:x:1003:1003:limit=3:/home/bloqueado:/bin/false
expirado:x:1004:1004:limit=1,uuid=c7e2b8a0-9c1d-4e2b-a3d1-8f5b4e3c2a10:/home/expirado:/bin/false
`

	validHash := "$6$saltsalt$validpasswordhashthatislongenoughforlinuxshadow"
	shadowContent := "root:*:19000:0:99999:7:::\n" +
		"nobody:*:19000:0:99999:7:::\n" +
		"cliente01:" + validHash + ":19000:0:99999:7::" + strconv.FormatInt(nowDays+30, 10) + "::\n" +
		"cliente02:" + validHash + ":19000:0:99999:7:::\n" +
		"bloqueado:!" + validHash + ":19000:0:99999:7:::\n" +
		"expirado:" + validHash + ":19000:0:99999:7::1000::\n"
	// Obs: 1000 em dias é ano 1972, logo já expirou
	_ = os.WriteFile(passwdPath, []byte(passwdContent), 0644)
	_ = os.WriteFile(shadowPath, []byte(shadowContent), 0644)

	mgr := NewAccountManager(passwdPath, shadowPath)

	accounts, err := mgr.ListAccounts()
	if err != nil {
		t.Fatalf("ListAccounts erro: %v", err)
	}

	if len(accounts) != 4 {
		t.Fatalf("esperado 4 contas de proxy, obtido %d", len(accounts))
	}

	acc1, err := mgr.GetAccount("cliente01")
	if err != nil {
		t.Fatalf("GetAccount cliente01 erro: %v", err)
	}
	if !acc1.HasUUID || acc1.UUID != "550e8400-e29b-41d4-a716-446655440000" {
		t.Fatalf("cliente01 deveria ter UUID válido: %+v", acc1)
	}
	if acc1.Limit != 2 {
		t.Fatalf("cliente01 limit deveria ser 2: %d", acc1.Limit)
	}
	if acc1.Status != StatusActive {
		t.Fatalf("cliente01 status deveria ser active, obtido %s", acc1.Status)
	}

	acc2, err := mgr.GetAccount("cliente02")
	if err != nil {
		t.Fatalf("GetAccount cliente02 erro: %v", err)
	}
	if acc2.HasUUID {
		t.Fatalf("cliente02 não deveria ter UUID: %+v", acc2)
	}
	if acc2.DaysLeft != -999 {
		t.Fatalf("cliente02 deveria ter DaysLeft=-999 (ilimitado), obtido %d", acc2.DaysLeft)
	}

	accLock, err := mgr.GetAccount("bloqueado")
	if err != nil || accLock.Status != StatusLocked {
		t.Fatalf("bloqueado deveria ter status locked, obtido: %+v", accLock)
	}

	accExp, err := mgr.GetAccount("expirado")
	if err != nil || accExp.Status != StatusExpired {
		t.Fatalf("expirado deveria ter status expired, obtido: %+v", accExp)
	}
}

func TestAccountOperationsMock(t *testing.T) {
	tmpDir := t.TempDir()
	passwdPath := filepath.Join(tmpDir, "passwd")
	shadowPath := filepath.Join(tmpDir, "shadow")

	_ = os.WriteFile(passwdPath, []byte("cliente01:x:1001:1001:limit=2:/home/cliente01:/bin/false\n"), 0644)
	_ = os.WriteFile(shadowPath, []byte("cliente01:$6$salt$hash:19000:0:99999:7:::\n"), 0644)

	var lastCommands [][]string
	mgr := NewAccountManager(passwdPath, shadowPath)
	mgr.Runner = func(name string, args ...string) ([]byte, error) {
		cmd := append([]string{name}, args...)
		lastCommands = append(lastCommands, cmd)
		return []byte("success"), nil
	}
	mgr.StdinRunner = func(stdin, name string, args ...string) ([]byte, error) {
		cmd := append([]string{name}, args...)
		lastCommands = append(lastCommands, cmd)
		return []byte("success"), nil
	}

	// Test UpdateLimit
	if err := mgr.UpdateLimit("cliente01", 5); err != nil {
		t.Fatalf("UpdateLimit erro: %v", err)
	}
	foundUsermod := false
	for _, cmd := range lastCommands {
		if cmd[0] == "usermod" && cmd[1] == "-c" && cmd[2] == "limit=5" && cmd[3] == "cliente01" {
			foundUsermod = true
		}
	}
	if !foundUsermod {
		t.Fatalf("usermod não foi executado corretamente: %+v", lastCommands)
	}

	// Test SetUUID
	newUUID := "c7e2b8a0-9c1d-4e2b-a3d1-8f5b4e3c2a10"
	if err := mgr.SetUUID("cliente01", newUUID); err != nil {
		t.Fatalf("SetUUID erro: %v", err)
	}

	// Test LockAccount
	if err := mgr.LockAccount("cliente01"); err != nil {
		t.Fatalf("LockAccount erro: %v", err)
	}

	// Test DeleteAccount
	if err := mgr.DeleteAccount("cliente01"); err != nil {
		t.Fatalf("DeleteAccount erro: %v", err)
	}
}

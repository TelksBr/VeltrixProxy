package i18n

import "testing"

func TestTranslation(t *testing.T) {
	_ = SetLanguage(LangPT)
	if T("app_title") != "GERENCIADOR VELTRIX PROXY" {
		t.Fatalf("tradução PT incorreta")
	}

	_ = SetLanguage(LangEN)
	if T("app_title") != "VELTRIX PROXY MANAGER" {
		t.Fatalf("tradução EN incorreta")
	}

	_ = SetLanguage(LangES)
	if T("app_title") != "ADMINISTRADOR VELTRIX PROXY" {
		t.Fatalf("tradução ES incorreta")
	}

	// Reset para PT
	_ = SetLanguage(LangPT)
}

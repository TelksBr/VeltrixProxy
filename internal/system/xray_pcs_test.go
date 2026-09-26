package system

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func withPCSAPI(t *testing.T, h http.HandlerFunc) {
	t.Helper()
	srv := httptest.NewServer(h)
	prev := XrayPCSAPIURL
	XrayPCSAPIURL = srv.URL
	t.Cleanup(func() {
		XrayPCSAPIURL = prev
		srv.Close()
	})
}

func TestFetchXrayPCSOK(t *testing.T) {
	const pcs = "017e53a24035a56ef5a7688d92526a3907c396f8643163a4df5e4204be141e4e"
	withPCSAPI(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("domain") != "webportals.cachefly.net" {
			t.Errorf("domain: %s", r.URL.RawQuery)
		}
		_, _ = w.Write([]byte(`{"domain":"webportals.cachefly.net","fingerprint":"` + pcs + `","pcs":"` + strings.ToUpper(pcs) + `","validTo":"21/12/2026"}`))
	})
	res, err := FetchXrayPCS(context.Background(), "webportals.cachefly.net:443")
	if err != nil {
		t.Fatal(err)
	}
	if res.PCS != pcs || res.ValidTo != "21/12/2026" {
		t.Fatalf("res: %+v", res)
	}
}

func TestFetchXrayPCSError(t *testing.T) {
	withPCSAPI(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
		_, _ = w.Write([]byte(`{"error":"Não foi possível obter o fingerprint SHA-256."}`))
	})
	_, err := FetchXrayPCS(context.Background(), "nao-existe.invalid")
	if err == nil || !strings.Contains(err.Error(), "fingerprint") {
		t.Fatalf("err: %v", err)
	}
	if _, err := FetchXrayPCS(context.Background(), " "); err == nil {
		t.Fatal("domínio vazio deveria falhar")
	}
}

func TestXrayPCSDomain(t *testing.T) {
	cases := []struct{ host, sni, want string }{
		{"cdn.example.com", "sni.example.com", "cdn.example.com"},
		{"1.2.3.4", "sni.example.com", "sni.example.com"},
		{"[2001:db8::1]:443", "sni.example.com", "sni.example.com"},
		{"cdn.example.com:8443", "", "cdn.example.com"},
	}
	for _, c := range cases {
		if got := XrayPCSDomain(c.host, c.sni); got != c.want {
			t.Fatalf("XrayPCSDomain(%q,%q)=%q want %q", c.host, c.sni, got, c.want)
		}
	}
}

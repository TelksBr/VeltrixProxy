package system

import (
	"errors"
	"strings"
	"testing"
)

func TestCertificateCommandDecoding(t *testing.T) {
	result, err := decodeCertificateResult([]byte("log startup\n{\"certificate\":{\"domain\":\"example.com\",\"not_after\":\"2027-01-01T00:00:00Z\"},\"changed\":true}\n"), "", "issue", nil)
	if err != nil || result.Certificate.Domain != "example.com" || !result.Changed {
		t.Fatalf("%+v %v", result, err)
	}
	status, err := decodeCertificateResult([]byte(`{"domain":"example.com","fingerprint":"abc"}`), "", "status", nil)
	if err != nil || status.Certificate.Fingerprint != "abc" {
		t.Fatalf("%+v %v", status, err)
	}
	for _, tc := range []struct {
		data, action string
		commandErr   error
	}{
		{`{"error":"domain validation failed"}`, "issue", errors.New("exit 1")},
		{`{"http01_ready":false}`, "check", nil},
		{`{"level":"info"}`, "issue", nil},
		{"unknown flag --ssl-action", "issue", errors.New("exit 2")},
	} {
		if _, err := decodeCertificateResult([]byte(tc.data), "", tc.action, tc.commandErr); err == nil {
			t.Fatalf("accepted invalid command: %s", tc.data)
		}
	}
	if _, err := decodeCertificateResult([]byte(`{"error":"CAA rejected"}`), "", "issue", errors.New("exit 1")); err == nil || !strings.Contains(err.Error(), "CAA rejected") {
		t.Fatal("lost CA diagnostic", err)
	}
}

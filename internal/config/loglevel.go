package config

import "strings"

// CanonicalLogLevels lists supported log levels from most verbose to quietest.
var CanonicalLogLevels = []string{"trace", "debug", "info", "warn", "error", "silent"}

// NormalizeLogLevel maps aliases to the canonical JSON value used by the proxy.
// Empty string aliases to "info" (proxy behavior); unknown values are lowercased as-is.
func NormalizeLogLevel(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", "info":
		return "info"
	case "trace", "verbose":
		return "trace"
	case "debug":
		return "debug"
	case "warn", "warning":
		return "warn"
	case "error":
		return "error"
	case "silent", "off", "none":
		return "silent"
	default:
		return strings.ToLower(strings.TrimSpace(raw))
	}
}

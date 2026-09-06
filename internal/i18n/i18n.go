package i18n

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

type Language string

const (
	LangPT Language = "pt"
	LangEN Language = "en"
	LangES Language = "es"
)

var (
	mu          sync.RWMutex
	currentLang = LangPT
	langFile    = "/etc/vtproxy/language"
)

func init() {
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		// Fallback se não tiver acesso a /etc
		if _, err := os.Stat(langFile); os.IsNotExist(err) {
			userLangFile := filepath.Join(home, ".vt_lang")
			if _, err := os.Stat(userLangFile); err == nil {
				langFile = userLangFile
			}
		}
	}
	LoadSavedLanguage()
}

// LoadSavedLanguage carrega o idioma gravado em disco
func LoadSavedLanguage() Language {
	mu.Lock()
	defer mu.Unlock()

	data, err := os.ReadFile(langFile)
	if err == nil {
		lang := strings.TrimSpace(strings.ToLower(string(data)))
		switch lang {
		case "en", "english":
			currentLang = LangEN
		case "es", "espanol", "español":
			currentLang = LangES
		default:
			currentLang = LangPT
		}
	}
	return currentLang
}

// SetLanguage define o idioma atual e salva em disco
func SetLanguage(lang Language) error {
	mu.Lock()
	defer mu.Unlock()

	switch lang {
	case LangEN, LangES:
		currentLang = lang
	default:
		currentLang = LangPT
	}

	dir := filepath.Dir(langFile)
	_ = os.MkdirAll(dir, 0755)
	return os.WriteFile(langFile, []byte(string(currentLang)+"\n"), 0644)
}

// CurrentLanguage retorna o idioma selecionado
func CurrentLanguage() Language {
	mu.RLock()
	defer mu.RUnlock()
	return currentLang
}

// T retorna a tradução para a chave no idioma atual
func T(key string, args ...interface{}) string {
	mu.RLock()
	lang := currentLang
	mu.RUnlock()

	var dict map[string]string
	switch lang {
	case LangEN:
		dict = dictEN
	case LangES:
		dict = dictES
	default:
		dict = dictPT
	}

	val, ok := dict[key]
	if !ok {
		// Fallback para português
		val, ok = dictPT[key]
		if !ok {
			val = key
		}
	}

	if len(args) > 0 {
		return fmt.Sprintf(val, args...)
	}
	return val
}

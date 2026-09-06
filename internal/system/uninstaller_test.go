package system

import (
	"testing"
)

func TestGetUninstallSteps(t *testing.T) {
	steps := GetUninstallSteps()
	if len(steps) == 0 {
		t.Fatalf("Esperado ao menos 1 passo de desinstalação, obteve 0")
	}

	for i, step := range steps {
		if step.Name == "" {
			t.Errorf("Passo %d sem nome definido", i)
		}
		if step.Description == "" {
			t.Errorf("Passo %d (%s) sem descrição definida", i, step.Name)
		}
		if step.Action == nil {
			t.Errorf("Passo %d (%s) sem action definida", i, step.Name)
		}
	}
}

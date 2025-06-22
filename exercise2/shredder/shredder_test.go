package shredder

import (
	"os"
	"path/filepath"
	"testing"
)

func createTempFile(t *testing.T, content string) string {
	t.Helper()

	tempDir := t.TempDir()
	tempFile := filepath.Join(tempDir, "testfile.txt")

	err := os.WriteFile(tempFile, []byte(content), 0644)
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}

	return tempFile
}

func TestShred(t *testing.T) {
	originalContent := "This is a test file"
	tempFile := createTempFile(t, originalContent)
	err := Shred(tempFile, 1, false)
	if err != nil {
		t.Errorf("Shred failed on valid file: %v", err)
	}

	shreddedContent, err := os.ReadFile(tempFile)
	if originalContent == string(shreddedContent) {
		t.Errorf("File content still the same after shredding: %s", string(shreddedContent))
	} else {
		t.Logf("File successfully shredded")
	}

	if len(originalContent) == len(shreddedContent) {
		t.Logf("Same file size after shredding")
	} else {
		t.Errorf("File size changed after shredding")
	}

	_ = os.Remove(tempFile)

}

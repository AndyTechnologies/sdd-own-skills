package retro

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveBodyFromFlag(t *testing.T) {
	body, err := resolveBody("hello world", "")
	if err != nil {
		t.Fatal(err)
	}
	if body != "hello world" {
		t.Fatalf("got %q, want %q", body, "hello world")
	}
}

func TestResolveBodyFromFile(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "body.md")
	os.WriteFile(f, []byte("from file"), 0o644)
	body, err := resolveBody("", f)
	if err != nil {
		t.Fatal(err)
	}
	if body != "from file" {
		t.Fatalf("got %q, want %q", body, "from file")
	}
}

func TestResolveBodyMissing(t *testing.T) {
	_, err := resolveBody("", "")
	if err == nil {
		t.Fatal("expected error when both body and body-file are empty")
	}
}

func TestNoneStorePersist(t *testing.T) {
	s, err := NewStore("none")
	if err != nil {
		t.Fatal(err)
	}
	err = s.Persist("test-change", "verify", "body text", "")
	if err != nil {
		t.Fatal(err)
	}
}

func TestNoneStoreLookup(t *testing.T) {
	s, err := NewStore("none")
	if err != nil {
		t.Fatal(err)
	}
	p, err := s.Lookup("", false)
	if err != nil {
		t.Fatal(err)
	}
	if p.Count != 0 {
		t.Fatalf("expected 0 retros, got %d", p.Count)
	}
}

func TestInvalidMode(t *testing.T) {
	_, err := NewStore("bogus")
	if err == nil {
		t.Fatal("expected error for invalid mode")
	}
}

func TestPrecisText(t *testing.T) {
	p := &Precis{
		Count: 2,
		Retros: []RetroEntry{
			{Change: "foo", Body: "line1\nline2", Lines: 2, Source: "openspec"},
			{Change: "bar", Body: "body here", Lines: 1, Source: "engram"},
		},
	}
	text := p.Text()
	if text == "" {
		t.Fatal("expected non-empty text")
	}
	if !contains(text, "Retrospectives (2)") {
		t.Fatalf("expected count header, got: %s", text)
	}
}

func TestExtractChangeFromTopic(t *testing.T) {
	got := extractChangeFromTopic("sdd/my-change/retrospective")
	if got != "my-change" {
		t.Fatalf("got %q, want %q", got, "my-change")
	}
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || len(s) > 0 && containsSubstr(s, sub))
}

func containsSubstr(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

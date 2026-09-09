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

func TestStripDatePrefix(t *testing.T) {
	cases := []struct{ in, want string }{
		{"2026-09-09-test-x", "test-x"},
		{"test-x", "test-x"},
		{"2026-01-01-foo", "foo"},
		{"my-change-name", "my-change-name"},
		{"x", "x"},
	}
	for _, c := range cases {
		if got := stripDatePrefix(c.in); got != c.want {
			t.Errorf("stripDatePrefix(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestExtractChangeFromPathActive(t *testing.T) {
	base := filepath.Join("openspec", "changes")
	path := filepath.Join(base, "test-x", "retrospective.md")
	if got := extractChangeFromPath(path, base); got != "test-x" {
		t.Fatalf("active path: got %q, want %q", got, "test-x")
	}
}

func TestExtractChangeFromPathArchiveSinglePart(t *testing.T) {
	// Archive scan: baseDir = openspec/changes/archive, rel = 1 part
	// ("2026-09-09-test-x") — must normalize to "test-x".
	base := filepath.Join("openspec", "changes", "archive")
	path := filepath.Join(base, "2026-09-09-test-x", "retrospective.md")
	if got := extractChangeFromPath(path, base); got != "test-x" {
		t.Fatalf("archive 1-part path: got %q, want %q", got, "test-x")
	}
}

func TestExtractChangeFromPathArchiveTwoPart(t *testing.T) {
	// Active scan walking into archive: baseDir = openspec/changes, rel = 2
	// parts ("archive/2026-09-09-test-x") — must normalize to "test-x".
	base := filepath.Join("openspec", "changes")
	path := filepath.Join(base, "archive", "2026-09-09-test-x", "retrospective.md")
	if got := extractChangeFromPath(path, base); got != "test-x" {
		t.Fatalf("archive 2-part path: got %q, want %q", got, "test-x")
	}
}

func TestScanDirSkipsArchiveSubdirAndDedupes(t *testing.T) {
	root := t.TempDir()
	changes := filepath.Join(root, "openspec", "changes")
	archive := filepath.Join(changes, "archive")
	if err := os.MkdirAll(filepath.Join(changes, "my-change"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(archive, "2026-09-09-my-change"), 0o755); err != nil {
		t.Fatal(err)
	}
	body := []byte("## What Worked\n\nAll good.\n")
	if err := os.WriteFile(filepath.Join(changes, "my-change", "retrospective.md"), body, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(archive, "2026-09-09-my-change", "retrospective.md"), body, 0o644); err != nil {
		t.Fatal(err)
	}

	// Active scan must NOT see the archived retro (no double match).
	active := scanDir(changes, "", "openspec")
	if len(active) != 1 {
		t.Fatalf("active scan: got %d entries, want 1 (archive subdir must be skipped)", len(active))
	}
	if active[0].change != "my-change" {
		t.Fatalf("active scan: change %q, want %q", active[0].change, "my-change")
	}

	// Archive scan finds the archived retro with the date prefix stripped.
	archived := scanDir(archive, "", "openspec")
	if len(archived) != 1 {
		t.Fatalf("archive scan: got %d entries, want 1", len(archived))
	}
	if archived[0].change != "my-change" {
		t.Fatalf("archive scan: change %q, want %q", archived[0].change, "my-change")
	}

	// Change-filtered lookup resolves the archived retro.
	filtered := scanDir(archive, "my-change", "openspec")
	if len(filtered) != 1 || filtered[0].change != "my-change" {
		t.Fatalf("archive change-filtered: got %d entries %+v, want exactly my-change", len(filtered), filtered)
	}

	// Combined precis: active + archived retros for the same change dedupe to ONE.
	precis := buildPrecis(append(active, archived...), false)
	if precis.Count != 1 {
		t.Fatalf("dedupe: precis count %d, want 1", precis.Count)
	}
	if precis.Retros[0].Change != "my-change" {
		t.Fatalf("dedupe: change %q, want %q", precis.Retros[0].Change, "my-change")
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

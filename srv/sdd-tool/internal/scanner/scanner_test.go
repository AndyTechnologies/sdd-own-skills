package scanner

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// fakeCmd produces a shell script that prints the JSON given in body.
func fakeCmd(t *testing.T, body string) string {
	t.Helper()
	dir := t.TempDir()
	script := filepath.Join(dir, "fake-status")
	content := "#!/usr/bin/env bash\nprintf '%s' '" + body + "'"
	if err := os.WriteFile(script, []byte(content), 0o755); err != nil {
		t.Fatal(err)
	}
	return script
}

func TestSnapshotParsesOnce(t *testing.T) {
	// A counter that appends to a file; the second call would change JSON.
	dir := t.TempDir()
	marker := filepath.Join(dir, "count")
	script := filepath.Join(dir, "fake-status")
	user := strings.ReplaceAll(t.TempDir(), "\\", "/")
	content := `#!/usr/bin/env bash
cat >> ` + marker + ` <<'EOF'
x
EOF
printf '%s' '{"artifactStore":"openspec","changes":[{"name":"demo","status":"spec","nextRecommended":"design","blockedReasons":[],"artifactPaths":["/tmp/demo"]}]}'`

	if err := os.WriteFile(script, []byte(content), 0o755); err != nil {
		t.Fatal(err)
	}
	_ = user
	_ = marker

	s := New(script)
	s.Snapshot() // first
	s.Snapshot() // second — must NOT re-invoke
	data, _ := os.ReadFile(marker)
	if got := strings.Count(string(data), "x"); got != 1 {
		t.Fatalf("command invoked %d times, want 1 (cached snapshot)", got)
	}
}

func TestSnapshotParseFailure(t *testing.T) {
	script := fakeCmd(t, "{not-json")
	s := New(script)
	st, err := s.Snapshot()
	if err == nil {
		t.Fatal("expected parse failure error, got nil")
	}
	if st != nil {
		t.Fatalf("expected nil status on failure, got %+v", st)
	}
}

func TestSnapshotCommandFailure(t *testing.T) {
	s := New("/nonexistent/definitely-not-a-binary 2>&1")
	st, err := s.Snapshot()
	if err == nil {
		t.Fatal("expected command failure error, got nil")
	}
	if st != nil {
		t.Fatalf("expected nil status on failure, got %+v", st)
	}
}

func TestSnapshotData(t *testing.T) {
	script := fakeCmd(t, `{"artifactStore":"openspec","changes":[{"name":"a","status":"design","nextRecommended":"tasks","blockedReasons":["x"],"artifactPaths":["/a"]}]}`)
	s := New(script)
	st, err := s.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if st.ArtifactStore != "openspec" {
		t.Fatalf("artifactStore = %q, want openspec", st.ArtifactStore)
	}
	if len(st.Changes) != 1 || st.Changes[0].Name != "a" {
		t.Fatalf("changes = %+v, want one named a", st.Changes)
	}
}

func TestSplitCommand(t *testing.T) {
	got := splitCommand(`gentle-ai sdd-status --json`)
	if len(got) != 3 {
		t.Fatalf("split = %v, want 3 parts", got)
	}
}

package worktree

import (
	"os"
	"path/filepath"
	"testing"
)

// buildTree creates <base>/<path>/.git as a directory marker and returns
// base's absolute path.
func buildDirMarker(t *testing.T, base, path string) string {
	t.Helper()
	dir := filepath.Join(base, path)
	if err := os.MkdirAll(filepath.Join(dir, ".git"), 0o755); err != nil {
		t.Fatal(err)
	}
	return dir
}

// buildWorktreeMarker creates <base>/<repo>/.git/worktrees/<name> as the
// directory structure and <base>/<repo>/worktrees/<name>/.git as the
// worktree marker file pointing at it. Returns the worktree dir.
func buildWorktreeMarker(t *testing.T, base, repo, name string) string {
	t.Helper()
	repoDir := filepath.Join(base, repo)
	gitdir := filepath.Join(repoDir, ".git", "worktrees", name)
	if err := os.MkdirAll(gitdir, 0o755); err != nil {
		t.Fatal(err)
	}
	wtDir := filepath.Join(base, repo, "worktrees", name)
	if err := os.MkdirAll(wtDir, 0o755); err != nil {
		t.Fatal(err)
	}
	content := "gitdir: " + gitdir + "\n"
	if err := os.WriteFile(filepath.Join(wtDir, ".git"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	return wtDir
}

func TestRepoRootFromWalksUpToDirMarker(t *testing.T) {
	base := t.TempDir()
	root := buildDirMarker(t, base, "repo")
	sub := filepath.Join(root, "src", "pkg")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	if got := repoRootFrom(sub); got != root {
		t.Fatalf("repoRootFrom(%s) = %q, want %q", sub, got, root)
	}
}

func TestRepoRootFromWorktreeFileMarker(t *testing.T) {
	base := t.TempDir()
	wt := buildWorktreeMarker(t, base, "repo", "feat-x")
	sub := filepath.Join(wt, "nested")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	if got := repoRootFrom(sub); got != wt {
		t.Fatalf("repoRootFrom(%s) = %q, want %q", sub, got, wt)
	}
}

func TestRepoRootFromNoMarker(t *testing.T) {
	base := t.TempDir()
	if got := repoRootFrom(base); got != "" {
		t.Fatalf("expected no root for markerless dir, got %q", got)
	}
}

func TestRepoNameFromDirMarker(t *testing.T) {
	base := t.TempDir()
	buildDirMarker(t, base, "my-repo")
	sub := filepath.Join(base, "my-repo", "deep")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	if got := repoNameFrom(sub); got != "my-repo" {
		t.Fatalf("repoNameFrom = %q, want %q", got, "my-repo")
	}
}

func TestRepoNameFromWorktreeResolvesParentRepo(t *testing.T) {
	base := t.TempDir()
	wt := buildWorktreeMarker(t, base, "my-repo", "feat-x")
	got := repoNameFrom(wt)
	if got != "my-repo" {
		t.Fatalf("repoNameFrom(worktree) = %q, want %q (parent repo basename)", got, "my-repo")
	}
}

func TestRepoNameFromDegenerateFallsBackToRepo(t *testing.T) {
	base := t.TempDir()
	if got := repoNameFrom(base); got != "repo" {
		t.Fatalf("repoNameFrom(markerless) = %q, want %q", got, "repo")
	}
	// A .git file with a malformed gitdir line must not panic or guess.
	bad := filepath.Join(base, "bad")
	if err := os.MkdirAll(bad, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(bad, ".git"), []byte("not-a-gitdir\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := repoNameFrom(bad); got != "repo" {
		t.Fatalf("repoNameFrom(malformed gitdir) = %q, want %q", got, "repo")
	}
}

// The following tests exercise the exported cwd-based API while tests run
// inside the repository checkout: the walk-up root must contain a .git
// marker, and the repo name must resolve to this repository's name (both in
// a main checkout and, via gitdir resolution, inside a feature worktree).
func TestRepoRootFromCwdInsideRepo(t *testing.T) {
	root := RepoRootFromCwd()
	if root == "" {
		t.Fatal("expected a non-empty walk-up root")
	}
	if _, err := os.Stat(filepath.Join(root, ".git")); err != nil {
		t.Fatalf("expected .git marker under root %q: %v", root, err)
	}
}

func TestRepoNameFromCwdInsideRepo(t *testing.T) {
	name := RepoNameFromCwd()
	if name == "" || name == "repo" || name == "." {
		t.Fatalf("expected the real repo name, got %q", name)
	}
}

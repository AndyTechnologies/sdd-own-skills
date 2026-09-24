package worktree

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// repoNameForTest is the derived namespace for this repository's convention
// backend (~/.agent_worktrees/<name>). Tests run from inside the repo, so
// RepoNameFromCwd() resolves to its basename.
const repoNameForTest = "sdd-own-skills"

// buildCanonicalWorktree materializes a canonical ODD worktree:
//
//	<home>/.agent_worktrees/<ns>/<name>/        the checkout root
//	<repoRoot>/.git/worktrees/<name>/HEAD       the gitdir (canonical suffix)
//	odd/tasks/<name>.md at the root (optional)
//
// Returns the worktree path.
func buildCanonicalWorktree(t *testing.T, home, repoRoot, ns, name, branch string, taskDoc bool) string {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(repoRoot, ".git"), 0o755); err != nil {
		t.Fatal(err)
	}
	wt := filepath.Join(home, ".agent_worktrees", ns, name)
	if err := os.MkdirAll(wt, 0o755); err != nil {
		t.Fatal(err)
	}
	gitdir := filepath.Join(repoRoot, ".git", "worktrees", name)
	if err := os.MkdirAll(gitdir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(gitdir, "HEAD"), []byte("ref: refs/heads/"+branch+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(wt, ".git"), []byte("gitdir: "+gitdir+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if taskDoc {
		doc := filepath.Join(wt, "odd", "tasks", name+".md")
		if err := os.MkdirAll(filepath.Dir(doc), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(doc, []byte("# task\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return wt
}

// ---- List ----

func TestListEmptyIsNonNilAndZero(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	if err := os.MkdirAll(filepath.Join(home, ".agent_worktrees", repoNameForTest), 0o755); err != nil {
		t.Fatal(err)
	}
	got := List()
	if got == nil {
		t.Fatal("expected non-nil empty slice so JSON marshals as []")
	}
	if len(got) != 0 {
		t.Fatalf("expected no entries, got %d", len(got))
	}
}

func TestListEnumeratesEntriesWithFlags(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	base := filepath.Join(home, ".agent_worktrees", repoNameForTest)
	if err := os.MkdirAll(base, 0o755); err != nil {
		t.Fatal(err)
	}
	repoRoot := filepath.Join(t.TempDir(), "src")
	// canonical worktree: all flags true, branch read from gitdir HEAD
	buildCanonicalWorktree(t, home, repoRoot, repoNameForTest, "c1", "feat/c1", true)
	// bare directory: validation flags false, branch empty, still listed
	if err := os.MkdirAll(filepath.Join(base, "c2"), 0o755); err != nil {
		t.Fatal(err)
	}
	// hidden entries are skipped
	if err := os.MkdirAll(filepath.Join(base, ".hidden"), 0o755); err != nil {
		t.Fatal(err)
	}

	got := List()
	if len(got) != 2 {
		t.Fatalf("expected 2 entries (c1, c2), got %d: %+v", len(got), got)
	}
	byName := map[string]Entry{}
	for _, e := range got {
		byName[e.Name] = e
	}
	c1, ok := byName["c1"]
	if !ok {
		t.Fatal("missing entry c1")
	}
	if !c1.RepoRootOK || !c1.TaskDocOK || c1.Branch != "feat/c1" {
		t.Fatalf("c1 expected canonical flags (root+taskdoc ok, branch feat/c1), got %+v", c1)
	}
	if c1.Path != filepath.Join(base, "c1") {
		t.Fatalf("c1 unexpected path %q", c1.Path)
	}
	c2, ok := byName["c2"]
	if !ok {
		t.Fatal("missing entry c2")
	}
	if c2.RepoRootOK || c2.TaskDocOK || c2.Branch != "" {
		t.Fatalf("c2 expected bare flags (all false, no branch), got %+v", c2)
	}
}

// ---- Verify ----

func TestVerifyRequiresFeature(t *testing.T) {
	if _, err := verifyAt("", "."); err == nil {
		t.Fatal("expected error for empty feature")
	}
}

func TestVerifyRootBlocksOutsideConventionWorktree(t *testing.T) {
	base := t.TempDir()
	repo := filepath.Join(base, "app")
	if err := os.MkdirAll(filepath.Join(repo, ".git"), 0o755); err != nil {
		t.Fatal(err)
	}
	res, err := verifyAt("feat-x", repo)
	if err != nil {
		t.Fatal(err)
	}
	if res.Pass {
		t.Fatal("expected overall FAIL outside convention worktree")
	}
	if res.Root.Pass {
		t.Fatalf("expected root signal to FAIL (walk-up root %q is not the convention root), got %+v", repo, res.Root)
	}
	if res.TaskDoc.Pass || res.Branch.Pass {
		t.Fatal("expected task_doc and branch signals to FAIL (no convention root)")
	}
}

func TestVerifyPassesOnConventionWorktree(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	repoRoot := filepath.Join(t.TempDir(), "repo")
	wt := buildCanonicalWorktree(t, home, repoRoot, "repo", "feat-x", "feat/feat-x", true)

	res, err := verifyAt("feat-x", wt)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Pass {
		t.Fatalf("expected PASS, got %+v", res)
	}
	if !res.Root.Pass || !res.TaskDoc.Pass || !res.Branch.Pass {
		t.Fatalf("expected all signals PASS, got root=%+v task_doc=%+v branch=%+v", res.Root, res.TaskDoc, res.Branch)
	}
}

func TestVerifyTaskDocBlocks(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	repoRoot := filepath.Join(t.TempDir(), "repo")
	// no odd/tasks/feat-x.md → task doc signal must BLOCK overall
	wt := buildCanonicalWorktree(t, home, repoRoot, "repo", "feat-x", "feat/feat-x", false)

	res, err := verifyAt("feat-x", wt)
	if err != nil {
		t.Fatal(err)
	}
	if res.Pass {
		t.Fatal("expected overall FAIL: task doc missing is BLOCKING")
	}
	if !res.Root.Pass {
		t.Fatalf("expected root PASS, got %+v", res.Root)
	}
	if res.TaskDoc.Pass {
		t.Fatalf("expected task_doc FAIL, got %+v", res.TaskDoc)
	}
}

func TestVerifyBranchInformativeNeverGates(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	repoRoot := filepath.Join(t.TempDir(), "repo")
	// wrong branch (other-branch instead of feat/feat-x) but task doc present
	wt := buildCanonicalWorktree(t, home, repoRoot, "repo", "feat-x", "other-branch", true)

	res, err := verifyAt("feat-x", wt)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Pass {
		t.Fatalf("expected PASS despite wrong branch: branch is INFORMATIVE only, got %+v", res)
	}
	if !res.Root.Pass || !res.TaskDoc.Pass {
		t.Fatalf("expected root+task_doc PASS, got root=%+v task_doc=%+v", res.Root, res.TaskDoc)
	}
	if res.Branch.Pass {
		t.Fatalf("expected branch FAIL (report-only), got %+v", res.Branch)
	}
	if !strings.Contains(res.Branch.Message, "(informative)") {
		t.Fatalf("expected branch message to mark informative, got %q", res.Branch.Message)
	}
}

// ---- presentation ----

func TestPassStr(t *testing.T) {
	if passStr(true) != "[PASS]" || passStr(false) != "[FAIL]" {
		t.Fatal("passStr must render [PASS]/[FAIL]")
	}
}

func TestVerifyResultText(t *testing.T) {
	r := VerifyResult{
		Pass:    true,
		Root:    Signal{Name: "root", Pass: true, Message: "ok"},
		TaskDoc: Signal{Name: "task_doc", Pass: true, Message: "ok"},
		Branch:  Signal{Name: "branch", Pass: false, Message: "informative"},
	}
	text := r.Text()
	for _, want := range []string{"Worktree verify: [PASS]", "1. Root:", "2. Task doc:", "3. Branch:", "(informative)"} {
		if !strings.Contains(text, want) {
			t.Fatalf("Text() missing %q:\n%s", want, text)
		}
	}
}

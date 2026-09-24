package worktree

import (
	"os"
	"path/filepath"
	"testing"
)

// repoNameForTest is the worktree namespace List() derives from the cwd's
// git root while tests run inside the repository checkout.
const repoNameForTest = "sdd-own-skills"

func TestListEmpty(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	trees := List()
	if len(trees) != 0 {
		t.Fatalf("expected 0 trees, got %d", len(trees))
	}
}

func TestListEnumeratesDirectories(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	base := filepath.Join(home, ".agent_worktrees", repoNameForTest)
	for _, name := range []string{"alice", "bob"} {
		if err := os.MkdirAll(filepath.Join(base, name), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	trees := List()
	if len(trees) != 2 {
		t.Fatalf("expected 2 trees, got %d", len(trees))
	}
	got := map[string]string{}
	for _, tr := range trees {
		got[filepath.Base(tr.Path)] = tr.Branch
	}
	if got["alice"] != "sdd/alice" || got["bob"] != "sdd/bob" {
		t.Fatalf("unexpected entries: %#v", got)
	}
}

func TestListSkipsHiddenEntries(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	base := filepath.Join(home, ".agent_worktrees", repoNameForTest)
	for _, name := range []string{"alice", ".hidden"} {
		if err := os.MkdirAll(filepath.Join(base, name), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	trees := List()
	if len(trees) != 1 {
		t.Fatalf("expected 1 tree (hidden skipped), got %d", len(trees))
	}
}

func TestVerifyBranchFailureAndMainNote(t *testing.T) {
	// Signal 2 (branch) fails whenever the current branch is not sdd/<change>;
	// on main/master it additionally reports the "no worktree" note. Both
	// invariants hold regardless of the branch the tests run under.
	result, err := Verify("", "")
	if err != nil {
		t.Fatal(err)
	}
	if result.Branch.Pass {
		t.Fatal("expected branch signal to fail when not on sdd/<change>")
	}
	branch, err := gitBranch()
	if err != nil {
		t.Fatal(err)
	}
	if (branch == "main" || branch == "master") && result.Note != "no worktree" {
		t.Fatalf("expected 'no worktree' note on main, got %q", result.Note)
	}
}

func TestPassStr(t *testing.T) {
	if passStr(true) != "[PASS]" {
		t.Fatal("expected [PASS]")
	}
	if passStr(false) != "[FAIL]" {
		t.Fatal("expected [FAIL]")
	}
}

func TestVerifyResultText(t *testing.T) {
	r := VerifyResult{
		Pass:   false,
		Root:   Signal{Name: "root", Pass: true, Message: "matched"},
		Branch: Signal{Name: "branch", Pass: false, Message: "got main, expected sdd/x"},
		Dirty:  false,
		Note:   "no worktree",
	}
	text := r.Text()
	if text == "" {
		t.Fatal("expected non-empty text")
	}
}
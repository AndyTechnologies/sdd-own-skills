package worktree

import (
	"testing"

	"sdd-tool/internal/scanner"
)

func TestListEmpty(t *testing.T) {
	snap := &scanner.Status{Changes: nil}
	trees := List(snap)
	if len(trees) != 0 {
		t.Fatalf("expected 0 trees, got %d", len(trees))
	}
}

func TestListNil(t *testing.T) {
	trees := List(nil)
	if len(trees) != 0 {
		t.Fatalf("expected 0 trees for nil, got %d", len(trees))
	}
}

func TestVerifyOnMain(t *testing.T) {
	// When on main branch, verify should fail signal 2 with "no worktree"
	snap := &scanner.Status{
		Changes: []*scanner.Change{
			{Name: "test", Status: "design", NextRecommended: "tasks"},
		},
	}
	result, err := Verify(snap, "", "")
	if err != nil {
		t.Fatal(err)
	}
	// On main, signal 2 (branch) should fail
	if result.Branch.Pass {
		t.Fatal("expected branch signal to fail on main")
	}
	if result.Note != "no worktree" {
		t.Fatalf("expected 'no worktree' note, got %q", result.Note)
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
		Scanner: Signal{Name: "scanner", Pass: true, Message: "parsed OK"},
		Dirty:  false,
		Note:   "no worktree",
	}
	text := r.Text()
	if text == "" {
		t.Fatal("expected non-empty text")
	}
}

// Package worktree provides worktree listing and verification against
// convention paths under ~/.agent_worktrees/<repo>/<change>.
//
// Verify checks three binding signals: root, branch, and scanner.
// Dirty-state disclosure ignores .codegraph/ and .sdd-agent-lock.
// The tool never auto-clears dirty trees — the human decides.
package worktree

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"sdd-tool/internal/scanner"
)

// Worktree represents a listed worktree.
type Worktree struct {
	Path   string `json:"path"`
	Branch string `json:"branch"`
}

// VerifyResult holds the outcome of a worktree verify check.
type VerifyResult struct {
	Pass    bool   `json:"pass"`
	Root    Signal `json:"root"`
	Branch  Signal `json:"branch"`
	Scanner Signal `json:"scanner"`
	Dirty   bool   `json:"dirty"`
	Note    string `json:"note,omitempty"`
}

// Signal represents one verify signal's status.
type Signal struct {
	Name    string `json:"name"`
	Pass    bool   `json:"pass"`
	Message string `json:"message,omitempty"`
}

// Text returns a human-readable representation of the verify result.
func (r VerifyResult) Text() string {
	var b strings.Builder
	fmt.Fprintf(&b, "Worktree verify: %s\n", passStr(r.Pass))
	fmt.Fprintf(&b, "  1. Root:    %s  %s\n", passStr(r.Root.Pass), r.Root.Message)
	fmt.Fprintf(&b, "  2. Branch:  %s  %s\n", passStr(r.Branch.Pass), r.Branch.Message)
	fmt.Fprintf(&b, "  3. Scanner: %s  %s\n", passStr(r.Scanner.Pass), r.Scanner.Message)
	if r.Dirty {
		fmt.Fprintf(&b, "  Dirty: yes (not cleared — human decides)\n")
	}
	if r.Note != "" {
		fmt.Fprintf(&b, "  Note: %s\n", r.Note)
	}
	return b.String()
}

func passStr(ok bool) string {
	if ok {
		return "[PASS]"
	}
	return "[FAIL]"
}

// List enumerates worktrees under ~/.agent_worktrees/<repo>/<change>
// by inspecting each scanner change entry for a convention path. The repo
// namespace is derived dynamically from the current working directory's git
// root (RepoNameFromGitRoot) — never hardcoded.
func List(snap *scanner.Status) []Worktree {
	var trees []Worktree
	if snap == nil {
		return trees
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return trees
	}
	repoName := RepoNameFromGitRoot(cwd())
	for _, ch := range snap.Changes {
		path := filepath.Join(home, ".agent_worktrees", repoName, ch.Name)
		if info, err := os.Stat(path); err == nil && info.IsDir() {
			branch := "sdd/" + ch.Name
			trees = append(trees, Worktree{Path: path, Branch: branch})
		}
	}
	return trees
}

func cwd() string {
	cwd, err := os.Getwd()
	if err != nil {
		return "."
	}
	return cwd
}

// Verify checks three binding signals for a worktree.
// changeName: if empty, taken from cwd path convention.
// expectedRoot: if empty, taken from cwd.
func Verify(snap *scanner.Status, changeName, expectedRoot string) (VerifyResult, error) {
	cwd, _ := os.Getwd()
	if expectedRoot == "" {
		expectedRoot = cwd
	}

	result := VerifyResult{Pass: true}

	// Signal 1: git rev-parse --show-toplevel == expected root
	root, err := gitRoot()
	if err != nil {
		result.Root = Signal{Name: "root", Pass: false, Message: fmt.Sprintf("git root failed: %v", err)}
		result.Pass = false
	} else {
		match := normalisePath(root) == normalisePath(expectedRoot)
		result.Root = Signal{
			Name:    "root",
			Pass:    match,
			Message: fmt.Sprintf("got %s, expected %s", root, expectedRoot),
		}
		if !match {
			result.Pass = false
		}
	}

	// Signal 2: git branch --show-current == sdd/<change>
	branch, err := gitBranch()
	if err != nil {
		result.Branch = Signal{Name: "branch", Pass: false, Message: fmt.Sprintf("git branch failed: %v", err)}
		result.Pass = false
	} else {
		expectedBranch := "sdd/" + changeName
		if changeName == "" {
			// Try to infer from path or scanner
			if snap != nil && len(snap.Changes) > 0 {
				expectedBranch = "sdd/" + snap.Changes[0].Name
			}
		}
		isMain := branch == "main" || branch == "master"
		match := branch == expectedBranch
		result.Branch = Signal{
			Name:    "branch",
			Pass:    match,
			Message: fmt.Sprintf("got %s, expected %s", branch, expectedBranch),
		}
		if !match {
			result.Pass = false
			if isMain {
				result.Note = "no worktree"
			}
		}
	}

	// Signal 3: scanner JSON parses
	if snap == nil {
		result.Scanner = Signal{Name: "scanner", Pass: false, Message: "scanner unavailable"}
		result.Pass = false
	} else {
		result.Scanner = Signal{Name: "scanner", Pass: true, Message: "parsed OK"}
	}

	// Dirty-state disclosure (ignoring .codegraph/ and .sdd-agent-lock)
	if result.Pass {
		result.Dirty = isDirty()
	}

	return result, nil
}

func gitRoot() (string, error) {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s: %w", strings.TrimSpace(string(out)), err)
	}
	return strings.TrimSpace(string(out)), nil
}

func gitBranch() (string, error) {
	out, err := exec.Command("git", "branch", "--show-current").CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s: %w", strings.TrimSpace(string(out)), err)
	}
	return strings.TrimSpace(string(out)), nil
}

func isDirty() bool {
	// git status --porcelain, ignoring .codegraph/ and .sdd-agent-lock
	out, err := exec.Command("git", "status", "--porcelain").CombinedOutput()
	if err != nil {
		return false
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		path := strings.TrimSpace(line[3:])
		if strings.HasPrefix(path, ".codegraph/") || path == ".sdd-agent-lock" {
			continue
		}
		return true
	}
	return false
}

func normalisePath(p string) string {
	p = filepath.Clean(p)
	// Resolve ~ if present
	if strings.HasPrefix(p, "~") {
		home, _ := os.UserHomeDir()
		p = filepath.Join(home, p[1:])
	}
	return p
}

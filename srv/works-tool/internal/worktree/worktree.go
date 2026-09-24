// Package worktree provides worktree listing and verification against
// convention paths under ~/.agent_worktrees/<repo>/<change>.
//
// List enumerates the convention directory (filesystem-only, no git
// subprocess). Verify checks the ODD binding signals: root (BLOCKING) and
// task doc (BLOCKING); branch is INFORMATIVE only. The tool never spawns git
// outside the retro commit-ref allowance.
package worktree

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Entry is one listed worktree under ~/.agent_worktrees/<repo>/.
type Entry struct {
	Name       string `json:"name"`
	Path       string `json:"path"`
	Branch     string `json:"branch"`
	RepoRootOK bool   `json:"repo_root_ok"`
	TaskDocOK  bool   `json:"task_doc_ok"`
}

// List enumerates the convention worktree entries under
// ~/.agent_worktrees/<repo>/ with the repo namespace derived filesystem-only
// from the current working directory (RepoNameFromCwd) — never a git
// subprocess. Each entry carries per-entry validation flags; entries failing
// validation are STILL listed (absent/invalid data is reported, never
// fabricated or hidden). Returns a non-nil slice so empty listings marshal
// as honest [].
func List() []Entry {
	trees := make([]Entry, 0)
	home, err := os.UserHomeDir()
	if err != nil {
		return trees
	}
	base := filepath.Join(home, ".agent_worktrees", RepoNameFromCwd())
	entries, err := os.ReadDir(base)
	if err != nil {
		return trees
	}
	for _, e := range entries {
		if !e.IsDir() || strings.HasPrefix(e.Name(), ".") {
			continue
		}
		path := filepath.Join(base, e.Name())
		trees = append(trees, Entry{
			Name:       e.Name(),
			Path:       path,
			Branch:     branchFromGitdir(path),
			RepoRootOK: repoRootOK(path),
			TaskDocOK:  taskDocOK(path, e.Name()),
		})
	}
	return trees
}

// repoRootOK reports whether the entry is a canonical worktree: it contains a
// `.git` FILE whose gitdir: line resolves under <repo>/.git/worktrees/<name>.
func repoRootOK(entryPath string) bool {
	gitPath := filepath.Join(entryPath, ".git")
	info, err := os.Stat(gitPath)
	if err != nil || info.IsDir() {
		return false
	}
	_, ok := gitdirRepoRoot(entryPath, gitPath)
	return ok
}

// taskDocOK reports whether odd/tasks/<feature>.md exists at the entry root.
func taskDocOK(entryPath, feature string) bool {
	info, err := os.Stat(filepath.Join(entryPath, "odd", "tasks", feature+".md"))
	return err == nil && !info.IsDir()
}

// branchFromGitdir reads the branch from the gitdir HEAD of the given
// checkout root: "ref: refs/heads/<branch>" → <branch>. Detached HEAD or a
// missing/ malformed .git marker yield "".
func branchFromGitdir(root string) string {
	gitPath := filepath.Join(root, ".git")
	gitdir := gitPath
	info, err := os.Stat(gitPath)
	if err != nil {
		return ""
	}
	if !info.IsDir() {
		raw, err := os.ReadFile(gitPath)
		if err != nil {
			return ""
		}
		line := strings.TrimSpace(string(raw))
		if !strings.HasPrefix(line, "gitdir:") {
			return ""
		}
		d := strings.TrimSpace(strings.TrimPrefix(line, "gitdir:"))
		if d == "" {
			return ""
		}
		if !filepath.IsAbs(d) {
			d = filepath.Join(root, d)
		}
		gitdir = filepath.Clean(d)
	}
	head, err := os.ReadFile(filepath.Join(gitdir, "HEAD"))
	if err != nil {
		return ""
	}
	s := strings.TrimSpace(string(head))
	const prefix = "ref: refs/heads/"
	if strings.HasPrefix(s, prefix) {
		return strings.TrimPrefix(s, prefix)
	}
	return "" // detached HEAD
}

// VerifyResult holds the outcome of a worktree verify check.
type VerifyResult struct {
	Pass    bool   `json:"pass"`
	Root    Signal `json:"root"`
	TaskDoc Signal `json:"task_doc"`
	Branch  Signal `json:"branch"`
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
	fmt.Fprintf(&b, "  1. Root:     %s  %s\n", passStr(r.Root.Pass), r.Root.Message)
	fmt.Fprintf(&b, "  2. Task doc: %s  %s\n", passStr(r.TaskDoc.Pass), r.TaskDoc.Message)
	fmt.Fprintf(&b, "  3. Branch:   %s  %s  (informative)\n", passStr(r.Branch.Pass), r.Branch.Message)
	return b.String()
}

func passStr(ok bool) string {
	if ok {
		return "[PASS]"
	}
	return "[FAIL]"
}

// Verify checks the ODD binding signals for the convention worktree of
// feature from the current working directory:
//
//   - Root (BLOCKING): the filesystem walk-up root of cwd equals the
//     convention root ~/.agent_worktrees/<repo>/<feature> (normalized).
//   - Task doc (BLOCKING): odd/tasks/<feature>.md exists at that root. Verify
//     NEVER passes without it.
//   - Branch (INFORMATIVE): feat/<feature> is reported, never gates.
//
// Filesystem-only; no git subprocess.
func Verify(feature string) (VerifyResult, error) {
	return verifyAt(feature, cwd())
}

// verifyAt is the start-path-injectable core of Verify (unit-testable).
func verifyAt(feature, start string) (VerifyResult, error) {
	if strings.TrimSpace(feature) == "" {
		return VerifyResult{}, fmt.Errorf("feature is required")
	}
	root := repoRootFrom(start)
	home, homeErr := os.UserHomeDir()

	rootSignal := Signal{Name: "root"}
	switch {
	case homeErr != nil:
		rootSignal = Signal{Name: "root", Pass: false, Message: fmt.Sprintf("user home unavailable: %v", homeErr)}
	case root == "":
		rootSignal = Signal{Name: "root", Pass: false, Message: "cwd is not inside any git checkout"}
	default:
		expected := filepath.Join(home, ".agent_worktrees", repoNameFrom(start), feature)
		rootSignal = Signal{
			Name:    "root",
			Pass:    normalisePath(root) == normalisePath(expected),
			Message: fmt.Sprintf("got %s, expected %s", root, expected),
		}
	}

	taskSignal := Signal{Name: "task_doc"}
	if root == "" {
		taskSignal = Signal{Name: "task_doc", Pass: false, Message: "no verified root to check"}
	} else {
		doc := filepath.Join(root, "odd", "tasks", feature+".md")
		info, err := os.Stat(doc)
		ok := err == nil && !info.IsDir()
		verb := "missing"
		if ok {
			verb = "exists"
		}
		taskSignal = Signal{Name: "task_doc", Pass: ok, Message: fmt.Sprintf("%s: %s", verb, doc)}
	}

	branchSignal := Signal{Name: "branch"}
	if root == "" {
		branchSignal = Signal{Name: "branch", Pass: false, Message: "no verified root to check"}
	} else {
		expected := "feat/" + feature
		branchSignal = Signal{
			Name:    "branch",
			Pass:    branchFromGitdir(root) == expected,
			Message: fmt.Sprintf("got %s, expected %s (informative)", branchFromGitdir(root), expected),
		}
	}

	return VerifyResult{
		Pass:    rootSignal.Pass && taskSignal.Pass,
		Root:    rootSignal,
		TaskDoc: taskSignal,
		Branch:  branchSignal,
	}, nil
}

func cwd() string {
	cwd, err := os.Getwd()
	if err != nil {
		return "."
	}
	return cwd
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

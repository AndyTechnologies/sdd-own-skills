package worktree

import (
	"os"
	"path/filepath"
	"strings"
)

// RepoRootFromCwd returns the filesystem walk-up root of the current working
// directory: the nearest ancestor containing a `.git` marker (a directory in
// a regular checkout, a file in a git worktree). Filesystem-only, never
// spawns git. Returns "" when cwd is not inside any git checkout.
func RepoRootFromCwd() string {
	return repoRootFrom(cwd())
}

// RepoNameFromCwd returns the worktree namespace basename for the current
// working directory: the basename of the nearest ancestor with a `.git`
// marker. When that marker is a worktree `.git` file, its `gitdir:` line is
// resolved to the parent repository's root and THAT basename is returned, so
// a feature worktree resolves to its repo namespace instead of the feature
// name. Degenerate results fall back to "repo".
func RepoNameFromCwd() string {
	return repoNameFrom(cwd())
}

// repoRootFrom walks up from start to the nearest ancestor with a `.git`
// marker and returns that ancestor's absolute path ("" if none).
func repoRootFrom(start string) string {
	dir, err := filepath.Abs(start)
	if err != nil {
		return ""
	}
	for {
		if isGitMarker(dir) {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "" // filesystem root reached without a marker
		}
		dir = parent
	}
}

// repoNameFrom derives the repo namespace name from start's walk-up root,
// resolving worktree `.git` files to their parent repository (see
// RepoNameFromCwd). Degenerate results fall back to "repo".
func repoNameFrom(start string) string {
	root := repoRootFrom(start)
	if root == "" {
		return "repo"
	}
	gitPath := filepath.Join(root, ".git")
	info, err := os.Stat(gitPath)
	if err == nil && !info.IsDir() {
		if repoRoot, ok := gitdirRepoRoot(root, gitPath); ok {
			return filepath.Base(repoRoot)
		}
		return "repo"
	}
	return filepath.Base(root)
}

// isGitMarker reports whether dir contains a `.git` marker (directory or
// file). A broken/missing marker is not a marker.
func isGitMarker(dir string) bool {
	info, err := os.Stat(filepath.Join(dir, ".git"))
	if err != nil {
		return false
	}
	return info.IsDir() || info.Mode().IsRegular()
}

// gitdirRepoRoot resolves a worktree `.git` file's `gitdir:` line to the
// parent repository root. The canonical layout is
// <repo>/.git/worktrees/<name>; the repo root is the gitdir path minus that
// suffix. Returns ok=false for unreadable/malformed gitdir files or
// non-canonical layouts (callers fall back to "repo").
func gitdirRepoRoot(markerDir, gitPath string) (string, bool) {
	raw, err := os.ReadFile(gitPath)
	if err != nil {
		return "", false
	}
	line := strings.TrimSpace(string(raw))
	if !strings.HasPrefix(line, "gitdir:") {
		return "", false
	}
	gitdir := strings.TrimSpace(strings.TrimPrefix(line, "gitdir:"))
	if gitdir == "" {
		return "", false
	}
	if !filepath.IsAbs(gitdir) {
		gitdir = filepath.Join(markerDir, gitdir)
	}
	gitdir = filepath.Clean(gitdir)
	suffix := filepath.Join(".git", "worktrees", filepath.Base(markerDir))
	if !strings.HasSuffix(gitdir, suffix) {
		return "", false
	}
	repoRoot := strings.TrimSuffix(gitdir, suffix)
	if repoRoot == "" || repoRoot == "." || repoRoot == "/" {
		return "", false
	}
	return repoRoot, true
}

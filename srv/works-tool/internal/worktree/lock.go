package worktree

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

// LockV2 is the lifecycle lock schema (version 2) shared with the MCP
// sidecar (srv/gh-mcp-server/src/worktree_state.py). The version field is
// REQUIRED and MUST equal 2 — v1 locks (pid/timestamp) are never silently
// trusted; they require explicit recovery.
type LockV2 struct {
	Version   int    `json:"version"`
	PID       int    `json:"pid"`
	Session   string `json:"session"`
	Owner     string `json:"owner"`
	Change    string `json:"change"`
	RepoRoot  string `json:"repo_root"`
	RepoName  string `json:"repo_name"`
	Branch    string `json:"branch"`
	Store     string `json:"store"`
	CreatedAt string `json:"created_at"`
	LastSeen  string `json:"last_seen"`
}

// ParseLockV2 reads and validates a lock file.
//
// Explicit guard: only ``version == 2`` locks parse successfully. A missing
// version, a v1 lock, or any other value returns an error — the caller must
// never treat an unverifiable lock as a live claim.
func ParseLockV2(path string) (*LockV2, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read lock %s: %w", path, err)
	}
	var lock LockV2
	if err := json.Unmarshal(raw, &lock); err != nil {
		return nil, fmt.Errorf("parse lock %s: %w", path, err)
	}
	if lock.Version != 2 {
		return nil, fmt.Errorf(
			"lock %s: unsupported version %d (only v2 is trusted; v1/missing needs explicit recovery)",
			path, lock.Version,
		)
	}
	return &lock, nil
}

// IsStale reports whether the lock's PID is dead.
//
// Liveness probe: ``kill(pid, 0)`` — ``ESRCH`` (no such process) → dead;
// ``EPERM`` (process exists but owned by another user) → alive. Absent or
// non-positive PID → stale. This mirrors the Python sidecar's
// ``lock_has_live_pid``.
func IsStale(lock *LockV2) bool {
	if lock == nil || lock.PID <= 0 {
		return true
	}
	err := syscall.Kill(lock.PID, 0)
	if err == nil {
		return false // alive
	}
	if errors.Is(err, syscall.EPERM) {
		return false // alive, owned by another user
	}
	return true // ESRCH or anything else → dead/unknown
}

// RepoNameFromGitRoot derives the canonical worktree namespace basename for
// *repoPath*: the basename of ``git rev-parse --show-toplevel``. Any subdir
// (``/repo``, ``/repo/sub``, ``/repo/.``) maps to the SAME name. For a
// non-repo path the fallback is the path's own basename; degenerate results
// (``.``, ``..``, ``/``, empty) fall back to "repo".
func RepoNameFromGitRoot(repoPath string) string {
	name := repoPath
	out, err := exec.Command("git", "-C", repoPath, "rev-parse", "--show-toplevel").CombinedOutput()
	if err == nil && strings.TrimSpace(string(out)) != "" {
		name = strings.TrimSpace(string(out))
	}
	base := filepath.Base(filepath.Clean(name))
	switch base {
	case ".", "..", "", "/":
		base = filepath.Base(filepath.Clean(repoPath))
	}
	if base == "" || base == "." || base == ".." || base == "/" {
		return "repo"
	}
	return base
}
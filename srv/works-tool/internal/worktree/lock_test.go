package worktree

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"testing"
)

func writeLock(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), ".sdd-agent-lock")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestParseLockV2Version1Errors(t *testing.T) {
	// Legacy v1 lock (pid/timestamp) — must NEVER parse as trusted.
	path := writeLock(t, `{"pid": 1234, "session": "s1", "owner": "alice", "timestamp": 1788984739.8}`)
	lock, err := ParseLockV2(path)
	if err == nil {
		t.Fatalf("expected error for v1 lock, got %+v", lock)
	}
}

func TestParseLockV2MissingVersionErrors(t *testing.T) {
	path := writeLock(t, `{"pid": 1234, "owner": "alice"}`)
	if _, err := ParseLockV2(path); err == nil {
		t.Fatal("expected error for lock without version")
	}
}

func TestParseLockV2CorruptJSONErrors(t *testing.T) {
	path := writeLock(t, `{not-json`)
	if _, err := ParseLockV2(path); err == nil {
		t.Fatal("expected error for corrupt JSON")
	}
}

func TestParseLockV2MissingFileErrors(t *testing.T) {
	if _, err := ParseLockV2(filepath.Join(t.TempDir(), "nope")); err == nil {
		t.Fatal("expected error for missing lock file")
	}
}

func TestParseLockV2Version2Parsed(t *testing.T) {
	path := writeLock(t, `{
		"version": 2, "pid": 4242, "session": "s1", "owner": "alice",
		"change": "c1", "repo_root": "/repo", "repo_name": "repo",
		"branch": "sdd/c1", "store": "hybrid",
		"created_at": "2026-01-01T00:00:00+00:00",
		"last_seen": "2026-01-01T00:00:00+00:00"
	}`)
	lock, err := ParseLockV2(path)
	if err != nil {
		t.Fatal(err)
	}
	if lock.Version != 2 || lock.PID != 4242 || lock.Owner != "alice" || lock.Branch != "sdd/c1" {
		t.Fatalf("unexpected parsed lock: %+v", lock)
	}
}

// deadPID returns a PID that is guaranteed not to exist on this host:
// a child process that was spawned and has fully exited.
func deadPID(t *testing.T) int {
	t.Helper()
	if runtime.GOOS != "linux" {
		return 999_999_999 // beyond the Linux pid_max default
	}
	cmd := exec.Command("sh", "-c", "exit 0")
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	pid := cmd.Process.Pid
	if err := cmd.Wait(); err != nil {
		t.Fatal(err)
	}
	return pid
}

func TestIsStaleDeadPID(t *testing.T) {
	if !IsStale(&LockV2{PID: deadPID(t)}) {
		t.Fatal("expected exited child PID to be stale")
	}
}

func TestIsStaleAlivePID(t *testing.T) {
	if IsStale(&LockV2{PID: os.Getpid()}) {
		t.Fatal("expected own PID to be alive, not stale")
	}
}

func TestIsStaleZeroNilNegative(t *testing.T) {
	if !IsStale(nil) {
		t.Fatal("expected nil lock to be stale")
	}
	if !IsStale(&LockV2{PID: 0}) {
		t.Fatal("expected PID 0 to be stale")
	}
	if !IsStale(&LockV2{PID: -1}) {
		t.Fatal("expected negative PID to be stale")
	}
}

func TestRepoNameFromGitRoot(t *testing.T) {
	repo := filepath.Join(t.TempDir(), "proj")
	if err := exec.Command("git", "init", "-q", repo).Run(); err != nil {
		t.Skipf("git init unavailable: %v", err)
	}
	if name := RepoNameFromGitRoot(repo); name != "proj" {
		t.Fatalf("expected proj, got %q", name)
	}
	sub := filepath.Join(repo, "sub")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	// Any subdir resolves to the toplevel basename (same namespace).
	if name := RepoNameFromGitRoot(sub); name != "proj" {
		t.Fatalf("expected proj from subdir, got %q", name)
	}
	if name := RepoNameFromGitRoot(repo + string(filepath.Separator) + "."); name != "proj" {
		t.Fatalf("expected proj from /./, got %q", name)
	}
}

func TestRepoNameFromGitRootNonRepoFallback(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "notgit")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if name := RepoNameFromGitRoot(dir); name != "notgit" {
		t.Fatalf("expected fallback name notgit, got %q", name)
	}
}

func TestRepoNameFromGitRootDegenerate(t *testing.T) {
	// Root has no meaningful basename → "repo" fallback.
	if got := RepoNameFromGitRoot(string(filepath.Separator) + "nonexistent-" + strconv.Itoa(os.Getpid())); got == "" || got == "." {
		t.Fatalf("expected sane fallback, got %q", got)
	}
}
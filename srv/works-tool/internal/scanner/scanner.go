// Package scanner is the lazy Facade in front of `gentle-ai sdd-status --json`.
//
// D4: ONE cached parse feeds each listing surface that needs it, BUT only
// when a listing surface requires it — never in a PersistentPreRunE for all
// commands, and NEVER for mutating commands (retro persist, bug record,
// bug resolve). The snapshot is process-lifetime; the dashboard `r` key is an
// explicit re-parse, not polling. Parse failure exits non-zero loudly and
// NEVER fabricates empty worktree/dashboard surfaces (acta D5).
package scanner

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os/exec"
)

// Status mirrors the gentle-ai.sdd-status v2 JSON shape consumed by the
// listing surfaces (dashboard table, worktree verify signal 3).
type Status struct {
	ArtifactStore string    `json:"artifactStore"`
	Changes       []*Change `json:"changes"`
}

// Change is one active change entry in the scanner output.
type Change struct {
	Name            string   `json:"name"`
	Status          string   `json:"status"`
	NextRecommended string   `json:"nextRecommended"`
	BlockedReasons  []string `json:"blockedReasons"`
	ArtifactPaths   []string `json:"artifactPaths"`
}

// Scanner lazily parses `gentle-ai sdd-status --json` exactly once per run.
type Scanner struct {
	cmd  string
	data *Status
	done bool
	err  error
}

// New returns a Scanner that invokes the given command (default
// "gentle-ai sdd-status --json"). No invocation happens until Snapshot.
func New(cmd string) *Scanner {
	if cmd == "" {
		cmd = "gentle-ai sdd-status --json"
	}
	return &Scanner{cmd: cmd}
}

// Snapshot returns the cached parse, invoking the command at most once.
// A parse failure is surfaced as an error; callers that are listing surfaces
// must exit non-zero loudly and never fabricate an empty surface.
func (s *Scanner) Snapshot() (*Status, error) {
	if s.done {
		return s.data, s.err
	}
	s.done = true
	s.data, s.err = run(s.cmd)
	return s.data, s.err
}

func run(cmd string) (*Status, error) {
	parts := splitCommand(cmd)
	out, err := exec.Command(parts[0], parts[1:]...).Output()
	if err != nil {
		return nil, fmt.Errorf("scanner: %s failed: %w", cmd, err)
	}
	var st Status
	if err := json.Unmarshal(out, &st); err != nil {
		return nil, fmt.Errorf("scanner: parse of `%s` failed (unreadable/half-written): %w", cmd, err)
	}
	return &st, nil
}

// splitCommand splits a simple quoted shell command into argv. Supports
// double-quoted segments for values that may contain spaces.
func splitCommand(cmd string) []string {
	var parts []string
	var cur bytes.Buffer
	inQ := false
	seen := false
	for _, r := range cmd {
		switch {
		case r == '"':
			inQ = !inQ
			seen = true
		case (r == ' ' || r == '\t') && !inQ:
			if seen {
				parts = append(parts, cur.String())
				cur.Reset()
				seen = false
			}
		default:
			cur.WriteRune(r)
			seen = true
		}
	}
	if seen {
		parts = append(parts, cur.String())
	}
	return parts
}

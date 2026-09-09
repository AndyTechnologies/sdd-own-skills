// Package retro provides store-aware retrospective persistence and lookup.
//
// Store-first on the declared mode, cross-store fallback only on zero domain
// results, dedupe by change name, precis capped at 3–5 retros of ≤15 lines.
// Engram access via subprocess only (save/search/timeline).
// Write failures exit non-zero with a loud FAIL-OPEN marker (D2).
package retro

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"sdd-tool/internal/engram"
	"sdd-tool/internal/scrub"
)

// Precis holds the structured retro lookup result.
type Precis struct {
	Count  int          `json:"count"`
	Retros []RetroEntry `json:"retros"`
	Text_  string       `json:"-"`
}

// RetroEntry is one deduped retrospective in the precis.
type RetroEntry struct {
	Change string `json:"change"`
	Body   string `json:"body"`
	Lines  int    `json:"lines"`
	Source string `json:"source"` // "openspec" or "engram"
}

// Text returns the human-readable precis.
func (p *Precis) Text() string {
	if p.Text_ != "" {
		return p.Text_
	}
	if p.Count == 0 {
		return ""
	}
	var b strings.Builder
	fmt.Fprintf(&b, "Retrospectives (%d):\n\n", p.Count)
	for i, r := range p.Retros {
		fmt.Fprintf(&b, "## %d. %s (via %s)\n", i+1, r.Change, r.Source)
		body := r.Body
		if r.Lines > 15 {
			lines := strings.SplitN(body, "\n", 16)
			body = strings.Join(lines[:15], "\n") + "\n... (truncated)"
		}
		fmt.Fprintf(&b, "%s\n\n", body)
	}
	p.Text_ = b.String()
	return p.Text_
}

// Store is the interface for retro persistence backends.
type Store interface {
	Lookup(changeName string, verifyDomain bool) (*Precis, error)
	Persist(changeName, phase, body, bodyFile string) error
}

// NewStore creates a store for the given mode.
func NewStore(mode string) (Store, error) {
	switch mode {
	case "both":
		return &compositeStore{primary: newOpenspecStore(), fallback: newEngramStore(), mode: mode}, nil
	case "openspec":
		return newOpenspecStore(), nil
	case "engram":
		return newEngramStore(), nil
	case "none":
		return &noneStore{}, nil
	default:
		return nil, fmt.Errorf("unknown mode %q: must be both|openspec|engram|none", mode)
	}
}

// compositeStore implements cross-store fallback.
type compositeStore struct {
	primary  Store
	fallback Store
	mode     string
}

func (c *compositeStore) Lookup(changeName string, verifyDomain bool) (*Precis, error) {
	p, err := c.primary.Lookup(changeName, verifyDomain)
	if err != nil {
		return nil, err
	}
	if p.Count > 0 {
		return p, nil
	}
	// Fallback on zero results
	return c.fallback.Lookup(changeName, verifyDomain)
}

func (c *compositeStore) Persist(changeName, phase, body, bodyFile string) error {
	b, err := resolveBody(body, bodyFile)
	if err != nil {
		return err
	}
	b = scrub.Scrub(b)
	err1 := c.primary.Persist(changeName, phase, b, "")
	err2 := c.fallback.Persist(changeName, phase, b, "")
	if err1 != nil {
		return err1
	}
	return err2
}

// noneStore emits a hint only.
type noneStore struct{}

func (n *noneStore) Lookup(string, bool) (*Precis, error) {
	return &Precis{}, nil
}

func (n *noneStore) Persist(changeName, _, _, _ string) error {
	fmt.Fprintf(os.Stderr, "Hint: mode=none — no retrospective persisted for %s\n", changeName)
	return nil
}

// openspecStore persists to openspec/changes/{change}/retrospective.md.
type openspecStore struct{}

func newOpenspecStore() *openspecStore { return &openspecStore{} }

func (o *openspecStore) Lookup(changeName string, verifyDomain bool) (*Precis, error) {
	entries, err := o.listRetros(changeName)
	if err != nil {
		return nil, err
	}
	return buildPrecis(entries, verifyDomain), nil
}

func (o *openspecStore) Persist(changeName, phase, body, bodyFile string) error {
	b, err := resolveBody(body, bodyFile)
	if err != nil {
		return err
	}
	b = scrub.Scrub(b)

	// Find the openspec changes dir
	repoRoot := findRepoRoot()
	if repoRoot == "" {
		return fmt.Errorf("cannot locate repo root for openspec persist")
	}
	dir := filepath.Join(repoRoot, "openspec", "changes", changeName)
	os.MkdirAll(dir, 0o755)

	file := filepath.Join(dir, "retrospective.md")
	frontmatter := fmt.Sprintf("---\nchange: %s\nphase: %s\nstore-mode: openspec\n---\n\n", changeName, phase)
	content := frontmatter + formatRetroSections(b)

	return os.WriteFile(file, []byte(content), 0o644)
}

func (o *openspecStore) listRetros(changeName string) ([]retroEntry, error) {
	repoRoot := findRepoRoot()
	if repoRoot == "" {
		return nil, nil
	}
	var entries []retroEntry

	// Active changes
	activeDir := filepath.Join(repoRoot, "openspec", "changes")
	entries = append(entries, scanDir(activeDir, changeName, "openspec")...)

	// Archived changes
	archiveDir := filepath.Join(repoRoot, "openspec", "changes", "archive")
	entries = append(entries, scanDir(archiveDir, changeName, "openspec")...)

	return entries, nil
}

type retroEntry struct {
	change string
	body   string
	source string
	ftime  time.Time
}

func scanDir(dir, changeFilter, source string) []retroEntry {
	var entries []retroEntry
	_ = filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info == nil {
			return nil
		}
		// The active scan walks openspec/changes recursively, which INCLUDES
		// archive/. Skipping it (unless archive/ is the walk root itself, i.e.
		// the dedicated archive scan) prevents the same retrospective.md from
		// being matched twice and breaking dedupe-by-change-name.
		if info.IsDir() && info.Name() == "archive" && path != dir {
			return filepath.SkipDir
		}
		if info.IsDir() || info.Name() != "retrospective.md" {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		change := extractChangeFromPath(path, dir)
		if changeFilter != "" && change != changeFilter {
			return nil
		}
		body := string(data)
		entries = append(entries, retroEntry{change: change, body: body, source: source, ftime: info.ModTime()})
		return nil
	})
	return entries
}

// stripDatePrefix strips a leading YYYY-MM-DD- archive prefix from a change
// directory name: "2026-09-09-test-x" → "test-x"; "test-x" stays "test-x".
func stripDatePrefix(name string) string {
	// len("2026-09-09-") == 11
	if len(name) >= 11 && name[4] == '-' && name[7] == '-' && name[10] == '-' {
		return name[11:]
	}
	return name
}

func extractChangeFromPath(path, baseDir string) string {
	rel, err := filepath.Rel(baseDir, filepath.Dir(path))
	if err != nil {
		return filepath.Base(filepath.Dir(path))
	}
	parts := strings.SplitN(rel, string(filepath.Separator), 2)
	if len(parts) > 1 {
		// Deep path (e.g. archive/2026-09-09-test-x from the active scan): the
		// change name is the deepest segment with any date prefix stripped.
		return stripDatePrefix(parts[len(parts)-1])
	}
	// Single segment (e.g. 2026-09-09-test-x from the archive scan): strip the
	// archive date prefix so the canonical name is "test-x", not the raw dir.
	return stripDatePrefix(parts[0])
}

func buildPrecis(entries []retroEntry, verifyDomain bool) *Precis {
	if len(entries) == 0 {
		return &Precis{}
	}
	// Dedupe by change (newest wins)
	deduped := make(map[string]retroEntry)
	for _, e := range entries {
		if existing, ok := deduped[e.change]; !ok || e.ftime.After(existing.ftime) {
			deduped[e.change] = e
		}
	}
	var sorted []retroEntry
	for _, e := range deduped {
		sorted = append(sorted, e)
	}
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].ftime.After(sorted[j].ftime)
	})
	// Cap at 5
	if len(sorted) > 5 {
		sorted = sorted[:5]
	}

	var entries_out []RetroEntry
	for _, e := range sorted {
		body := e.body
		if verifyDomain {
			body = extractVerifyDomain(body)
		}
		body = scrub.Scrub(body)
		lines := strings.Count(body, "\n") + 1
		entries_out = append(entries_out, RetroEntry{
			Change: e.change,
			Body:   body,
			Lines:  lines,
			Source: e.source,
		})
	}
	return &Precis{Count: len(entries_out), Retros: entries_out}
}

func extractVerifyDomain(body string) string {
	var out strings.Builder
	inSection := false
	sections := []string{"verification gaps", "verify-phase incidents"}
	for _, line := range strings.Split(body, "\n") {
		lower := strings.ToLower(line)
		for _, s := range sections {
			if strings.Contains(lower, s) {
				inSection = true
				out.WriteString(line + "\n")
				break
			}
		}
		if inSection && strings.HasPrefix(line, "## ") && !strings.Contains(strings.ToLower(line), "verification") && !strings.Contains(strings.ToLower(line), "incident") {
			inSection = false
		}
	}
	return strings.TrimSpace(out.String())
}

func formatRetroSections(body string) string {
	// Ensure the body has the 4 required sections
	sections := []string{"What Worked", "What Didn't", "Verification Gaps", "Verify-Phase Incidents"}
	hasSection := func(s string) bool {
		return strings.Contains(body, "## "+s) || strings.Contains(body, "# "+s)
	}
	var out strings.Builder
	for _, s := range sections {
		if hasSection(s) {
			// Section exists in the body, find and include it
			idx := strings.Index(body, "## "+s)
			if idx < 0 {
				idx = strings.Index(body, "# "+s)
			}
			if idx >= 0 {
				nextSection := len(body)
				for _, ns := range sections {
					nIdx := strings.Index(body[idx+len(s)+4:], "## "+ns)
					if nIdx > 0 {
						candidate := idx + len(s) + 4 + nIdx
						if candidate < nextSection {
							nextSection = candidate
						}
					}
				}
				out.WriteString(body[idx:nextSection])
				out.WriteString("\n")
				continue
			}
		}
		out.WriteString(fmt.Sprintf("## %s\n\n(none)\n\n", s))
	}
	return out.String()
}

func resolveBody(body, bodyFile string) (string, error) {
	if bodyFile != "" {
		data, err := os.ReadFile(bodyFile)
		if err != nil {
			return "", fmt.Errorf("failed to read body file %s: %w", bodyFile, err)
		}
		return string(data), nil
	}
	if body != "" {
		return body, nil
	}
	return "", fmt.Errorf("either --body or --body-file is required")
}

func findRepoRoot() string {
	cwd, err := os.Getwd()
	if err != nil {
		return ""
	}
	// Walk up looking for openspec/ dir
	dir := cwd
	for {
		if _, err := os.Stat(filepath.Join(dir, "openspec")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

// engramStore persists to Engram via subprocess only.
type engramStore struct{}

func newEngramStore() *engramStore { return &engramStore{} }

func (e *engramStore) Lookup(changeName string, verifyDomain bool) (*Precis, error) {
	results, err := engram.Search("retrospective", 20)
	if err != nil {
		return nil, err
	}
	var entries []retroEntry
	for _, r := range results {
		if !strings.HasPrefix(r.Title, "sdd/") || !strings.HasSuffix(r.Title, "/retrospective") {
			continue
		}
		change := extractChangeFromTopic(r.Title)
		if changeName != "" && change != changeName {
			continue
		}
		body := r.Content
		if verifyDomain {
			body = extractVerifyDomain(body)
		}
		entries = append(entries, retroEntry{
			change: change,
			body:   body,
			source: "engram",
			ftime:  r.Time,
		})
	}
	return buildPrecis(entries, verifyDomain), nil
}

func (e *engramStore) Persist(changeName, phase, body, bodyFile string) error {
	b, err := resolveBody(body, bodyFile)
	if err != nil {
		return err
	}
	b = scrub.Scrub(b)
	topicKey := fmt.Sprintf("sdd/%s/retrospective", changeName)
	return engram.Save(topicKey, b, "learning")
}

func extractChangeFromTopic(title string) string {
	// sdd/{change}/retrospective
	parts := strings.Split(title, "/")
	if len(parts) >= 2 {
		return parts[1]
	}
	return title
}

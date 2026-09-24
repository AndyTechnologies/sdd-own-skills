// Package retro provides the retrospective ledger for ODD change tasks.
//
// Each persist saves ONE ordered ledger entry
//
//   - [Retro <phase>] <commit-ref>: <summary>
//     <indented detail lines, when present>
//
// to two places, in this order:
//
//  1. Engram — PRIMARY storage. The observation topic
//     `odd/<feature>/retrospective` (title == topic, type learning, topic-key
//     upsert) holds the ordered list of signed entries; re-persisting
//     (feature, phase, commit-ref) is an in-place update, never a duplicate.
//  2. odd/tasks/<feature>.md under `## Retros` (created when missing) in the
//     walk-up repo root — the SECONDARY durable copy of the same entry line.
//
// When the task-doc appendix cannot be written (task doc missing, not in a
// repo, or a read/write failure), Persist returns ErrTaskDocUnavailable and
// the caller emits the D2 loud FAIL-OPEN marker with exit 2 — the Engram
// write still stands when it succeeded, and its failure is carried alongside
// when it did not. Honest environmental note: the standalone CLI `engram
// save` may be rejected by the v2 session-ownership guard in this
// environment; the persist then still succeeds with EngramWritten=false and
// the reason in EngramError — that never re-orders the A6 contract (Engram
// primary, task-doc appendix secondary).
//
// Persists are idempotent by (feature, phase, commit-ref): a re-run whose
// marker is already recorded is a no-op (AlreadyRecorded).
//
// Engram access is subprocess-only (save/search); lookups never touch git.
// `git rev-parse HEAD` (for the commit ref) is the tool's ONLY sanctioned git
// subprocess and lives in the retro command layer, not here.
package retro

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"works-tool/internal/engram"
	"works-tool/internal/scrub"
	"works-tool/internal/worktree"
)

// Engram adapter seam. Production defaults are the subprocess-only CLI
// adapter (internal/engram); tests substitute in-memory fakes. Package
// callers keep the subprocess-only behavior.
var (
	engramSave   = engram.Save
	engramSearch = engram.Search
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
	Source string `json:"source"` // always "engram" (Engram-first)
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

// PersistResult reports the outcome of one retro persist.
type PersistResult struct {
	Feature         string `json:"feature"`
	Phase           string `json:"phase"`
	CommitRef       string `json:"commit_ref"`
	AlreadyRecorded bool   `json:"already_recorded"`
	EngramWritten   bool   `json:"engram_written"`
	EngramError     string `json:"engram_error,omitempty"`
	TaskDocPath     string `json:"task_doc_path,omitempty"`
	TaskDocAppended bool   `json:"task_doc_appended"`
}

// ErrTaskDocUnavailable means the SECONDARY task-doc appendix could not be
// performed (task doc missing, not in a repo, or a read/write failure).
// Callers surface the D2 FAIL-OPEN marker and exit 2 — the retro's secondary
// durable copy is lost (the Engram write stands when it succeeded, and its
// failure is carried alongside when it did not).
type ErrTaskDocUnavailable struct{ Reason string }

func (e *ErrTaskDocUnavailable) Error() string { return "task doc appendix unavailable: " + e.Reason }

// topic returns the engram topic key for a feature's ledger.
func topic(feature string) string { return "odd/" + feature + "/retrospective" }

// SplitBody splits a resolved retro body into its one-line summary (the
// first non-empty line) and the remaining detail (trimmed), for the ledger
// entry bullet.
func SplitBody(body string) (summary, detail string) {
	lines := strings.Split(strings.TrimSpace(body), "\n")
	start := -1
	for i, l := range lines {
		if strings.TrimSpace(l) != "" {
			start = i
			break
		}
	}
	if start == -1 {
		return "", ""
	}
	summary = strings.TrimSpace(lines[start])
	rest := lines[start+1:]
	for len(rest) > 0 && strings.TrimSpace(rest[0]) == "" {
		rest = rest[1:]
	}
	return summary, strings.TrimSpace(strings.Join(rest, "\n"))
}

// BuildLedgerEntry renders one ordered ledger entry from a phase, commit ref,
// summary line and optional detail (indented two spaces under the bullet).
func BuildLedgerEntry(phase, commitRef, summary, detail string) string {
	var b strings.Builder
	b.WriteString("- [Retro " + phase + "] " + commitRef + ": " + summary)
	if d := strings.TrimSpace(detail); d != "" {
		for _, l := range strings.Split(d, "\n") {
			b.WriteString("\n  " + l)
		}
	}
	return b.String()
}

// HasMarker reports whether the ledger already records (phase, commitRef).
func HasMarker(ledger, phase, commitRef string) bool {
	marker := "[Retro " + phase + "] " + commitRef
	for _, l := range strings.Split(ledger, "\n") {
		if strings.Contains(l, marker) {
			return true
		}
	}
	return false
}

// AppendToLedger appends entry to the ordered ledger, preserving order.
func AppendToLedger(current, entry string) string {
	current = strings.TrimSpace(current)
	entry = strings.TrimSpace(entry)
	if current == "" {
		return entry
	}
	return current + "\n" + entry
}

// indexHeadingLine returns the index of the first line-start occurrence of
// heading in doc, or -1. The heading must sit at the start of a line — a
// substring match (e.g. "## Retros" mentioned inside task-description prose)
// never counts as a real section.
func indexHeadingLine(doc, heading string) int {
	for idx := 0; idx < len(doc); {
		i := strings.Index(doc[idx:], heading)
		if i == -1 {
			return -1
		}
		pos := idx + i
		if pos == 0 || doc[pos-1] == '\n' {
			return pos
		}
		idx = pos + len(heading)
	}
	return -1
}

// AppendLedgerToDoc inserts entry under the doc's `## Retros` section —
// after the heading when the section exists (line-start heading only), or as
// a new section at the end when absent. Pure string helper; callers do the
// file IO.
func AppendLedgerToDoc(docContent, entry string) string {
	entry = strings.TrimSpace(entry)
	const heading = "## Retros"
	idx := indexHeadingLine(docContent, heading)
	if idx == -1 {
		base := strings.TrimRight(docContent, "\n")
		if base == "" {
			return heading + "\n\n" + entry + "\n"
		}
		return base + "\n\n" + heading + "\n\n" + entry + "\n"
	}
	// Insert at the end of the existing section: right before the next H2
	// heading after "## Retros" (line-start), or at EOF.
	after := docContent[idx+len(heading):]
	if n := nextH2(after); n >= 0 {
		pos := idx + len(heading) + n
		return docContent[:pos] + "\n" + entry + docContent[pos:]
	}
	return strings.TrimRight(docContent, "\n") + "\n" + entry + "\n"
}

// nextH2 returns the index of the next line-start "## " heading in s, or -1.
func nextH2(s string) int {
	for i := 0; i+3 < len(s); i++ {
		if s[i] == '\n' && s[i+1] == '#' && s[i+2] == '#' && s[i+3] == ' ' {
			return i
		}
	}
	return -1
}

// mergeLedgerBodies joins ledger source bodies with line-identity dedupe:
// an exact trimmed-line match appears once, first occurrence wins. Both
// durable copies (task-doc appendix, Engram primary) carry the SAME shared
// entry lines, so a line present in both stores must never be duplicated in
// the merged ledger — that is the P03 body contract ("ordered list of signed
// entries, one per work-unit, never a duplicate").
func mergeLedgerBodies(bodies []string) string {
	seen := make(map[string]bool)
	var lines []string
	for _, body := range bodies {
		for _, line := range strings.Split(body, "\n") {
			key := strings.TrimSpace(line)
			if key == "" {
				continue
			}
			if seen[key] {
				continue
			}
			seen[key] = true
			lines = append(lines, key)
		}
	}
	return strings.Join(lines, "\n")
}

// CurrentLedger returns the accumulated ledger body for feature: the Engram
// topic (primary) merged with the task-doc `## Retros` appendix (secondary
// durable copy); "" when none exists in either source. The merge dedupes by
// line identity so an entry line present in BOTH stores (the normal state
// after a persist) is never saved back to Engram as a duplicate. Read
// failures are fail-open: any source that reads contributes; an unreadable
// source is skipped rather than aborting a persist.
func CurrentLedger(feature string) string {
	var bodies []string
	if root := worktree.RepoRootFromCwd(); root != "" {
		if data, err := os.ReadFile(filepath.Join(root, "odd", "tasks", feature+".md")); err == nil {
			if s, ok := extractRetrosSection(string(data)); ok {
				if s = strings.TrimSpace(s); s != "" {
					bodies = append(bodies, s)
				}
			}
		}
	}
	if results, err := engramSearch(topic(feature), 5); err == nil {
		for _, r := range results {
			if r.Title == topic(feature) {
				if s := strings.TrimSpace(r.Content); s != "" {
					bodies = append(bodies, s)
				}
				break
			}
		}
	}
	return mergeLedgerBodies(bodies)
}

// extractRetrosSection returns the content of the document's `## Retros`
// section (heading line excluded), ending at the next line-start H2 or EOF.
// Only a line-start heading counts — an inline "## Retros" mention in prose
// is not a section.
func extractRetrosSection(doc string) (string, bool) {
	const heading = "## Retros"
	idx := indexHeadingLine(doc, heading)
	if idx == -1 {
		return "", false
	}
	after := doc[idx+len(heading):]
	if nl := strings.IndexByte(after, '\n'); nl >= 0 {
		after = after[nl+1:]
	} else {
		return "", true // heading is the last line: empty section
	}
	if n := nextH2(after); n >= 0 {
		after = after[:n]
	}
	return strings.TrimSpace(after), true
}

// Persist records a retro ledger entry for (feature, phase, commitRef).
// Engram is the PRIMARY store and is saved first: the observation topic
// odd/<feature>/retrospective (type learning) is upserted in place, so a
// re-persist of (feature, phase, commit-ref) never duplicates. The task-doc
// appendix (odd/tasks/<feature>.md ## Retros) is the SECONDARY durable copy
// and runs second: any failure there returns ErrTaskDocUnavailable (with the
// Engram write status attached), and the caller emits the loud FAIL-OPEN
// marker with exit 2 while the Engram write stands. When the engram
// session-ownership guard or the standalone CLI rejects the save, the
// persist still succeeds with EngramWritten=false and the reason in
// EngramError — the A6 ordering (Engram primary, appendix secondary) is
// never re-arranged. Idempotent by (feature, phase, commit-ref).
func Persist(feature, phase, commitRef, summary, detail string) (*PersistResult, error) {
	res := &PersistResult{Feature: feature, Phase: phase, CommitRef: commitRef}
	if HasMarker(CurrentLedger(feature), phase, commitRef) {
		res.AlreadyRecorded = true
		return res, nil
	}
	entry := BuildLedgerEntry(phase, commitRef, summary, detail)
	next := AppendToLedger(CurrentLedger(feature), entry)
	if err := engramSave(topic(feature), scrub.Scrub(next), "learning"); err != nil {
		res.EngramError = err.Error()
	} else {
		res.EngramWritten = true
	}

	root := worktree.RepoRootFromCwd()
	if root == "" {
		return res, docFail(res, "cwd is not inside any git checkout")
	}
	res.TaskDocPath = filepath.Join(root, "odd", "tasks", feature+".md")
	data, err := os.ReadFile(res.TaskDocPath)
	if err != nil {
		return res, docFail(res, "cannot read "+res.TaskDocPath+": "+err.Error())
	}
	if err := os.WriteFile(res.TaskDocPath, []byte(AppendLedgerToDoc(string(data), entry)), 0o644); err != nil {
		return res, docFail(res, "cannot write "+res.TaskDocPath+": "+err.Error())
	}
	res.TaskDocAppended = true
	return res, nil
}

// docFail wraps a task-doc appendix failure as ErrTaskDocUnavailable,
// preserving the Engram write status for honest, combined reporting.
func docFail(res *PersistResult, reason string) error {
	if res.EngramError != "" {
		return fmt.Errorf("%w; engram write also failed: %s", &ErrTaskDocUnavailable{Reason: reason}, res.EngramError)
	}
	return &ErrTaskDocUnavailable{Reason: reason}
}

// Lookup returns deduped retrospectives from the Engram topics (primary,
// odd/<feature>/retrospective) merged with the task-doc `## Retros`
// appendixes (secondary durable copies, odd/tasks/*.md), optionally filtered
// to one feature and/or to the verification domain. An engram search failure
// is fail-open: the task-doc appendixes still answer.
func Lookup(feature string, verifyDomain bool) (*Precis, error) {
	var entries []retroEntry
	docEntries, err := lookupDocLedger(feature)
	if err != nil {
		return nil, err
	}
	entries = append(entries, docEntries...)

	if results, serr := engramSearch("retrospective", 20); serr == nil {
		for _, r := range results {
			if !strings.HasPrefix(r.Title, "odd/") || !strings.HasSuffix(r.Title, "/retrospective") {
				continue
			}
			change := topicChange(r.Title)
			if feature != "" && change != feature {
				continue
			}
			body := r.Content
			if verifyDomain {
				body = ExtractVerifyDomain(body)
			}
			entries = append(entries, retroEntry{change: change, body: body, source: "engram", ftime: r.Time})
		}
	}
	return buildPrecis(entries, verifyDomain), nil
}

// lookupDocLedger reads the secondary durable retros appendix from
// odd/tasks/*.md under the walk-up repo root. Not inside a checkout yields
// no doc source (nil).
func lookupDocLedger(feature string) ([]retroEntry, error) {
	root := worktree.RepoRootFromCwd()
	if root == "" {
		return nil, nil
	}
	files, err := filepath.Glob(filepath.Join(root, "odd", "tasks", "*.md"))
	if err != nil {
		return nil, err
	}
	var entries []retroEntry
	for _, f := range files {
		change := strings.TrimSuffix(filepath.Base(f), ".md")
		if feature != "" && change != feature {
			continue
		}
		data, err := os.ReadFile(f)
		if err != nil {
			continue // unreadable task doc: skip (fail-open)
		}
		section, ok := extractRetrosSection(string(data))
		if !ok || strings.TrimSpace(section) == "" {
			continue
		}
		var ftime time.Time
		if st, err := os.Stat(f); err == nil {
			ftime = st.ModTime()
		}
		entries = append(entries, retroEntry{change: change, body: section, source: "task_doc", ftime: ftime})
	}
	return entries, nil
}

// topicChange extracts the feature name from an "odd/<feature>/retrospective"
// topic title.
func topicChange(title string) string {
	return strings.TrimSuffix(strings.TrimPrefix(title, "odd/"), "/retrospective")
}

// ResolveBody resolves the retro body to persist from explicit body/body-file,
// optionally extracting ONLY the verification domain (Verification Gaps +
// Verify-Phase Incidents). Returns an error when nothing would persist.
func ResolveBody(body, bodyFile string, verifyDomain bool) (string, error) {
	b, err := resolveBody(body, bodyFile)
	if err != nil {
		return "", err
	}
	if !verifyDomain {
		return b, nil
	}
	filtered := ExtractVerifyDomain(b)
	if strings.TrimSpace(filtered) == "" {
		return "", fmt.Errorf("--verify-domain found no Verification Gaps / Verify-Phase Incidents in body")
	}
	return filtered, nil
}

type retroEntry struct {
	change string
	body   string
	source string
	ftime  time.Time
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

	var entriesOut []RetroEntry
	for _, e := range sorted {
		body := e.body
		if verifyDomain {
			body = ExtractVerifyDomain(body)
		}
		body = scrub.Scrub(body)
		lines := strings.Count(body, "\n") + 1
		entriesOut = append(entriesOut, RetroEntry{
			Change: e.change,
			Body:   body,
			Lines:  lines,
			Source: e.source,
		})
	}
	return &Precis{Count: len(entriesOut), Retros: entriesOut}
}

// ExtractVerifyDomain filters a retro/verify-report body down to its
// verification domain: the "Verification Gaps" and "Verify-Phase Incidents"
// sections (headings plus their content), ending at the next unrelated H2.
func ExtractVerifyDomain(body string) string {
	var out strings.Builder
	inSection := false
	sections := []string{"verification gaps", "verify-phase incidents"}
	for _, line := range strings.Split(body, "\n") {
		lower := strings.ToLower(line)
		for _, s := range sections {
			if strings.Contains(lower, s) {
				inSection = true
				break
			}
		}
		if inSection && strings.HasPrefix(line, "## ") && !strings.Contains(lower, "verification") && !strings.Contains(lower, "incident") {
			inSection = false
		}
		if inSection {
			out.WriteString(line + "\n")
		}
	}
	return strings.TrimSpace(out.String())
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

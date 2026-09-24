// Package engram provides a subprocess-only adapter to the engram CLI (v2).
// It never writes the engram DB directly: save/search go through `engram`
// subprocesses only. Output parsing targets v2.0.0 block format:
//
//	[1] #680 (discovery) — Auditoría sdd-own-skills vs gentle-ai 2.9.1
//	    **What**: ...
//	    2026-09-15 18:03:49 | project: sdd-own-skills | scope: project
package engram

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const (
	defaultProject = "sdd-own-skills"
	defaultScope   = "project"
)

// SearchResult holds one engram search result.
type SearchResult struct {
	ID      int       `json:"id"`
	Title   string    `json:"title"`
	Content string    `json:"content"`
	Type    string    `json:"type"`
	Time    time.Time `json:"time"`
}

var (
	// blockRe matches a v2 result header: "[1] #680 (discovery) — Title".
	blockRe = regexp.MustCompile(`^\[(\d+)\] #(\d+) \((\w+)\) — (.+)$`)
	// footerRe matches the closing footer of a result block:
	// "2026-09-15 18:03:49 | project: ... | scope: ...".
	footerRe = regexp.MustCompile(`^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \| project:`)
)

// Save invokes `engram save <title> <content> --type --project --scope
// --topic` as a subprocess. The title doubles as the topic key so search
// output carries the topic pattern; v2 topic-key upsert makes save idempotent
// per topic. Returns an error if the engram CLI is unavailable or save fails.
func Save(topic, body, typ string) error {
	if _, err := exec.LookPath("engram"); err != nil {
		return fmt.Errorf("engram CLI not found: %w", err)
	}
	// Flags first, then a `--` separator: ledger bodies legitimately start
	// with "- [Retro …]" and cobra would otherwise treat them as flags.
	args := []string{"save", "--type", typ, "--project", defaultProject, "--scope", defaultScope, "--topic", topic, "--", topic, body}
	out, err := exec.Command("engram", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("engram save failed: %s: %w", cleanCLIError(string(out)), err)
	}
	return nil
}

// cleanCLIError reduces raw engram CLI output to the meaningful error line:
// the first line starting with "engram:" (the CLI's own message) when present,
// otherwise the last non-empty line. Banner noise ("Update available:",
// "To update:", usage text) is dropped so callers see the real reason.
func cleanCLIError(out string) string {
	lines := strings.Split(out, "\n")
	var lastNonEmpty string
	for _, l := range lines {
		t := strings.TrimSpace(l)
		if t == "" {
			continue
		}
		lastNonEmpty = t
		if strings.HasPrefix(t, "engram:") {
			return t
		}
	}
	return lastNonEmpty
}

// Search invokes `engram search <query> [--limit] [--project] [--scope]` and
// parses the v2 block output. Exit 0 with zero results is not an error.
func Search(query string, limit int) ([]SearchResult, error) {
	if _, err := exec.LookPath("engram"); err != nil {
		return nil, fmt.Errorf("engram CLI not found: %w", err)
	}
	args := []string{"search", query, "--limit", strconv.Itoa(limit), "--project", defaultProject, "--scope", defaultScope}
	out, err := exec.Command("engram", args...).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("engram search failed: %s: %w", cleanCLIError(string(out)), err)
	}
	return parseSearchOutput(string(out)), nil
}

// IsAvailable reports whether the engram CLI is on PATH.
func IsAvailable() bool {
	_, err := exec.LookPath("engram")
	return err == nil
}

// parseSearchOutput parses v2 search output: one block per result starting
// with "[N] #<id> (<type>) — <title>", followed by indented content lines and
// closed by a "timestamp | project: ..." footer. Banner lines ("Update
// available:", "Found N memories:", …) never match a block start.
func parseSearchOutput(out string) []SearchResult {
	var results []SearchResult
	var cur *SearchResult
	for _, line := range strings.Split(out, "\n") {
		trimmed := strings.TrimSpace(line)
		if m := blockRe.FindStringSubmatch(trimmed); m != nil {
			if cur != nil {
				results = append(results, *cur)
			}
			id, _ := strconv.Atoi(m[2])
			cur = &SearchResult{ID: id, Title: m[4], Type: m[3]}
			continue
		}
		if cur == nil {
			continue
		}
		if footerRe.MatchString(trimmed) {
			const layout = "2006-01-02 15:04:05"
			if len(trimmed) >= len(layout) {
				if t, err := time.Parse(layout, trimmed[:len(layout)]); err == nil {
					cur.Time = t
				}
			}
			results = append(results, *cur)
			cur = nil
			continue
		}
		if strings.HasPrefix(line, "    ") {
			cur.Content += strings.TrimPrefix(line, "    ") + "\n"
			continue
		}
		// Non-indented, non-footer line inside a block: close the block
		// defensively rather than merging unrelated output into content.
		results = append(results, *cur)
		cur = nil
	}
	if cur != nil {
		results = append(results, *cur)
	}
	return results
}

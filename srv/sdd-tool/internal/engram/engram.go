// Package engram provides a subprocess-only adapter to the engram CLI.
// It never writes ~/.engram/engram.db directly.
// Save parses #<id> from stdout; search filters by title prefix.
package engram

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// SearchResult holds one engram search result.
type SearchResult struct {
	ID      int       `json:"id"`
	Title   string    `json:"title"`
	Content string    `json:"content"`
	Type    string    `json:"type"`
	Time    time.Time `json:"time"`
}

var idRe = regexp.MustCompile(`#(\d+)`)

// Save invokes `engram save` subprocess. Parses #<id> from stdout.
// Returns error if engram is not available or save fails.
func Save(topic, body, typ string) error {
	args := []string{"save", topic, body, "--type", typ, "--project", "sdd-own-skills", "--scope", "project", "--topic", topic}
	out, err := exec.Command("engram", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("engram save failed: %s: %w", strings.TrimSpace(string(out)), err)
	}
	// Parse #<id> from stdout
	m := idRe.FindStringSubmatch(string(out))
	if m == nil {
		return fmt.Errorf("engram save returned no observation id in output: %s", strings.TrimSpace(string(out)))
	}
	return nil
}

// Search invokes `engram search` and returns matching results.
func Search(query string, limit int) ([]SearchResult, error) {
	args := []string{"search", query, "--project", "sdd-own-skills", "--scope", "project", "--limit", strconv.Itoa(limit)}
	out, err := exec.Command("engram", args...).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("engram search failed: %s: %w", strings.TrimSpace(string(out)), err)
	}
	return parseSearchOutput(string(out)), nil
}

// Timeline verifies an observation id exists via `engram timeline <id>`.
func Timeline(id int) error {
	out, err := exec.Command("engram", "timeline", strconv.Itoa(id)).CombinedOutput()
	if err != nil {
		return fmt.Errorf("engram timeline %d failed: %s: %w", id, strings.TrimSpace(string(out)), err)
	}
	return nil
}

func parseSearchOutput(out string) []SearchResult {
	var results []SearchResult
	lines := strings.Split(out, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Try to parse: #<id>  <title>  (<type>)  <time>
		m := idRe.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		id, _ := strconv.Atoi(m[1])
		rest := strings.TrimSpace(line[len(m[0]):])
		parts := strings.SplitN(rest, "  ", 3)
		title := ""
		typ := ""
		if len(parts) > 0 {
			title = parts[0]
		}
		if len(parts) > 1 {
			typ = strings.Trim(parts[1], "()")
		}
		results = append(results, SearchResult{
			ID:    id,
			Title: title,
			Type:  typ,
		})
	}
	return results
}

// IsAvailable checks if the engram CLI is accessible.
func IsAvailable() bool {
	_, err := exec.LookPath("engram")
	return err == nil
}

package engram

import (
	"strings"
	"testing"
	"time"
)

// realV2Sample mirrors actual `engram search retrospective` output (v2.0.0),
// including the update banner and the two observation shapes observed live.
const realV2Sample = `Update available: 2.0.0 -> 2.1.0
To update:
  brew update && brew upgrade engram
  or: go install github.com/Gentleman-Programming/engram/v2/cmd/engram@latest

Found 2 memories:

[1] #680 (discovery) — Auditoría sdd-own-skills vs gentle-ai 2.9.1: dispatcher guard endurecido no espejado
    **What**: Auditoría read-only del repo sdd-own-skills contra gentle-ai 2.9.1 y main (2026-09-15).
    2026-09-15 18:03:49 | project: sdd-own-skills | scope: project

[2] #405 (architecture) — Migrated SDD-own install model to ~/.config/sdd-own canonical originals
    **What**: Migrated sync-skills.sh + setup.sh to the approved target model.
    **Why**: Canonical originals remove replication drift.
    2026-09-06 23:29:42 | project: sdd-own-skills | scope: project
`

func TestParseSearchOutputBlocks(t *testing.T) {
	got := parseSearchOutput(realV2Sample)
	if len(got) != 2 {
		t.Fatalf("expected 2 results, got %d", len(got))
	}
	first := got[0]
	if first.ID != 680 {
		t.Fatalf("first ID: got %d, want 680", first.ID)
	}
	if first.Type != "discovery" {
		t.Fatalf("first type: got %q, want discovery", first.Type)
	}
	if !strings.Contains(first.Title, "dispatcher guard endurecido") {
		t.Fatalf("first title not captured: %q", first.Title)
	}
	if !strings.Contains(first.Content, "**What**: Auditoría read-only") {
		t.Fatalf("first content not captured: %q", first.Content)
	}
	wantTime := time.Date(2026, 9, 15, 18, 3, 49, 0, time.UTC)
	if !first.Time.Equal(wantTime) {
		t.Fatalf("first time: got %v, want %v", first.Time, wantTime)
	}
	second := got[1]
	if second.ID != 405 || second.Type != "architecture" {
		t.Fatalf("second block wrong: %+v", second)
	}
	if !strings.Contains(second.Content, "**Why**") {
		t.Fatalf("second multi-line content not captured: %q", second.Content)
	}
}

func TestParseSearchOutputBannerLinesIgnored(t *testing.T) {
	got := parseSearchOutput(realV2Sample)
	for _, r := range got {
		if strings.Contains(r.Content, "Update available") || strings.Contains(r.Content, "brew update") {
			t.Fatalf("banner leaked into content: %q", r.Content)
		}
	}
}

func TestParseSearchOutputEmpty(t *testing.T) {
	if got := parseSearchOutput(""); len(got) != 0 {
		t.Fatalf("expected 0 results for empty output, got %d", len(got))
	}
	if got := parseSearchOutput("No memories found for: \"zzz\""); len(got) != 0 {
		t.Fatalf("expected 0 results for no-memories output, got %d", len(got))
	}
}

func TestParseSearchOutputNonIndentedGarbageClosesBlock(t *testing.T) {
	// A non-indented line between blocks must not merge into the previous
	// block's content — the block closes defensively.
	out := "[1] #1 (learning) — one\n    content line\nSOME RANDOM LINE\n[2] #2 (decision) — two\n    2026-09-15 10:00:00 | project: sdd-own-skills | scope: project"
	got := parseSearchOutput(out)
	if len(got) != 2 {
		t.Fatalf("expected 2 results, got %d: %+v", len(got), got)
	}
	if strings.Contains(got[0].Content, "RANDOM") {
		t.Fatalf("garbage merged into first block: %q", got[0].Content)
	}
}

func TestCleanCLIErrorPicksEngramLine(t *testing.T) {
	out := "Update available: 2.0.0 -> 2.1.0\nTo update:\n  brew update\n\nengram: session ownership does not match write project: x\n"
	if got := cleanCLIError(out); !strings.Contains(got, "session ownership") || strings.Contains(got, "Update available") {
		t.Fatalf("expected the engram: line, got %q", got)
	}
}

func TestCleanCLIErrorFallsBackToLastNonEmpty(t *testing.T) {
	out := "Update available: 2.0.0 -> 2.1.0\n\nusage: engram save <title> <content> [flags]\n"
	if got := cleanCLIError(out); got != "usage: engram save <title> <content> [flags]" {
		t.Fatalf("expected usage fallback, got %q", got)
	}
}

func TestCleanCLIErrorEmpty(t *testing.T) {
	if got := cleanCLIError(""); got != "" {
		t.Fatalf("expected empty, got %q", got)
	}
}

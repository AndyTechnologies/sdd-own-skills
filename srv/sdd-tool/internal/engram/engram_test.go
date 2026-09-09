package engram

import (
	"strings"
	"testing"
)

func TestParseSearchOutput(t *testing.T) {
	input := `#42  sdd/tooling/retrospective  (learning)  2026-09-09T10:00:00Z
#43  sdd/other-change/retrospective  (learning)  2026-09-09T09:00:00Z
#44  random observation  (decision)  2026-09-09T08:00:00Z`
	results := parseSearchOutput(input)
	if len(results) != 3 {
		t.Fatalf("expected 3 results, got %d", len(results))
	}
	if results[0].ID != 42 {
		t.Fatalf("expected first ID 42, got %d", results[0].ID)
	}
	if results[0].Title != "sdd/tooling/retrospective" {
		t.Fatalf("expected title 'sdd/tooling/retrospective', got %q", results[0].Title)
	}
	if results[0].Type != "learning" {
		t.Fatalf("expected type 'learning', got %q", results[0].Type)
	}
	if results[2].Title != "random observation" {
		t.Fatalf("expected title 'random observation', got %q", results[2].Title)
	}
}

func TestParseSearchOutputEmpty(t *testing.T) {
	results := parseSearchOutput("")
	if len(results) != 0 {
		t.Fatalf("expected 0 results for empty input, got %d", len(results))
	}
}

func TestTitleFilterRetrospective(t *testing.T) {
	// Simulate the title filtering logic from engramStore.Lookup
	results := []SearchResult{
		{ID: 1, Title: "sdd/tooling/retrospective", Content: "body1"},
		{ID: 2, Title: "sdd/other-change/retrospective", Content: "body2"},
		{ID: 3, Title: "random observation", Content: "body3"},
		{ID: 4, Title: "sdd/third/retrospective", Content: "body4"},
	}

	var filtered []SearchResult
	for _, r := range results {
		if !strings.HasPrefix(r.Title, "sdd/") || !strings.HasSuffix(r.Title, "/retrospective") {
			continue
		}
		filtered = append(filtered, r)
	}

	if len(filtered) != 3 {
		t.Fatalf("expected 3 filtered results (sdd/*/retrospective), got %d", len(filtered))
	}
	// The random observation should be excluded
	for _, r := range filtered {
		if r.Title == "random observation" {
			t.Fatal("random observation should have been filtered out")
		}
	}
}

func TestTitleFilterByChangeName(t *testing.T) {
	results := []SearchResult{
		{ID: 1, Title: "sdd/tooling/retrospective", Content: "body1"},
		{ID: 2, Title: "sdd/other-change/retrospective", Content: "body2"},
	}

	changeFilter := "tooling"
	var filtered []SearchResult
	for _, r := range results {
		if !strings.HasPrefix(r.Title, "sdd/") || !strings.HasSuffix(r.Title, "/retrospective") {
			continue
		}
		// extract change from title: sdd/{change}/retrospective
		parts := strings.Split(r.Title, "/")
		if len(parts) >= 2 {
			change := parts[1]
			if changeFilter != "" && change != changeFilter {
				continue
			}
		}
		filtered = append(filtered, r)
	}

	if len(filtered) != 1 {
		t.Fatalf("expected 1 filtered result for change=%q, got %d", changeFilter, len(filtered))
	}
	if filtered[0].ID != 1 {
		t.Fatalf("expected ID 1, got %d", filtered[0].ID)
	}
}

package retro

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestResolveBodyFromFlag(t *testing.T) {
	body, err := resolveBody("hello world", "")
	if err != nil {
		t.Fatal(err)
	}
	if body != "hello world" {
		t.Fatalf("got %q, want %q", body, "hello world")
	}
}

func TestResolveBodyFromFile(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "body.md")
	os.WriteFile(f, []byte("from file"), 0o644)
	body, err := resolveBody("", f)
	if err != nil {
		t.Fatal(err)
	}
	if body != "from file" {
		t.Fatalf("got %q, want %q", body, "from file")
	}
}

func TestResolveBodyMissing(t *testing.T) {
	_, err := resolveBody("", "")
	if err == nil {
		t.Fatal("expected error when both body and body-file are empty")
	}
}

func TestResolvePersistBodyVerifyDomainFiltersBody(t *testing.T) {
	body := `## What Worked

- everything

## Verification Gaps

- gap one

## Verify-Phase Incidents

- incident one
`
	got, err := ResolvePersistBody("test-change", body, "", true)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "## Verification Gaps") || !strings.Contains(got, "- gap one") {
		t.Fatalf("missing Verification Gaps in filtered body: %q", got)
	}
	if !strings.Contains(got, "## Verify-Phase Incidents") || !strings.Contains(got, "- incident one") {
		t.Fatalf("missing Verify-Phase Incidents in filtered body: %q", got)
	}
	if strings.Contains(got, "What Worked") {
		t.Fatalf("non-verification content leaked through: %q", got)
	}
}

func TestResolvePersistBodyVerifyDomainNoSections(t *testing.T) {
	_, err := ResolvePersistBody("test-change", "## What Worked\n\nnothing special\n", "", true)
	if err == nil {
		t.Fatal("expected error when body has no verification-domain sections")
	}
}

func TestResolvePersistBodyNonVerifyDomain(t *testing.T) {
	got, err := ResolvePersistBody("test-change", "plain body", "", false)
	if err != nil {
		t.Fatal(err)
	}
	if got != "plain body" {
		t.Fatalf("got %q, want %q", got, "plain body")
	}
}

func TestResolvePersistBodyVerifyDomainFromFile(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "body.md")
	os.WriteFile(f, []byte("## Verification Gaps\n\n- from file gap\n"), 0o644)
	got, err := ResolvePersistBody("test-change", "", f, true)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "- from file gap") {
		t.Fatalf("file body not filtered/persisted: %q", got)
	}
}

func TestResolvePersistBodyVerifyDomainRequiresSource(t *testing.T) {
	_, err := ResolvePersistBody("test-change", "", "", true)
	if err == nil {
		t.Fatal("expected error when verify-domain has no body and no repo verify-report")
	}
}

func TestDeriveVerifyDomainFromReportLiteralSections(t *testing.T) {
	report := `## Verification Report

## Verification Gaps

- gap from literal

## Verify-Phase Incidents

- incident from literal
`
	got := deriveVerifyDomainFromReport(report)
	if !strings.Contains(got, "- gap from literal") || !strings.Contains(got, "- incident from literal") {
		t.Fatalf("literal sections not preserved: %q", got)
	}
}

func TestDeriveVerifyDomainFromReportIssuesFound(t *testing.T) {
	report := `## Verification Report

Some preamble.

### Issues Found

**CRITICAL**: None.

1. **WARNING** — dashboard envelope subset is open.
2. **SUGGESTION** — add over-cap test.

Prior CRITICAL-1 → CLOSED with evidence.

### Verdict

PASS WITH WARNINGS.
`
	got := deriveVerifyDomainFromReport(report)
	if !strings.Contains(got, "## Verification Gaps") || !strings.Contains(got, "WARNING") || !strings.Contains(got, "SUGGESTION") {
		t.Fatalf("Issues Found warnings/suggestions not mapped to gaps: %q", got)
	}
	if !strings.Contains(got, "## Verify-Phase Incidents") || !strings.Contains(got, "CRITICAL") {
		t.Fatalf("Issues Found criticals not mapped to incidents: %q", got)
	}
	if strings.Contains(got, "Verdict") || strings.Contains(got, "preamble") {
		t.Fatalf("non-issue content leaked: %q", got)
	}
}

func TestDeriveVerifyDomainFromReportEmpty(t *testing.T) {
	got := deriveVerifyDomainFromReport("## Verification Report\n\nnothing here\n")
	if got != "" {
		t.Fatalf("expected empty derivation, got %q", got)
	}
}

func TestDeriveVerifyDomainFromReportKeywordInTableRow(t *testing.T) {
	// Keyword substrings inside a table row must NOT activate a section and
	// must NOT drag the whole document into the derived body.
	report := `## Verification Report

| Scenario | Result |
|----------|--------|
| Retro precis mentions verify-phase incidents inside a row | ⚠️ PARTIAL |
| Retro precis mentions verification gaps inside a row | ✅ COMPLIANT |

### Issues Found

1. **WARNING** — real gap one.
2. **SUGGESTION** — real suggestion.

### Verdict

PASS WITH WARNINGS.
`
	got := deriveVerifyDomainFromReport(report)
	if strings.Contains(got, "table row") || strings.Contains(got, "⚠️") {
		t.Fatalf("table-row keyword leaked into derived body: %q", got)
	}
	if !strings.Contains(got, "real gap one") || !strings.Contains(got, "real suggestion") {
		t.Fatalf("Issues Found mapping missing: %q", got)
	}
}

func TestExtractH2SectionsWholeHeadingOnly(t *testing.T) {
	body := "## Verification Gaps\n\n- gap one\n\n## What Worked\n\n- fine\n\n## Verify-Phase Incidents\n\n- incident one\n"
	sections := extractH2Sections(body, "Verification Gaps", "Verify-Phase Incidents")
	if len(sections) != 2 {
		t.Fatalf("want 2 sections, got %d: %q", len(sections), sections)
	}
	if !strings.Contains(sections[0], "- gap one") || strings.Contains(sections[0], "What Worked") {
		t.Fatalf("first section wrong: %q", sections[0])
	}
	if !strings.Contains(sections[1], "- incident one") {
		t.Fatalf("second section wrong: %q", sections[1])
	}
}

func TestExtractH2SectionsNoMatch(t *testing.T) {
	sections := extractH2Sections("## What Worked\n\n- fine\n", "Verification Gaps")
	if len(sections) != 0 {
		t.Fatalf("expected no sections, got %d", len(sections))
	}
}

func TestNoneStorePersist(t *testing.T) {
	s, err := NewStore("none")
	if err != nil {
		t.Fatal(err)
	}
	err = s.Persist("test-change", "verify", "body text", "")
	if err != nil {
		t.Fatal(err)
	}
}

func TestNoneStoreLookup(t *testing.T) {
	s, err := NewStore("none")
	if err != nil {
		t.Fatal(err)
	}
	p, err := s.Lookup("", false)
	if err != nil {
		t.Fatal(err)
	}
	if p.Count != 0 {
		t.Fatalf("expected 0 retros, got %d", p.Count)
	}
}

func TestInvalidMode(t *testing.T) {
	_, err := NewStore("bogus")
	if err == nil {
		t.Fatal("expected error for invalid mode")
	}
}

func TestPrecisText(t *testing.T) {
	p := &Precis{
		Count: 2,
		Retros: []RetroEntry{
			{Change: "foo", Body: "line1\nline2", Lines: 2, Source: "openspec"},
			{Change: "bar", Body: "body here", Lines: 1, Source: "engram"},
		},
	}
	text := p.Text()
	if text == "" {
		t.Fatal("expected non-empty text")
	}
	if !strings.Contains(text, "Retrospectives (2)") {
		t.Fatalf("expected count header, got: %s", text)
	}
}

func TestExtractChangeFromTopic(t *testing.T) {
	got := extractChangeFromTopic("sdd/my-change/retrospective")
	if got != "my-change" {
		t.Fatalf("got %q, want %q", got, "my-change")
	}
}

func TestStripDatePrefix(t *testing.T) {
	cases := []struct{ in, want string }{
		{"2026-09-09-test-x", "test-x"},
		{"test-x", "test-x"},
		{"2026-01-01-foo", "foo"},
		{"my-change-name", "my-change-name"},
		{"x", "x"},
	}
	for _, c := range cases {
		if got := stripDatePrefix(c.in); got != c.want {
			t.Errorf("stripDatePrefix(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestExtractChangeFromPathActive(t *testing.T) {
	base := filepath.Join("openspec", "changes")
	path := filepath.Join(base, "test-x", "retrospective.md")
	if got := extractChangeFromPath(path, base); got != "test-x" {
		t.Fatalf("active path: got %q, want %q", got, "test-x")
	}
}

func TestExtractChangeFromPathArchiveSinglePart(t *testing.T) {
	// Archive scan: baseDir = openspec/changes/archive, rel = 1 part
	// ("2026-09-09-test-x") — must normalize to "test-x".
	base := filepath.Join("openspec", "changes", "archive")
	path := filepath.Join(base, "2026-09-09-test-x", "retrospective.md")
	if got := extractChangeFromPath(path, base); got != "test-x" {
		t.Fatalf("archive 1-part path: got %q, want %q", got, "test-x")
	}
}

func TestExtractChangeFromPathArchiveTwoPart(t *testing.T) {
	// Active scan walking into archive: baseDir = openspec/changes, rel = 2
	// parts ("archive/2026-09-09-test-x") — must normalize to "test-x".
	base := filepath.Join("openspec", "changes")
	path := filepath.Join(base, "archive", "2026-09-09-test-x", "retrospective.md")
	if got := extractChangeFromPath(path, base); got != "test-x" {
		t.Fatalf("archive 2-part path: got %q, want %q", got, "test-x")
	}
}

func TestScanDirSkipsArchiveSubdirAndDedupes(t *testing.T) {
	root := t.TempDir()
	changes := filepath.Join(root, "openspec", "changes")
	archive := filepath.Join(changes, "archive")
	if err := os.MkdirAll(filepath.Join(changes, "my-change"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(archive, "2026-09-09-my-change"), 0o755); err != nil {
		t.Fatal(err)
	}
	body := []byte("## What Worked\n\nAll good.\n")
	if err := os.WriteFile(filepath.Join(changes, "my-change", "retrospective.md"), body, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(archive, "2026-09-09-my-change", "retrospective.md"), body, 0o644); err != nil {
		t.Fatal(err)
	}

	// Active scan must NOT see the archived retro (no double match).
	active := scanDir(changes, "", "openspec")
	if len(active) != 1 {
		t.Fatalf("active scan: got %d entries, want 1 (archive subdir must be skipped)", len(active))
	}
	if active[0].change != "my-change" {
		t.Fatalf("active scan: change %q, want %q", active[0].change, "my-change")
	}

	// Archive scan finds the archived retro with the date prefix stripped.
	archived := scanDir(archive, "", "openspec")
	if len(archived) != 1 {
		t.Fatalf("archive scan: got %d entries, want 1", len(archived))
	}
	if archived[0].change != "my-change" {
		t.Fatalf("archive scan: change %q, want %q", archived[0].change, "my-change")
	}

	// Change-filtered lookup resolves the archived retro.
	filtered := scanDir(archive, "my-change", "openspec")
	if len(filtered) != 1 || filtered[0].change != "my-change" {
		t.Fatalf("archive change-filtered: got %d entries %+v, want exactly my-change", len(filtered), filtered)
	}

	// Combined precis: active + archived retros for the same change dedupe to ONE.
	precis := buildPrecis(append(active, archived...), false)
	if precis.Count != 1 {
		t.Fatalf("dedupe: precis count %d, want 1", precis.Count)
	}
	if precis.Retros[0].Change != "my-change" {
		t.Fatalf("dedupe: change %q, want %q", precis.Retros[0].Change, "my-change")
	}
}

func containsSubstr(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

package retro

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
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

func TestResolveBodyVerifyDomainFilters(t *testing.T) {
	body := `## What Worked

- everything

## Verification Gaps

- gap one

## Verify-Phase Incidents

- incident one
`
	got, err := ResolveBody(body, "", true)
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

func TestResolveBodyVerifyDomainNoSections(t *testing.T) {
	_, err := ResolveBody("## What Worked\n\nnothing special\n", "", true)
	if err == nil {
		t.Fatal("expected error when body has no verification-domain sections")
	}
}

func TestResolveBodyNonVerifyDomain(t *testing.T) {
	got, err := ResolveBody("plain body", "", false)
	if err != nil {
		t.Fatal(err)
	}
	if got != "plain body" {
		t.Fatalf("got %q, want %q", got, "plain body")
	}
}

func TestSplitBody(t *testing.T) {
	summary, detail := SplitBody("\n\nFirst line\n\nRest one\nRest two\n")
	if summary != "First line" {
		t.Fatalf("summary: got %q", summary)
	}
	if detail != "Rest one\nRest two" {
		t.Fatalf("detail: got %q", detail)
	}
	single, d := SplitBody("only line")
	if single != "only line" || d != "" {
		t.Fatalf("single-line: summary=%q detail=%q", single, d)
	}
	empty, e := SplitBody("   \n  \n")
	if empty != "" || e != "" {
		t.Fatalf("blank body: summary=%q detail=%q", empty, e)
	}
}

func TestBuildLedgerEntry(t *testing.T) {
	got := BuildLedgerEntry("verify", "abc123", "root and task doc verified", "line two")
	want := "- [Retro verify] abc123: root and task doc verified\n  line two"
	if got != want {
		t.Fatalf("got:\n%q\nwant:\n%q", got, want)
	}
	flat := BuildLedgerEntry("verify", "abc123", "summary only", "")
	if flat != "- [Retro verify] abc123: summary only" {
		t.Fatalf("flat entry wrong: %q", flat)
	}
}

func TestHasMarker(t *testing.T) {
	ledger := "- [Retro explore] 111: first\n- [Retro verify] abc123: second\n  detail line"
	if !HasMarker(ledger, "verify", "abc123") {
		t.Fatal("expected marker present")
	}
	if HasMarker(ledger, "verify", "zzz999") {
		t.Fatal("expected different ref NOT present")
	}
	if HasMarker(ledger, "apply", "abc123") {
		t.Fatal("expected different phase NOT present")
	}
	if HasMarker("", "verify", "abc123") {
		t.Fatal("empty ledger must not contain markers")
	}
}

func TestAppendToLedger(t *testing.T) {
	got := AppendToLedger("- [Retro explore] 111: first", "- [Retro verify] abc123: second")
	want := "- [Retro explore] 111: first\n- [Retro verify] abc123: second"
	if got != want {
		t.Fatalf("got:\n%q\nwant:\n%q", got, want)
	}
	if first := AppendToLedger("", "- [Retro verify] abc123: first"); first != "- [Retro verify] abc123: first" {
		t.Fatalf("empty start wrong: %q", first)
	}
}

func TestAppendLedgerToDocFresh(t *testing.T) {
	got := AppendLedgerToDoc("# Works-tool Re-wire\n\nSome body.\n", "- [Retro verify] abc123: ok")
	if !strings.Contains(got, "## Retros") {
		t.Fatalf("Retros section missing:\n%s", got)
	}
	if !strings.HasSuffix(got, "\n- [Retro verify] abc123: ok\n") {
		t.Fatalf("entry not appended at end:\n%s", got)
	}
	if strings.Count(got, "## Retros") != 1 {
		t.Fatalf("expected exactly one Retros heading:\n%s", got)
	}
}

func TestAppendLedgerToDocExistingSectionAtEOF(t *testing.T) {
	doc := "# Title\n\n## What Worked\n\n- x\n\n## Retros\n\n- [Retro explore] 111: first\n"
	got := AppendLedgerToDoc(doc, "- [Retro verify] abc123: second\n  detail")
	if !strings.Contains(got, "- [Retro explore] 111: first\n- [Retro verify] abc123: second\n  detail") {
		t.Fatalf("entry not appended inside Retros section:\n%s", got)
	}
}

func TestAppendLedgerToDocExistingSectionWithNextHeading(t *testing.T) {
	doc := "# Title\n\n## Retros\n\n- [Retro explore] 111: first\n\n## Risks\n\n- none\n"
	got := AppendLedgerToDoc(doc, "- [Retro verify] abc123: second\n  detail")
	// Entry must be inserted BEFORE the Risks heading, still under Retros.
	risks := strings.Index(got, "## Risks")
	explore := strings.Index(got, "[Retro explore]")
	verify := strings.Index(got, "[Retro verify]")
	if !(explore < verify && verify < risks) {
		t.Fatalf("entry misplaced (explore=%d verify=%d risks=%d):\n%s", explore, verify, risks, got)
	}
	if strings.Contains(got[risks:], "[Retro verify]") {
		t.Fatalf("entry leaked into Risks section:\n%s", got)
	}
}

func TestTopicChange(t *testing.T) {
	if got := topicChange("odd/my-change/retrospective"); got != "my-change" {
		t.Fatalf("got %q, want my-change", got)
	}
}

func TestPrecisText(t *testing.T) {
	p := &Precis{
		Count: 2,
		Retros: []RetroEntry{
			{Change: "foo", Body: "line1\nline2", Lines: 2, Source: "engram"},
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

func TestBuildPrecisDedupesByChangeNewestWins(t *testing.T) {
	old := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	newer := old.Add(24 * time.Hour)
	entries := []retroEntry{
		{change: "feat-x", body: "old body", source: "engram", ftime: old},
		{change: "feat-x", body: "new body", source: "engram", ftime: newer},
	}
	p := buildPrecis(entries, false)
	if p.Count != 1 {
		t.Fatalf("dedupe failed: count %d", p.Count)
	}
	if !strings.Contains(p.Retros[0].Body, "new body") {
		t.Fatalf("newest entry not kept: %+v", p.Retros[0])
	}
}

func TestExtractVerifyDomain(t *testing.T) {
	body := `## What Worked

- fine

## Verification Gaps

- gap one

## Verify-Phase Incidents

- incident one

## Risks

- none
`
	got := ExtractVerifyDomain(body)
	if !strings.Contains(got, "## Verification Gaps") || !strings.Contains(got, "- gap one") {
		t.Fatalf("gaps missing: %q", got)
	}
	if !strings.Contains(got, "## Verify-Phase Incidents") || !strings.Contains(got, "- incident one") {
		t.Fatalf("incidents missing: %q", got)
	}
	if strings.Contains(got, "Risks") || strings.Contains(got, "What Worked") {
		t.Fatalf("non-verification content leaked: %q", got)
	}
}

func TestExtractRetrosSection(t *testing.T) {
	doc := "# Feature\n\n## Retros\n\n- [Retro apply] abc123: Applied\n  detail line\n\n## Risk Mitigation\n\n- none\n"
	got, ok := extractRetrosSection(doc)
	if !ok {
		t.Fatal("section not found")
	}
	if !strings.Contains(got, "- [Retro apply] abc123: Applied") {
		t.Fatalf("entry missing: %q", got)
	}
	if !strings.Contains(got, "detail line") {
		t.Fatalf("detail line missing: %q", got)
	}
	if strings.Contains(got, "Risk Mitigation") {
		t.Fatalf("next section leaked: %q", got)
	}
}

func TestExtractRetrosSectionAtEOF(t *testing.T) {
	doc := "# Feature\n\n## Retros\n\n- [Retro verify] def456: Verified\n"
	got, ok := extractRetrosSection(doc)
	if !ok {
		t.Fatal("section not found")
	}
	if !strings.Contains(got, "def456") {
		t.Fatalf("entry missing: %q", got)
	}
}

func TestExtractRetrosSectionAbsent(t *testing.T) {
	if _, ok := extractRetrosSection("# Feature\n\nNothing here.\n"); ok {
		t.Fatal("expected no section")
	}
}

func TestExtractRetrosSectionHeadingOnly(t *testing.T) {
	got, ok := extractRetrosSection("# Feature\n\n## Retros")
	if !ok {
		t.Fatal("section not found")
	}
	if strings.TrimSpace(got) != "" {
		t.Fatalf("expected empty section content, got %q", got)
	}
}

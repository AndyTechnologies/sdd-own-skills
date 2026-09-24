// Package scrub provides a single shared privacy scrubbing function used
// uniformly by incident summaries and retrospective bodies. It is pure:
// it never touches I/O and returns a scrubbed copy of its input.
//
// D3: ONE shared pure function Scrub(string) applied to incident summaries
// AND retro bodies (--body/--body-file). Retro bodies persist into Engram
// long-lived memory, so an unscubbed body is a durable secret leak.
package scrub

import (
	"regexp"
	"strings"
)

var (
	// GitHub token prefixes: ghp_ gho_ ghu_ ghs_ ghe_ github_pat_ + 20+ chars.
	githubToken = regexp.MustCompile(`(?i)(ghp_|gho_|ghu_|ghs_|ghe_|github_pat_)[A-Za-z0-9]{20,}`)

	// PEM private key blocks. (?s) makes . match newlines.
	pemBlock = regexp.MustCompile(`(?s)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----`)

	// Generic secret assignments: token|secret|api[_-]?key|password := or = value.
	secretAssign = regexp.MustCompile(`(?i)(token|secret|api[_-]?key|password)\s*[:=]\s*\S+`)

	// Absolute paths.
	absPath = regexp.MustCompile(`/[A-Za-z0-9_.\-/]+`)
)

const redacted = "[redacted]"

// Scrub returns a copy of s with secrets and absolute paths replaced by
// [redacted]. It is deterministic and pure. Order matters: longer/structured
// matches (PEM, tokens) are scrubbed first so partial patterns cannot leak.
func Scrub(s string) string {
	out := s
	out = pemBlock.ReplaceAllString(out, redacted)
	out = githubToken.ReplaceAllString(out, redacted)
	out = secretAssign.ReplaceAllString(out, redacted)
	out = absPath.ReplaceAllString(out, redacted)
	return strings.TrimSpace(out)
}

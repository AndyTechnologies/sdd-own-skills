package scrub

import "testing"

func TestScrubGitHubTokens(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"ghp", "token ghp_abcdefghijklmnopqrstuvwxyz12345678 end", "token [redacted] end"},
		{"gho", "gho_abcdefghijklmnopqrstuvwxyz12345678", "[redacted]"},
		{"ghu", "ghu_abcdefghijklmnopqrstuvwxyz12345678", "[redacted]"},
		{"ghs", "ghs_abcdefghijklmnopqrstuvwxyz12345678", "[redacted]"},
		{"ghe", "ghe_abcdefghijklmnopqrstuvwxyz12345678", "[redacted]"},
		{"github_pat", "github_pat_abcdefghijklmnopqrstuvwxy", "[redacted]"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := Scrub(tc.in); got != tc.want {
				t.Fatalf("Scrub(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestScrubPEM(t *testing.T) {
	in := "key: -----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA\n-----END RSA PRIVATE KEY-----"
	if got := Scrub(in); got != "key: [redacted]" {
		t.Fatalf("Scrub(PEM) = %q, want %q", got, "key: [redacted]")
	}
}

func TestScrubSecretAssign(t *testing.T) {
	cases := []struct{ in, want string }{
		{"password=sup3rsecret", "[redacted]"},
		{"secret: hunter2", "[redacted]"},
		{"api_key = abc123", "[redacted]"},
		{"api-key=xyz", "[redacted]"},
		{"token := green", "[redacted] green"},
	}
	for _, tc := range cases {
		if got := Scrub(tc.in); got != tc.want {
			t.Fatalf("Scrub(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestScrubAbsPath(t *testing.T) {
	in := "wrote to /home/andy/.config/other/file"
	if got := Scrub(in); got != "" {
		if got == in {
			t.Fatalf("Scrub did not redact abs path: %q", got)
		}
	}
}

func TestScrubPlainTextUntouched(t *testing.T) {
	in := "all good, no secrets here"
	if got := Scrub(in); got != in {
		t.Fatalf("Scrub(%q) = %q, want unchanged", in, got)
	}
}

func TestScrubEmpty(t *testing.T) {
	if got := Scrub(""); got != "" {
		t.Fatalf("Scrub(\"\") = %q, want empty", got)
	}
}

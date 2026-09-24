package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"works-tool/internal/envelope"
	"works-tool/internal/retro"
	"works-tool/internal/worktree"

	"github.com/spf13/cobra"
)

func newRetroCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "retro",
		Short: "Retro ledger: Engram primary, task-doc ## Retros appendix secondary",
	}
	cmd.AddCommand(newRetroPersistCmd())
	cmd.AddCommand(newRetroLookupCmd())
	return cmd
}

func newRetroPersistCmd() *cobra.Command {
	var (
		body, bodyFile, commitRef, feature, phase string
		verifyDomain, jsonOut                     bool
	)
	cmd := &cobra.Command{
		Use:   "persist",
		Short: "Record a retro ledger line: Engram primary, task-doc ## Retros appendix secondary",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if feature == "" || phase == "" {
				return retroInvalidArgs("persist: --feature and --phase are required", jsonOut)
			}
			resolved, err := retro.ResolveBody(body, bodyFile, verifyDomain)
			if err != nil {
				return retroFailOpen(feature, envelope.CodeInvalidArgs, "FAIL-OPEN: retro lost write — "+err.Error(), jsonOut)
			}
			ref, err := resolveCommitRef(commitRef)
			if err != nil {
				return retroFailOpen(feature, envelope.CodeInvalidArgs, "FAIL-OPEN: retro lost write — "+err.Error(), jsonOut)
			}
			summary, detail := retro.SplitBody(resolved)
			res, err := retro.Persist(feature, phase, ref, summary, detail)
			if err != nil {
				var unavailable *retro.ErrTaskDocUnavailable
				if errors.As(err, &unavailable) {
					// Secondary task-doc appendix lost → loud marker (D2) + exit 2.
					// The Engram write status decides the wording.
					var msg string
					if res != nil && res.EngramWritten {
						msg = fmt.Sprintf("FAIL-OPEN: retro persisted to Engram but task doc appendix lost — %v", err)
					} else {
						msg = fmt.Sprintf("FAIL-OPEN: retro write lost — task doc appendix lost: %v", err)
					}
					return retroFailOpen(feature, envelope.CodeWriteFailed, msg, jsonOut)
				}
				return retroFailOpen(feature, envelope.CodeWriteFailed, "FAIL-OPEN: retro lost write — "+err.Error(), jsonOut)
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, res))
			}
			if res.AlreadyRecorded {
				fmt.Printf("Retro already recorded: %s [%s] %s (no-op)\n", feature, phase, ref)
				return nil
			}
			if res.EngramError != "" {
				fmt.Fprintf(os.Stderr, "[warn] engram write rejected: %s (task-doc appendix recorded as secondary; Engram primary missing)\n", res.EngramError)
			}
			fmt.Printf("Retro recorded: %s [%s] %s (engram=%t task_doc=%t)\n", feature, phase, ref, res.EngramWritten, res.TaskDocAppended)
			return nil
		},
	}
	cmd.Flags().StringVar(&feature, "feature", "", "feature/change name (required)")
	cmd.Flags().StringVar(&phase, "phase", "", "ODD phase (required): explore|propose|design|apply|verify|archive")
	cmd.Flags().StringVar(&body, "body", "", "retro body text")
	cmd.Flags().StringVar(&bodyFile, "body-file", "", "path to retro body file")
	cmd.Flags().BoolVar(&verifyDomain, "verify-domain", false, "persist verification domain only (Verification Gaps + Verify-Phase Incidents)")
	cmd.Flags().StringVar(&commitRef, "commit-ref", "", "commit ref to record (defaults to git rev-parse HEAD at the repo root; required when not inside a repo)")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON result")
	return cmd
}

// retroInvalidArgs surfaces a persist usage error (missing required flag)
// and exits 1 — the envelope CodeInvalidArgs path; with --json the failure
// envelope goes to stdout.
func retroInvalidArgs(msg string, jsonOut bool) error {
	if jsonOut {
		_ = json.NewEncoder(os.Stdout).Encode(envelope.NewFailure("", envelope.CodeInvalidArgs, msg, false))
	} else {
		fmt.Fprintln(os.Stderr, msg)
	}
	os.Exit(1)
	return nil
}

// retroFailOpen surfaces a D2 loud FAIL-OPEN marker for a lost retro write
// and exits 2 (the write path failed; the orchestrator must notice). The
// marker prose always goes to stderr; with --json the machine-readable
// failure envelope (acta A10: {ok:false, error:{code, message, fail_open}})
// goes to stdout so callers can parse the outcome.
func retroFailOpen(feature, code, msg string, jsonOut bool) error {
	fmt.Fprintln(os.Stderr, msg)
	if jsonOut {
		_ = json.NewEncoder(os.Stdout).Encode(envelope.NewFailure(feature, code, msg, true))
	}
	os.Exit(2)
	return nil
}

// resolveCommitRef resolves the commit ref to record: an explicit
// --commit-ref, or `git rev-parse HEAD` at the filesystem walk-up repo root.
// This is the tool's ONLY sanctioned git subprocess (retro contract). A repo
// root failure with no explicit ref is an error (exit 2 path).
func resolveCommitRef(explicit string) (string, error) {
	if explicit != "" {
		return explicit, nil
	}
	root := worktree.RepoRootFromCwd()
	if root == "" {
		return "", fmt.Errorf("cannot resolve commit ref: not inside a git checkout and no --commit-ref given")
	}
	out, err := exec.Command("git", "-C", root, "rev-parse", "HEAD").CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("git rev-parse HEAD failed: %s", strings.TrimSpace(string(out)))
	}
	ref := strings.TrimSpace(string(out))
	if ref == "" {
		return "", fmt.Errorf("git rev-parse HEAD returned empty")
	}
	return ref, nil
}

func newRetroLookupCmd() *cobra.Command {
	var (
		feature      string
		verifyDomain bool
		jsonOut      bool
	)
	cmd := &cobra.Command{
		Use:   "lookup",
		Short: "Lookup retrospectives: Engram primary, task-doc ## Retros appendix secondary",
		RunE: func(cmd *cobra.Command, args []string) error {
			precis, err := retro.Lookup(feature, verifyDomain)
			if err != nil {
				fmt.Fprintf(os.Stderr, "[warn] retro lookup failed (fail-open): %v\n", err)
				return nil
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, precis))
			}
			if precis.Count == 0 {
				fmt.Println("No retrospectives found.")
				return nil
			}
			fmt.Println(precis.Text())
			return nil
		},
	}
	cmd.Flags().StringVar(&feature, "feature", "", "filter by feature/change name")
	cmd.Flags().BoolVar(&verifyDomain, "verify-domain", false, "extract only verification gaps and incidents")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}

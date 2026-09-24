package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

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
		body, bodyFile, commitRef string
		verifyDomain, jsonOut     bool
	)
	cmd := &cobra.Command{
		Use:   "persist <phase> <feature>",
		Short: "Record a retro ledger line: Engram primary, task-doc ## Retros appendix secondary",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			phase, feature := args[0], args[1]
			resolved, err := retro.ResolveBody(body, bodyFile, verifyDomain)
			if err != nil {
				return retroFailOpen(err)
			}
			ref, err := resolveCommitRef(commitRef)
			if err != nil {
				return retroFailOpen(err)
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
					fmt.Fprintln(os.Stderr, msg)
					if jsonOut {
						_ = json.NewEncoder(os.Stdout).Encode(map[string]any{
							"ok":      false,
							"message": msg,
						})
					}
					os.Exit(2)
				}
				return retroFailOpen(err)
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(res)
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
	cmd.Flags().StringVar(&body, "body", "", "retro body text")
	cmd.Flags().StringVar(&bodyFile, "body-file", "", "path to retro body file")
	cmd.Flags().BoolVar(&verifyDomain, "verify-domain", false, "persist verification domain only (Verification Gaps + Verify-Phase Incidents)")
	cmd.Flags().StringVar(&commitRef, "commit-ref", "", "commit ref to record (defaults to git rev-parse HEAD at the repo root; required when not inside a repo)")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON result")
	return cmd
}

// retroFailOpen surfaces a D2 loud FAIL-OPEN marker for a lost retro write
// and exits 2 (the write path failed; the orchestrator must notice).
func retroFailOpen(err error) error {
	fmt.Fprintf(os.Stderr, "FAIL-OPEN: retro lost write — %v\n", err)
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
				return json.NewEncoder(os.Stdout).Encode(precis)
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

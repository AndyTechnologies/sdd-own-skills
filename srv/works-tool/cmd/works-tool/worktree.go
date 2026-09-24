package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"works-tool/internal/envelope"
	"works-tool/internal/worktree"

	"github.com/spf13/cobra"
)

func newWorktreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "worktree",
		Short: "Worktree lifecycle: list and verify",
	}
	cmd.AddCommand(newWorktreeListCmd())
	cmd.AddCommand(newWorktreeVerifyCmd())
	return cmd
}

func newWorktreeListCmd() *cobra.Command {
	var jsonOut bool
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List convention worktrees under ~/.agent_worktrees/<repo>/<change>",
		RunE: func(cmd *cobra.Command, args []string) error {
			entries := worktree.List()
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess("", entries))
			}
			if len(entries) == 0 {
				fmt.Println("No worktrees found.")
				return nil
			}
			for _, e := range entries {
				fmt.Printf("%s  %s  root_ok=%t task_doc_ok=%t\n", e.Path, e.Branch, e.RepoRootOK, e.TaskDocOK)
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}

func newWorktreeVerifyCmd() *cobra.Command {
	var (
		jsonOut bool
		feature string
	)
	cmd := &cobra.Command{
		Use:   "verify",
		Short: "Verify ODD binding signals (root, task doc; branch informative)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if feature == "" {
				msg := "--feature is required"
				if jsonOut {
					_ = json.NewEncoder(os.Stdout).Encode(envelope.NewFailure("", envelope.CodeInvalidArgs, msg, false))
				} else {
					fmt.Fprintln(os.Stderr, msg)
				}
				os.Exit(1)
			}
			result, err := worktree.Verify(feature)
			if err != nil {
				if jsonOut {
					_ = json.NewEncoder(os.Stdout).Encode(envelope.NewFailure(feature, envelope.CodeSignalFailed, err.Error(), false))
				} else {
					fmt.Fprintln(os.Stderr, err)
				}
				os.Exit(1)
			}
			if jsonOut {
				if result.Pass {
					return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, result))
				}
				_ = json.NewEncoder(os.Stdout).Encode(envelope.NewFailure(feature, envelope.CodeSignalFailed, strings.TrimSpace(result.Text()), false))
				os.Exit(1)
			}
			fmt.Print(result.Text())
			if !result.Pass {
				os.Exit(1)
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	cmd.Flags().StringVar(&feature, "feature", "", "feature/change name (required)")
	return cmd
}

package main

import (
	"encoding/json"
	"fmt"
	"os"

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
			trees := worktree.List()
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(trees)
			}
			if len(trees) == 0 {
				fmt.Println("No worktrees found.")
				return nil
			}
			for _, t := range trees {
				fmt.Printf("%s  %s\n", t.Path, t.Branch)
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}

func newWorktreeVerifyCmd() *cobra.Command {
	var (
		jsonOut     bool
		changeName  string
		expectedRoot string
	)
	cmd := &cobra.Command{
		Use:   "verify",
		Short: "Verify worktree binding signals (root, branch)",
		RunE: func(cmd *cobra.Command, args []string) error {
			result, err := worktree.Verify(changeName, expectedRoot)
			if err != nil {
				fmt.Fprintf(os.Stderr, "%v\n", err)
				os.Exit(1)
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(result)
			}
			fmt.Print(result.Text())
			if !result.Pass {
				os.Exit(1)
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	cmd.Flags().StringVar(&changeName, "change", "", "change name")
	cmd.Flags().StringVar(&expectedRoot, "root", "", "expected repo root (default: cwd")
	return cmd
}

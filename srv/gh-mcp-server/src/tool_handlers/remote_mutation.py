"""Remote mutation handlers — 3 ``gh_*`` destructive tools.

All tools use ``destructive_flow`` with computed dry-runs.
No ``gh pr merge --dry-run`` exists; no ``gh branch`` exists.
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from src.dryrun import DryRunResult, classify_mergeability, classify_merged, safe_to_rerun, destructive_flow
from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


def register(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire all 3 remote mutation tools into *server*."""

    # ------------------------------------------------------------------
    # 1. gh_merge_pull_request
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_merge_pull_request(
        owner: str,
        repo: str,
        number: int,
        method: str = "squash",
        delete_branch: bool = False,
        auto: bool = False,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Merge a pull request (two-phase: dry-run → confirm).

        method: squash | merge | rebase
        auto: defer merge until checks pass (GitHub merge queue).
        """
        def compute_dry_run() -> DryRunResult:
            # Gather PR state
            pr_r = executor.run(["gh", "pr", "view", "-R", f"{owner}/{repo}",
                                 str(number), "--json",
                                 "mergeable,mergeStateStatus,baseRefName"])
            if pr_r.returncode != 0:
                return DryRunResult(
                    data={"error": "pr_not_found"},
                    summary=f"PR #{number} not found",
                )
            pr = json.loads(pr_r.stdout)
            mergeable = pr.get("mergeable")
            merge_state_status = pr.get("mergeStateStatus")

            # Gather check rollup
            checks_r = executor.run(["gh", "pr", "view", "-R", f"{owner}/{repo}",
                                     str(number), "--json", "statusCheckRollup"])
            checks_ok = True
            if checks_r.returncode == 0:
                checks = json.loads(checks_r.stdout).get("statusCheckRollup", [])
                checks_ok = all(c.get("conclusion") == "success" for c in checks) if checks else True

            # Check base up-to-date (simplified: if mergeStateStatus indicates behind)
            base_up_to_date = merge_state_status not in ("BEHIND", None)

            effect = classify_mergeability(
                mergeable=mergeable,
                merge_state_status=merge_state_status,
                checks_ok=checks_ok,
                base_up_to_date=base_up_to_date,
            )

            # Add method and auto to data
            effect.data["method"] = method
            effect.data["delete_branch"] = delete_branch
            effect.data["auto"] = auto
            if auto:
                effect.summary += " [--auto: merge deferred until checks pass]"
            effect.fingerprint = DryRunResult(effect.data, "").fingerprint
            return effect

        def execute() -> Envelope:
            cmd = ["gh", "pr", "merge", "-R", f"{owner}/{repo}",
                   str(number), f"--{method}"]
            if delete_branch:
                cmd.append("--delete-branch")
            if auto:
                cmd.append("--auto")
            r = executor.run(cmd)
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())
            return ok(None, f"PR #{number} merged via {method}")

        result = destructive_flow(
            remote=True,
            executor=executor,
            compute_dry_run=compute_dry_run,
            execute=execute,
            dry_run=dry_run,
            confirmed=confirmed,
            confirmed_data=confirmed_data,
        )
        return dict(result)

    # ------------------------------------------------------------------
    # 2. gh_delete_branch
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_delete_branch(
        owner: str,
        repo: str,
        branch: str,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Delete a remote branch (two-phase: dry-run → confirm).

        Verifies the branch is merged before allowing deletion.
        """
        def compute_dry_run() -> DryRunResult:
            # Get default branch
            repo_r = executor.run(["gh", "repo", "view", f"{owner}/{repo}",
                                   "--json", "defaultBranchRef"])
            if repo_r.returncode != 0:
                return DryRunResult(
                    data={"error": "repo_not_found"},
                    summary=f"Repository {owner}/{repo} not found",
                )
            default_branch = json.loads(repo_r.stdout).get("defaultBranchRef", {}).get("name", "main")

            # Compare default..branch to check for unmerged work
            compare_r = executor.run(["gh", "api",
                                      f"repos/{owner}/{repo}/compare/{default_branch}...{branch}"])
            if compare_r.returncode != 0:
                # Branch may not exist or compare failed
                return DryRunResult(
                    data={"error": "compare_failed"},
                    summary=f"Could not compare {branch} to {default_branch}",
                )
            compare_data = json.loads(compare_r.stdout)
            compare_status = compare_data.get("status")

            return classify_merged(compare_status=compare_status)

        def execute() -> Envelope:
            r = executor.run(["gh", "api", "-X", "DELETE",
                              f"repos/{owner}/{repo}/git/refs/heads/{branch}"])
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())
            return ok(None, f"Branch {branch} deleted")

        result = destructive_flow(
            remote=True,
            executor=executor,
            compute_dry_run=compute_dry_run,
            execute=execute,
            dry_run=dry_run,
            confirmed=confirmed,
            confirmed_data=confirmed_data,
        )
        return dict(result)

    # ------------------------------------------------------------------
    # 3. gh_rerun_workflow
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_rerun_workflow(
        owner: str,
        repo: str,
        run_id: int,
        failed_only: bool = False,
        dry_run: bool = True,
        confirmed: bool = False,
        confirmed_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Re-run a workflow (two-phase: dry-run → confirm).

        failed_only: re-run only failed jobs.
        """
        def compute_dry_run() -> DryRunResult:
            r = executor.run(["gh", "run", "view", str(run_id),
                              "-R", f"{owner}/{repo}", "--json",
                              "status,conclusion,name,jobs"])
            if r.returncode != 0:
                return DryRunResult(
                    data={"error": "run_not_found"},
                    summary=f"Workflow run {run_id} not found",
                )
            data = json.loads(r.stdout)
            status = data.get("status")
            conclusion = data.get("conclusion")
            failed_jobs = None
            if failed_only and data.get("jobs"):
                failed_jobs = [
                    j["name"] for j in data["jobs"]
                    if j.get("conclusion") == "failure"
                ]
            return safe_to_rerun(
                status=status,
                conclusion=conclusion,
                failed_jobs=failed_jobs,
            )

        def execute() -> Envelope:
            cmd = ["gh", "run", "rerun", str(run_id), "-R", f"{owner}/{repo}"]
            if failed_only:
                cmd.append("--failed")
            r = executor.run(cmd)
            if r.returncode != 0:
                return err("invalid_parameter", r.stderr.strip())
            return ok(None, f"Workflow run {run_id} re-triggered")

        result = destructive_flow(
            remote=True,
            executor=executor,
            compute_dry_run=compute_dry_run,
            execute=execute,
            dry_run=dry_run,
            confirmed=confirmed,
            confirmed_data=confirmed_data,
        )
        return dict(result)

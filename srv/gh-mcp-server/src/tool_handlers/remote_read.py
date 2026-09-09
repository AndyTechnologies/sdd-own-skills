"""Remote read handlers — 14 ``gh_*`` tools.

All tools:
- Gate on ``require_auth(executor)`` (fail-closed)
- Use ``executor.run()`` with ``gh --json`` or ``gh`` text output
- Return ``ok(data, summary)`` with structured data
- Timeout: 30 s default; 120 s for ``gh_get_run_logs``
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from src.envelope import Envelope, err, ok
from src.gh_auth import require_auth

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


def register(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire all 14 remote read tools into *server*."""

    # ------------------------------------------------------------------
    # 1. gh_get_me
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_me() -> dict[str, Any]:
        """Get authenticated user identity (login, name, plan)."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "api", "user"])
        if r.returncode != 0:
            return dict(err("repo_not_found", r.stderr.strip()))
        data = json.loads(r.stdout)
        return dict(ok(
            {"login": data.get("login"), "name": data.get("name"), "plan": data.get("plan")},
            f"Authenticated as {data.get('login', 'unknown')}",
        ))

    # ------------------------------------------------------------------
    # 2. gh_get_repo
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_repo(owner: str, repo: str) -> dict[str, Any]:
        """Get repo metadata (defaultBranch, visibility, isPrivate, url)."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "repo", "view", f"{owner}/{repo}", "--json",
                          "defaultBranchRef,visibility,isPrivate,url"])
        if r.returncode != 0:
            return dict(err("repo_not_found", f"Repository {owner}/{repo} not found"))
        data = json.loads(r.stdout)
        return dict(ok(data, f"Repository {owner}/{repo}"))

    # ------------------------------------------------------------------
    # 3. gh_list_repositories
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_list_repositories(owner: str, limit: int = 30) -> dict[str, Any]:
        """List repositories for an owner."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "repo", "list", owner, "--json",
                          "name,description,isPrivate", "--limit", str(limit)])
        if r.returncode != 0:
            return dict(err("repo_not_found", r.stderr.strip()))
        data = json.loads(r.stdout)
        return dict(ok({"repositories": data}, f"Found {len(data)} repositories"))

    # ------------------------------------------------------------------
    # 4. gh_list_issues
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_list_issues(owner: str, repo: str, limit: int = 30) -> dict[str, Any]:
        """List issues for a repository."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "issue", "list", "-R", f"{owner}/{repo}", "--json",
                          "number,title,state,labels", "--limit", str(limit)])
        if r.returncode != 0:
            return dict(err("repo_not_found", r.stderr.strip()))
        data = json.loads(r.stdout)
        return dict(ok({"issues": data}, f"Found {len(data)} issues"))

    # ------------------------------------------------------------------
    # 5. gh_get_issue
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_issue(owner: str, repo: str, number: int) -> dict[str, Any]:
        """Get a single issue by number."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "issue", "view", "-R", f"{owner}/{repo}",
                          str(number), "--json",
                          "number,title,state,body,labels,assignees"])
        if r.returncode != 0:
            return dict(err("not_found", f"Issue #{number} not found in {owner}/{repo}"))
        data = json.loads(r.stdout)
        return dict(ok(data, f"Issue #{number}: {data.get('title', '')}"))

    # ------------------------------------------------------------------
    # 6. gh_list_pull_requests
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_list_pull_requests(owner: str, repo: str, limit: int = 30) -> dict[str, Any]:
        """List pull requests."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "pr", "list", "-R", f"{owner}/{repo}", "--json",
                          "number,title,state,headRefName,baseRefName", "--limit", str(limit)])
        if r.returncode != 0:
            return dict(err("repo_not_found", r.stderr.strip()))
        data = json.loads(r.stdout)
        return dict(ok({"pull_requests": data}, f"Found {len(data)} pull requests"))

    # ------------------------------------------------------------------
    # 7. gh_get_pull_request
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_pull_request(owner: str, repo: str, number: int) -> dict[str, Any]:
        """Get a single pull request."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "pr", "view", "-R", f"{owner}/{repo}",
                          str(number), "--json",
                          "number,title,state,headRefName,baseRefName,mergeable,url"])
        if r.returncode != 0:
            return dict(err("not_found", f"PR #{number} not found in {owner}/{repo}"))
        data = json.loads(r.stdout)
        return dict(ok(data, f"PR #{number}: {data.get('title', '')}"))

    # ------------------------------------------------------------------
    # 8. gh_get_pr_checks
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_pr_checks(owner: str, repo: str, number: int) -> dict[str, Any]:
        """Get PR status check rollup and merge state."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "pr", "view", "-R", f"{owner}/{repo}",
                          str(number), "--json",
                          "statusCheckRollup,mergeStateStatus"])
        if r.returncode != 0:
            return dict(err("not_found", f"PR #{number} not found"))
        data = json.loads(r.stdout)
        checks = data.get("statusCheckRollup", [])
        passing = sum(1 for c in checks if c.get("conclusion") == "success")
        return dict(ok(data, f"PR #{number} checks: {passing}/{len(checks)} passing"))

    # ------------------------------------------------------------------
    # 9. gh_get_pr_diff
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_pr_diff(owner: str, repo: str, number: int) -> dict[str, Any]:
        """Get the diff for a pull request (wrapped text, not raw passthrough)."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "pr", "diff", "-R", f"{owner}/{repo}", str(number)])
        if r.returncode != 0:
            return dict(err("not_found", f"PR #{number} diff not available"))
        return dict(ok({"diff": r.stdout}, f"PR #{number} diff ({len(r.stdout)} chars)"))

    # ------------------------------------------------------------------
    # 10. gh_list_commits
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_list_commits(owner: str, repo: str, limit: int = 30) -> dict[str, Any]:
        """List recent commits."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "api", f"repos/{owner}/{repo}/commits",
                          "--paginate", "-q", f".[0:{limit}]"])
        if r.returncode != 0:
            return dict(err("repo_not_found", r.stderr.strip()))
        data = json.loads(r.stdout)
        summary = [
            {"sha": c["sha"][:7], "message": c["commit"]["message"].split("\n")[0]}
            for c in data
        ]
        return dict(ok({"commits": summary}, f"Found {len(summary)} commits"))

    # ------------------------------------------------------------------
    # 11. gh_list_workflow_runs
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_list_workflow_runs(owner: str, repo: str, limit: int = 30) -> dict[str, Any]:
        """List workflow runs."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "run", "list", "-R", f"{owner}/{repo}", "--json",
                          "id,name,status,conclusion,headSha", "--limit", str(limit)])
        if r.returncode != 0:
            return dict(err("repo_not_found", r.stderr.strip()))
        data = json.loads(r.stdout)
        return dict(ok({"workflow_runs": data}, f"Found {len(data)} workflow runs"))

    # ------------------------------------------------------------------
    # 12. gh_get_workflow_run
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_workflow_run(owner: str, repo: str, run_id: int) -> dict[str, Any]:
        """Get a single workflow run."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "run", "view", str(run_id),
                          "-R", f"{owner}/{repo}", "--json",
                          "status,conclusion,name,headSha,jobs"])
        if r.returncode != 0:
            return dict(err("not_found", f"Workflow run {run_id} not found"))
        data = json.loads(r.stdout)
        return dict(ok(data, f"Run {run_id}: {data.get('status', '?')}"))

    # ------------------------------------------------------------------
    # 13. gh_get_run_logs (120s timeout — streams large logs)
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_get_run_logs(owner: str, repo: str, run_id: int,
                              log_failed: bool = False) -> dict[str, Any]:
        """Get logs for a workflow run. Use log_failed=true for failed jobs only."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        cmd = ["gh", "run", "view", str(run_id), "-R", f"{owner}/{repo}"]
        if log_failed:
            cmd.append("--log-failed")
        else:
            cmd.append("--log")
        r = executor.run(cmd, timeout_s=120)
        if r.returncode != 0:
            return dict(err("not_found", f"Logs for run {run_id} not available"))
        return dict(ok({"logs": r.stdout}, f"Run {run_id} logs ({len(r.stdout)} chars)"))

    # ------------------------------------------------------------------
    # 14. gh_search_code
    # ------------------------------------------------------------------
    @server.tool()
    async def gh_search_code(query: str, limit: int = 10) -> dict[str, Any]:
        """Search code via GitHub API (rate-limited)."""
        auth = require_auth(executor)
        if auth:
            return dict(auth)
        r = executor.run(["gh", "api", "search/code", "-X", "GET",
                          "-f", f"q={query}", "-f", f"per_page={limit}"])
        if r.returncode != 0:
            return dict(err("network_error", r.stderr.strip()))
        data = json.loads(r.stdout)
        items = data.get("items", [])
        summary_items = [
            {"path": it["path"], "repository": it["repository"]["full_name"]}
            for it in items
        ]
        return dict(ok({"items": summary_items, "total_count": data.get("total_count", 0)},
                        f"Found {len(items)} code results"))

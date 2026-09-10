"""Dry-run template and shared pure helpers.

Contains:
- ``DryRunResult`` dataclass (data, summary, fingerprint)
- ``fingerprint(data)`` — SHA-256 of sorted-JSON
- ``ECHO_PROTOCOL`` — the canonical two-phase echo contract wording shared by
  every destructive tool's docstring (E1: single source of truth)
- Pure classifiers: ``classify_mergeability``, ``classify_merged``, ``safe_to_rerun``
- ``destructive_flow()`` — Template Method for two-phase ops with echo-back

``dryrun.py`` has **zero executor dependencies** — per-op data gathering
lives in each handler's ``compute_dry_run`` closure.

Safety contract (fail-closed):
- An effect whose ``data["safe"]`` is not exactly ``True`` NEVER executes,
  even when the caller echoes matching evidence (``confirm_required`` returns
  the recomputed effect instead).
- The echo evidence the caller must return is the **exact data object the
  first phase returned**, i.e. ``{"dry_run": True, **effect.data}``. The
  fingerprint is computed over that whole object so echoing it verbatim
  confirms; any drift (or a stripped ``dry_run`` key) is treated as evidence
  of a changed effect and refuses.
- The phase selector is **``confirmed``**, not ``dry_run``. Phase 1
  (``dry_run=true``, the schema default) returns the display effect; phase 2
  executes when ``confirmed=true`` and ``confirmed_data`` exactly matches —
  without the caller touching ``dry_run`` at all. ``dry_run`` only carries
  the convenient default for phase 1 and is ignored once ``confirmed=true``.
- ``confirm_required`` is an ``ok()`` summary MARKER — it never uses ``err()``
  and it names the exact parameter to echo back (``confirmed_data``) so the
  model can act on it (E1).
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, Callable

from src.envelope import Envelope, err, ok

if TYPE_CHECKING:
    from src.executor import ExecutorProto


# ---------------------------------------------------------------------------
# DryRunResult
# ---------------------------------------------------------------------------

@dataclass
class DryRunResult:
    """Computed effect for a destructive dry-run."""
    data: dict[str, Any]
    summary: str
    fingerprint: str = field(default="", repr=False)

    def __post_init__(self) -> None:
        if not self.fingerprint:
            self.fingerprint = fp(self.data)


def fp(data: dict[str, Any]) -> str:
    """Deterministic fingerprint: SHA-256 of sorted-JSON."""
    return hashlib.sha256(
        json.dumps(data, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


ECHO_PROTOCOL = (
    "Echo protocol: phase 1 dry_run=true returns display_data "
    "{dry_run:true, ...effect}; phase 2 confirmed=true requires "
    "confirmed_data=EXACT <display_data object>; a mismatch or omitted "
    "confirmed_data returns confirm_required (never executes). "
    "The phase selector is confirmed=true — dry_run stays at its schema "
    "default (true) and is ignored during phase 2, so do NOT set dry_run=false "
    "to confirm; pass confirmed=true + confirmed_data."
)


# ---------------------------------------------------------------------------
# Pure classifiers
# ---------------------------------------------------------------------------

def classify_mergeability(
    *,
    mergeable: bool | str | None,
    merge_state_status: str | None,
    checks_ok: bool,
    base_up_to_date: bool,
) -> DryRunResult:
    """Compute dry-run data for ``gh_merge_pull_request``.

    ``gh pr view --json mergeable`` yields the GraphQL ``MergeableState``
    **string** enum (``MERGEABLE``, ``CONFLICTING``, ``UNKNOWN``, ``DRAFT``),
    not a boolean. Fail closed: any value other than a definitive merged/OK
    state becomes ``safe: None`` (unknown), never safe.
    """
    if isinstance(mergeable, str):
        if mergeable == "MERGEABLE":
            mergeable = True
        elif mergeable == "CONFLICTING":
            mergeable = False
        else:  # UNKNOWN, DRAFT, or any other string -> unknown
            mergeable = None

    mergeable_str = str(mergeable) if mergeable is not None else "UNKNOWN"
    data: dict[str, Any] = {
        "mergeable": mergeable,
        "merge_state_status": merge_state_status,
        "checks_ok": checks_ok,
        "base_up_to_date": base_up_to_date,
    }

    if mergeable is None:
        data["safe"] = None
        return DryRunResult(
            data=data,
            summary="Mergeability UNKNOWN — cannot proceed",
        )

    if not base_up_to_date:
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary="Base branch is behind HEAD — update base first",
        )

    if not checks_ok:
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary="Checks are not passing — wait for green",
        )

    if not mergeable:
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary="PR is not mergeable (conflicts or blocked)",
        )

    data["safe"] = True
    return DryRunResult(
        data=data,
        summary="PR is mergeable, checks green, base up-to-date",
    )


def classify_merged(*, compare_status: str | None) -> DryRunResult:
    """Compute dry-run data for ``gh_delete_branch``."""
    data: dict[str, Any] = {"compare_status": compare_status}

    if compare_status is None:
        data["merged"] = False
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary="Could not determine merge status — refusing to delete",
        )

    if compare_status in ("ahead", "diverged"):
        data["merged"] = False
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary=f"Branch has unmerged work (compare: {compare_status}) — refusing to delete",
        )

    data["merged"] = True
    data["safe"] = True
    return DryRunResult(
        data=data,
        summary="Branch appears merged — safe to delete",
    )


def classify_push(
    *,
    branch: str | None,
    upstream: str | None,
    ahead: int,
    behind: int,
    dirty_count: int,
) -> DryRunResult:
    """Compute dry-run data for ``git_push`` (local branch → its upstream).

    Fail closed: pushing is only provably safe when the current HEAD is on a
    named branch (not detached), an upstream is configured, and there is at
    least one commit ahead of it. Being behind is NOT a blocker (a plain push
    cannot force; the remote rejects a non-fast-forward itself).
    """
    data: dict[str, Any] = {
        "branch": branch,
        "upstream": upstream,
        "ahead": ahead,
        "behind": behind,
        "dirty_count": dirty_count,
    }

    if branch is None:
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary="Detached HEAD — nothing to push (checkout a branch first)",
        )

    if upstream is None:
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary=f"Branch {branch} has no upstream — nothing to push (set tracking first)",
        )

    if ahead <= 0:
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary=f"Nothing to push — {branch} is up to date with {upstream}",
        )

    data["safe"] = True
    detail = f"{behind} behind" if behind > 0 else "in sync"
    dirty = f", {dirty_count} dirty" if dirty_count > 0 else ""
    return DryRunResult(
        data=data,
        summary=f"Push {ahead} commit(s) from {branch} → {upstream} ({detail}{dirty})",
    )


def safe_to_rerun(
    *,
    status: str | None,
    conclusion: str | None,
    failed_jobs: list[str] | None = None,
) -> DryRunResult:
    """Compute dry-run data for ``gh_rerun_workflow``."""
    data: dict[str, Any] = {
        "status": status,
        "conclusion": conclusion,
    }
    if failed_jobs:
        data["failed_jobs"] = failed_jobs

    if status not in ("completed", "failure", None):
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary=f"Run is still {status} — cannot re-run",
        )

    if conclusion == "success":
        data["safe"] = False
        return DryRunResult(
            data=data,
            summary="Run already succeeded — nothing to re-run",
        )

    data["safe"] = True
    hint = ""
    if failed_jobs:
        hint = f" (failed jobs: {', '.join(failed_jobs)})"
    return DryRunResult(
        data=data,
        summary=f"Run can be re-run (status: {status}, conclusion: {conclusion}){hint}",
    )


# ---------------------------------------------------------------------------
# Template Method: destructive two-phase flow
# ---------------------------------------------------------------------------

def destructive_flow(
    *,
    remote: bool,
    executor: ExecutorProto,
    compute_dry_run: Callable[[], DryRunResult],
    execute: Callable[[], Envelope],
    dry_run: bool = True,
    confirmed: bool = False,
    confirmed_data: dict[str, Any] | None = None,
) -> Envelope:
    """Two-phase destructive operation with echo-back evidence.

    Flow:
    1. Auth gate (remote tools only)
    2. Recompute dry-run effect (always) and build the display payload:
       ``{"dry_run": True, **effect.data}`` (this exact object is the echo
       evidence the caller must return)
    3. If ``dry_run`` or not ``confirmed`` → return effect, no mutation
    4. **Fail-closed gate**: if ``effect.data["safe"]`` is not exactly True
       → return ``not_safe`` error, NEVER execute (matching echo included)
    5. If ``confirmed`` but no ``confirmed_data`` → re-compute + confirm_required
    6. If ``confirmed_data`` fingerprint (over the full display payload)
       mismatches → drift, re-compute + confirm_required
    7. If fingerprint matches → ``execute()`` once, no retries
    """
    if remote:
        from src.gh_auth import require_auth

        auth_issue = require_auth(executor)
        if auth_issue:
            return auth_issue

    effect = compute_dry_run()

    if effect.data.get("error"):
        return err("invalid_parameter", effect.summary)

    # The exact object the caller must echo back to confirm
    display_data = {"dry_run": True, **effect.data}
    display_fp = fp(display_data)

    # Phase selector is `confirmed`, NOT `dry_run`. Phase 1 (dry-run) returns
    # the display effect when the call is unconfirmed; phase 2 (confirmed=true
    # + exact confirmed_data) executes. `dry_run` only carries the convenient
    # default for phase 1 — a caller following the documented contract echoes
    # confirmed=true + confirmed_data without touching dry_run, and must not
    # be forced to know it defaults to True.
    if dry_run and not confirmed:
        return ok(display_data, effect.summary)

    # Fail-closed: an effect that is not provably safe NEVER executes
    if effect.data.get("safe") is not True:
        return err(
            "not_safe",
            effect.summary + " [refusing to execute: dry-run effect is not safe]",
            hint="resolve the block, then re-run the dry-run",
        )

    # Phase 2: confirmed=true — verify echo-back evidence
    if confirmed_data is None:
        return ok(
            display_data,
            effect.summary + " [confirm_required: echo the dry-run data back as confirmed_data]",
        )

    echoed_fp = fp(confirmed_data)
    if echoed_fp != display_fp:
        return ok(
            display_data,
            effect.summary + " [confirm_required: dry-run effect changed — echo the NEW display_data back as confirmed_data]",
        )

    # Evidence matches → execute exactly once
    return execute()

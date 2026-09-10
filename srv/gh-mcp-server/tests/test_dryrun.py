"""RED tests for the two-phase echo protocol (dryrun.destructive_flow).

Covers the phase selector contract: phase 2 is selected by ``confirmed=true``
(exact echo data), NOT by ``dry_run=false``. Regression: a caller that follows
the documented ECHO_PROTOCOL — ``confirmed=true`` + ``confirmed_data`` exact —
executes even when ``dry_run`` stays at its schema default (true). Also covers
the fail-closed gates (safe gate, fingerprint drift, missing data, effect
errors) which never execute.

FakeExecutor mocks git; destructive_flow is exercised directly with injected
compute_dry_run/execute closures that record call counts.
"""

from __future__ import annotations

from typing import Any, Callable

import pytest

from src.dryrun import DryRunResult, destructive_flow
from src.envelope import Envelope
from src.executor import ProcResult


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class FakeExecutor:
    """Recorded argv -> ProcResult mapping (default: fail)."""

    def __init__(
        self,
        mapping: dict[tuple[str, ...], ProcResult] | None = None,
    ) -> None:
        self.mapping = mapping or {}
        self.calls: list[tuple[tuple[str, ...], str | None]] = []

    def run(self, argv, *, cwd=None, text=True, timeout_s=30.0) -> ProcResult:  # noqa: ARG002
        key = tuple(argv)
        self.calls.append((key, cwd))
        if key not in self.mapping:
            return ProcResult(1, "", f"unmocked: {' '.join(argv)}")
        return self.mapping[key]


def flow(
    *,
    executor: FakeExecutor,
    effect_data: dict[str, Any],
    summary: str = "test effect",
    dry_run: bool = True,
    confirmed: bool = False,
    confirmed_data: dict[str, Any] | None = None,
) -> tuple[Envelope, int]:
    """Run one destructive_flow round-trip; returns (envelope, execute_count)."""
    executed = 0

    def compute_dry_run() -> DryRunResult:
        return DryRunResult(data=effect_data, summary=summary)

    def execute() -> Envelope:
        nonlocal executed
        executed += 1
        return {"ok": True, "data": None, "summary": "executed", "error": None}

    env = destructive_flow(
        remote=False,
        executor=executor,
        compute_dry_run=compute_dry_run,
        execute=execute,
        dry_run=dry_run,
        confirmed=confirmed,
        confirmed_data=confirmed_data,
    )
    return env, executed


SAFE_EFFECT = {"staged_count": 2, "files": ["M a.txt", "M b.txt"], "safe": True}
# The exact display_data returned by phase 1 for SAFE_EFFECT.
SAFE_DISPLAY = {"dry_run": True, **SAFE_EFFECT}


# ---------------------------------------------------------------------------
# Phase 1 — dry-run (default)
# ---------------------------------------------------------------------------


def test_phase1_dry_run_default_returns_display_and_never_executes() -> None:
    executor = FakeExecutor()
    env, executed = flow(executor=executor, effect_data=SAFE_EFFECT)

    assert env["ok"] is True
    assert env["data"] == SAFE_DISPLAY
    assert executed == 0


def test_phase1_explicit_dry_run_true_never_executes() -> None:
    executor = FakeExecutor()
    env, executed = flow(
        executor=executor, effect_data=SAFE_EFFECT, dry_run=True, confirmed=True, confirmed_data=None
    )

    assert env["ok"] is True
    assert "confirm_required" in env["summary"]
    assert executed == 0


# ---------------------------------------------------------------------------
# Phase 2 — confirmed=true + exact echo (the regression: dry_run stays true)
# ---------------------------------------------------------------------------


def test_phase2_confirmed_without_touching_dry_run_executes() -> None:
    """THE regression case — caller follows documented protocol (confirmed=true,
    confirmed_data exact, dry_run left at schema default true) -> executes."""
    executor = FakeExecutor()
    env, executed = flow(
        executor=executor,
        effect_data=SAFE_EFFECT,
        confirmed=True,
        confirmed_data=SAFE_DISPLAY,
    )

    assert env["ok"] is True
    assert env["data"] is None
    assert env["summary"] == "executed"
    assert executed == 1


def test_phase2_explicit_dry_run_false_still_executes() -> None:
    """Backward compat: the old workaround (dry_run=false + confirmed=true) works."""
    executor = FakeExecutor()
    env, executed = flow(
        executor=executor,
        effect_data=SAFE_EFFECT,
        dry_run=False,
        confirmed=True,
        confirmed_data=SAFE_DISPLAY,
    )

    assert env["ok"] is True
    assert executed == 1


# ---------------------------------------------------------------------------
# Phase 2 fail-closed gates — never execute
# ---------------------------------------------------------------------------


def test_phase2_missing_confirmed_data_returns_confirm_required() -> None:
    executor = FakeExecutor()
    env, executed = flow(
        executor=executor, effect_data=SAFE_EFFECT, confirmed=True, confirmed_data=None
    )

    assert env["ok"] is True
    assert "confirm_required" in env["summary"]
    assert executed == 0


def test_phase2_drifted_confirmed_data_returns_confirm_required() -> None:
    executor = FakeExecutor()
    drifted = dict(SAFE_DISPLAY)
    drifted["files"] = ["M a.txt"]  # effect changed between phase 1 and phase 2
    env, executed = flow(
        executor=executor, effect_data=SAFE_EFFECT, confirmed=True, confirmed_data=drifted
    )

    assert env["ok"] is True
    assert "dry-run effect changed" in env["summary"]
    assert executed == 0


def test_phase2_not_safe_never_executes_even_with_matching_echo() -> None:
    not_safe = {"staged_count": 0, "files": [], "safe": False}
    executor = FakeExecutor()
    env, executed = flow(
        executor=executor,
        effect_data=not_safe,
        confirmed=True,
        confirmed_data={"dry_run": True, **not_safe},
    )

    assert env["ok"] is False
    assert env["error"] is not None
    assert env["error"]["type"] == "not_safe"
    assert executed == 0


def test_phase2_effect_error_returns_invalid_parameter() -> None:
    executor = FakeExecutor()
    env, executed = flow(
        executor=executor,
        effect_data={"error": "status_failed"},
        summary="Could not read git status",
        confirmed=True,
        confirmed_data=SAFE_DISPLAY,
    )

    assert env["ok"] is False
    assert env["error"] is not None
    assert env["error"]["type"] == "invalid_parameter"
    assert executed == 0


def test_fingerprint_ignores_key_order() -> None:
    """The echo fingerprint is over sorted-JSON, so key order never matters."""
    executor = FakeExecutor()
    shuffled = {"safe": True, "files": ["M a.txt", "M b.txt"], "staged_count": 2, "dry_run": True}
    env, executed = flow(
        executor=executor, effect_data=SAFE_EFFECT, confirmed=True, confirmed_data=shuffled
    )

    assert env["ok"] is True
    assert executed == 1
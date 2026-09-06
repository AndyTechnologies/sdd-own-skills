"""Typed output envelope and error catalog.

Every tool returns an ``Envelope`` — a flat dict with ``ok``, ``data``,
``summary``, and ``error`` keys.  Two builder helpers (``ok`` / ``err``)
construct it so handlers never build the shape by hand.

Error catalog (closed set, RFC §4.1):
    auth_required, repo_not_found, network_error, not_found,
    not_a_repo, dirty_worktree, confirm_required, invalid_parameter
"""

from __future__ import annotations

from typing import Any, TypedDict


class ErrorPayload(TypedDict, total=False):
    type: str
    message: str
    hint: str | None


class Envelope(TypedDict, total=False):
    ok: bool
    data: dict[str, Any] | None
    summary: str
    error: ErrorPayload | None


# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------

def ok(data: dict[str, Any] | None, summary: str) -> Envelope:
    """Return a successful envelope."""
    return Envelope(ok=True, data=data, summary=summary, error=None)


def err(error_type: str, message: str, hint: str | None = None) -> Envelope:
    """Return a failure envelope with a typed error."""
    return Envelope(ok=False, data=None, summary="", error=ErrorPayload(
        type=error_type, message=message, hint=hint,
    ))

"""Typed output envelope and error catalog.

Every tool returns an ``Envelope`` — a flat dict with ``ok``, ``data``,
``summary``, and ``error`` keys.  Two builder helpers (``ok`` / ``err``)
construct it so handlers never build the shape by hand.

ERROR CATALOG
-------------
The closed set lives in ``ERROR_TYPES`` below — NOT in this docstring and not
only in the spec. It used to be a list written here, and the drift that invited
was not hypothetical: ``push_failed`` was emitted by ``local_mutation`` and was
in nobody's list, while ``active_agents`` was in the list and emitted nowhere.
Two hand-written copies of a closed set is a closed set that is already open.
The docstring points at the tuple; ``spec.md`` must agree with it (asserted by
``tests/test_error_catalog.py``) and ``err()`` refuses anything outside it.

``timeout`` is the classification of a command that exceeded its deadline
(``SubprocessTimeout``), as opposed to ``network_error``, which is a real
OS-level failure. A missing binary is ``not_found`` with a hint naming the
executable — it is not a network problem. See ``executor.py`` and the safety
net in ``server.py``.

Note: ``confirm_required`` is a summary marker on ``ok()`` envelopes (see
``dryrun.destructive_flow``), NEVER an ``error.type``.
"""

from __future__ import annotations

from typing import Any, TypedDict

#: Closed set of valid ``error.type`` values (RFC §4.1). Single source of truth:
#: the docstring above, ``spec.md`` and the handlers must all agree with it.
ERROR_TYPES: tuple[str, ...] = (
    "auth_required",
    "repo_not_found",
    "network_error",
    "not_found",
    "not_a_repo",
    "dirty_worktree",
    "not_safe",
    "commit_failed",
    "invalid_parameter",
    "worktree_exists",
    "active_agents",
    "owned_by_other",
    "locked_unreadable",
    "corrupt_worktree",
    "timeout",
    # `git push` exited non-zero: a distinct, reportable failure (rejected,
    # no upstream, auth at the remote) that is not an OS error and therefore
    # never reaches the safety net's `network_error` arm.
    "push_failed",
)


class ErrorPayload(TypedDict, total=False):
    type: str
    message: str
    hint: str | None


class Envelope(TypedDict, total=False):
    ok: bool
    data: dict[str, Any] | None
    summary: str
    error: ErrorPayload | None


class UnknownErrorType(ValueError):
    """``err()`` recibió un ``error.type`` fuera del catálogo cerrado.

    Deliberately loud. Every call site passes a literal, never a variable, so an
    unknown type at runtime can only be a typo — and an envelope carrying
    ``type: "auth_requried"`` is indistinguishable from a valid one to whoever
    consumes it, which is worse than a crash during development.
    """

    def __init__(self, error_type: str) -> None:
        super().__init__(
            f"error.type {error_type!r} no esta en ERROR_TYPES "
            f"({len(ERROR_TYPES)} tipos). Si es un tipo nuevo, agregalo a la "
            f"tupla y al spec en el mismo cambio."
        )
        self.error_type = error_type


# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------

def ok(data: dict[str, Any] | None, summary: str) -> Envelope:
    """Return a successful envelope."""
    return Envelope(ok=True, data=data, summary=summary, error=None)


def err(error_type: str, message: str, hint: str | None = None) -> Envelope:
    """Return a failure envelope with a typed error.

    Raises ``UnknownErrorType`` if ``error_type`` is not in ``ERROR_TYPES``.
    """
    if error_type not in ERROR_TYPES:
        raise UnknownErrorType(error_type)
    return Envelope(ok=False, data=None, summary="", error=ErrorPayload(
        type=error_type, message=message, hint=hint,
    ))

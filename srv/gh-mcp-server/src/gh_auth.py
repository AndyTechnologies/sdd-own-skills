"""Auth gate — core service.

``require_auth(executor)`` probes ``gh auth status --exit-code`` per-call.
Returns ``None`` on success or an ``auth_required`` envelope on failure.
Every remote tool funnels through this single helper.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from src.envelope import Envelope, err

if TYPE_CHECKING:
    from src.executor import ExecutorProto


def require_auth(executor: ExecutorProto) -> Envelope | None:
    """Gate: verify ``gh`` is authenticated.

    Returns ``None`` if auth is valid; an ``auth_required`` envelope otherwise.
    """
    result = executor.run(["gh", "auth", "status", "--exit-code"])
    if result.returncode != 0:
        return err(
            "auth_required",
            "gh is not authenticated. Run `gh auth login` first.",
            hint="gh auth login",
        )
    return None

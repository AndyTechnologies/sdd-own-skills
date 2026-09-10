"""Auth gate — core service.

``require_auth(executor)`` probes ``gh auth status --json hosts`` per-call and
checks that at least one host is ``active``. The ``--exit-code`` flag was
removed in gh >= 2.98 (``unknown flag`` would fail the gate even when
authenticated), and ``gh auth status --json`` keeps rc=0 whether or not the
user is logged in, so the ``active`` field — not the exit code — is the
authoritative signal. Returns ``None`` on success or an ``auth_required``
envelope on failure. Every remote tool funnels through this single helper.
"""

from __future__ import annotations

import json
import shutil
from typing import TYPE_CHECKING

from src.envelope import Envelope, err
from src.executor import SubprocessError

if TYPE_CHECKING:
    from src.executor import ExecutorProto


def require_auth(executor: ExecutorProto) -> Envelope | None:
    """Gate: verify ``gh`` is authenticated to at least one active host.

    Returns ``None`` if auth is valid; an ``auth_required`` envelope otherwise.
    """
    if shutil.which("gh") is None:
        return err("auth_required", "gh CLI is not installed.", hint="install gh CLI")
    try:
        result = executor.run(["gh", "auth", "status", "--json", "hosts"])
    except SubprocessError as exc:
        return err("auth_required", f"gh auth status failed: {exc}", hint="check gh installation")
    if result.returncode != 0:
        return err(
            "auth_required",
            "gh is not authenticated. Run `gh auth login` first.",
            hint="gh auth login",
        )
    try:
        payload = json.loads(result.stdout)
    except (json.JSONDecodeError, TypeError):
        return err("auth_required", "gh auth status returned invalid JSON.", hint="gh auth login")
    for hosts in (payload.get("hosts") or {}).values():
        if any(host.get("active") for host in hosts):
            return None
    return err(
        "auth_required",
        "gh is not authenticated. Run `gh auth login` first.",
        hint="gh auth login",
    )
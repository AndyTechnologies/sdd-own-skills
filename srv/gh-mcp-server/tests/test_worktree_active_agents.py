"""El gate que faltaba: remove no puede borrar el worktree de otro proceso vivo.

Contexto — como se produjo el hueco. El change archivado
``2026-09-07-sdd-mcp-worktree`` especifico que ``git_worktree_remove``
denegara con ``active_agents`` cuando ``.sdd-agent-lock`` tuviera un PID vivo, y
su reporte de verificacion afirmo "32/32 PASS — live-pid -> active_agents". Ese
caso no existia en el codigo. ``active_agents`` estaba en el catalogo de
``error.type`` y no lo emitia nadie: un caller que ramifica sobre el recibiria
algo que nunca llega, y ``tests/test_error_catalog.py::test_catalog_has_no_dead_entries`
falla justo por esto.

El Audit lo mostro por el camino corto: la capa de handlers
(``tool_handlers/worktree_mutation.py``) no tenia NINGUN test. Todo lo que se
sabia del remove venia de tests de ``worktree_state``, que es la capa de abajo.

Por que el PID y no la identidad. El lock guarda ``pid = os.getpid()`` del
proceso que acquireo. Para un servidor MCP de vida larga ese PID esta siempre
vivo, asi que "denegar si hay PID vivo" leido al pie de la letra haria
imposible que un servidor remueva el worktree que el mismo acaba de tomar. La
senal autoritativa para remove es entonces: **hay un proceso VIVO, y no soy yo**.

Casos que fija esta suite:

===========================  =======  =====================  =================
lock (owner / pid)           session  resultado esperado    por que
===========================  =======  =====================  =================
alice / proceso vivo ajeno   n/a      ``active_agents``     el PID no soy yo
alice / ``os.getpid()``      n/a      procede (dry-run)     el claim es mio
mallory / proceso vivo      n/a      ``owned_by_other``    el dueño es otro
alice / PID muerto           n/a      procede               lock obsoleto
===========================  =======  =====================  =================
"""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest

import src.worktree_state as ws
from src.tool_handlers import worktree_mutation as wm
from src.executor import ProcResult

DEAD_PID = 999_999_999
REPO = "/repo"
OWNER = "alice"
CHANGE = "c1"


# ---------------------------------------------------------------------------
# Un PID vivo que no soy yo. `os.getpid()` no sirve: seria mi propio caso.
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def live_foreign_pid() -> int:
    """PID de un proceso real, vivo, que no es este proceso de test."""
    proc = subprocess.Popen(["sleep", "30"])
    try:
        yield proc.pid
    finally:
        proc.terminate()
        proc.wait(timeout=10)


class RecordingExecutor:
    """Executor minimo: responde lo que la ruta de remove consulta y registra todo."""

    def __init__(self, target: str, porcelain_paths: list[str]) -> None:
        self.calls: list[tuple[str, ...]] = []
        self._target = target
        # Correr cuando el flujo consulta `status --porcelain`. Es el momento
        # exacto entre el pre-check y `compute_dry_run`: lo que se simula con el
        # drift tiene que cambiar de ahi para entrar por la recomputacion.
        self.on_status = None
        lines: list[str] = []
        for p in porcelain_paths:
            lines += [f"worktree {p}", "HEAD deadbeef", "branch refs/heads/main", ""]
        self._porcelain = "\n".join(lines)

    def run(self, argv, *, cwd=None, text=True, timeout_s=30.0) -> ProcResult:  # noqa: ARG002
        self.calls.append(tuple(argv))
        if "--is-inside-work-tree" in argv:
            return ProcResult(0, "true", "")
        if "--show-toplevel" in argv:
            return ProcResult(0, REPO, "")
        if "worktree" in argv and "list" in argv:
            return ProcResult(0, self._porcelain, "")
        if "status" in argv and "--porcelain" in argv:
            if self.on_status is not None:
                hook, self.on_status = self.on_status, None
                hook()
            return ProcResult(0, "", "")  # limpio
        if "show-ref" in argv:
            return ProcResult(1, "", "")
        if "worktree" in argv and "remove" in argv:
            return ProcResult(0, "", "")
        return ProcResult(0, "", "")

    def ran_removal(self) -> bool:
        return any("remove" in c for c in self.calls if "worktree" in c)


def _lock(**over: Any) -> dict[str, Any]:
    base = {
        "version": 2,
        "pid": DEAD_PID,
        "session": "s1",
        "owner": OWNER,
        "change": CHANGE,
        "repo_root": REPO,
        "repo_name": "repo",
        "branch": "sdd/c1",
        "store": "hybrid",
        "created_at": "2026-01-01T00:00:00+00:00",
        "last_seen": "2026-01-01T00:00:00+00:00",
    }
    base.update(over)
    return base


class FakeServer:
    """Captura lo que se registra, como lo haria FastMCP.

    Los handlers son closures de ``register(server, executor)``, no atributos de
    modulo: no hay ``wm.executor`` que monkeypatchear. Passar por la puerta real
    además prueba que la tool queda registrada y con su descripcion, que es
    parte del contrato (E1).
    """

    def __init__(self) -> None:
        self.tools: dict[str, Any] = {}
        self.descriptions: dict[str, str] = {}

    def tool(self, *args: Any, **kwargs: Any):
        def decorate(fn):
            self.tools[fn.__name__] = fn
            self.descriptions[fn.__name__] = kwargs.get("description", "")
            return fn

        return decorate


@pytest.fixture
def env(tmp_path, monkeypatch):
    """Worktree de prueba ya en disco, con su lock, registrado en porcelain."""
    root = tmp_path / "agent_worktrees"
    target = root / "repo" / CHANGE
    target.mkdir(parents=True)
    monkeypatch.setattr(ws, "_agent_worktrees_root", lambda: root)
    ex = RecordingExecutor(str(target), [str(root / "repo" / "main"), str(target)])
    server = FakeServer()
    wm.register(server, ex)
    return {"root": root, "target": target, "ex": ex, "server": server}


def write_lock(env, lock: dict[str, Any]) -> None:
    (env["target"] / ws.LOCK_FILENAME).write_text(json.dumps(lock))


def remove(env, *, dry_run: bool = True, confirmed_data: dict[str, Any] | None = None):
    handler = env["server"].tools["git_worktree_remove"]
    return asyncio.run(
        handler(
            repo_path=REPO,
            change=CHANGE,
            owner=OWNER,
            dry_run=dry_run,
            confirmed=confirmed_data is not None,
            confirmed_data=confirmed_data,
        )
    )


def error_type(env_result) -> str | None:
    err = env_result.get("error")
    return err["type"] if err else None


# ---------------------------------------------------------------------------
# El gate
# ---------------------------------------------------------------------------


def test_remove_denies_active_agents_when_a_live_foreign_process_holds_my_claim(
    env, live_foreign_pid
):
    """El caso del spec: un proceso vivo, que no soy yo, tiene el worktree.

    Sin este gate, remove procede y le borra el worktree al otro proceso por
    debajo — con archivos modificados sin commitear, que es justo lo que un
    ``rm -rf`` de worktree no puede deshacer.
    """
    write_lock(env, _lock(pid=live_foreign_pid))
    result = remove(env)
    assert error_type(result) == "active_agents"
    assert not env["ex"].ran_removal(), "execute no debe correr con un claim vivo ajeno"


def test_remove_proceeds_when_the_live_holder_is_this_process(env):
    """El claim vivo es de ESTE proceso: se puede remover.

    Este caso fallaba antes con ``owned_by_other``, porque remove llama al
    clasificador con ``session=None`` y con session nula toda identidad se
    declara distinta — incluso la propia. Un servidor que acquire y despues
    removia su propio worktree no podia.
    """
    write_lock(env, _lock(pid=os.getpid()))
    result = remove(env)
    assert error_type(result) is None, result
    assert result["ok"] is True
    assert result["data"]["dry_run"] is True


def test_remove_still_denies_owned_by_other_when_the_owner_differs(env, live_foreign_pid):
    """Precedencia: un dueño ajeno se reporta como ``owned_by_other``, no active_agents.

    ``owned_by_other`` dice QUIEN tiene el worktree; ``active_agents`` dice que
    hay un proceso vivo. Cuando el dueño ya es otro, el primero es la respuesta
    accionable y no se degrada.
    """
    write_lock(env, _lock(owner="mallory", pid=live_foreign_pid))
    result = remove(env)
    assert error_type(result) == "owned_by_other"
    assert "mallory" in result["error"]["message"]


def test_remove_proceeds_when_the_claim_pid_is_dead(env):
    """Lock obsoleto: nadie lo sostiene, se puede remover."""
    write_lock(env, _lock(pid=DEAD_PID))
    result = remove(env)
    assert error_type(result) is None, result
    assert result["ok"] is True


# ---------------------------------------------------------------------------
# Fail-closed en la recomputacion
# ---------------------------------------------------------------------------


def test_confirm_refuses_when_a_live_foreign_pid_appears_after_the_precheck(env, live_foreign_pid):
    """El confirm vuelve a correr el pre-check: si el worktree ya esta tomado, no borra.

    La garantia que importa es "no borra", no con que error contesta. Este test
    fijaba ``not_safe`` y se equivocaba: el gate de PID corre antes del flujo de
    dos fases, asi que un confirm enfrenta un lock tomado se responde
    ``active_agents``. La recomputacion de ``safe`` se cubre aparte, en
    ``test_confirm_recomputes_the_pid_gate_inside_the_flow``.
    """
    write_lock(env, _lock(pid=DEAD_PID))
    phase1 = remove(env)
    assert phase1["ok"] is True
    echoed = phase1["data"]

    # Drift: aparece un proceso vivo con MI owner entre las dos fases.
    write_lock(env, _lock(pid=live_foreign_pid))

    result = remove(env, confirmed_data=echoed)
    assert result["ok"] is False
    assert error_type(result) in {"active_agents", "not_safe"}
    assert not env["ex"].ran_removal(), "no debe ejecutar con un claim vivo ajeno"


def test_confirm_recomputes_the_pid_gate_inside_the_flow(env, live_foreign_pid):
    """El PID se reevalua DENTRO del flujo, no solo en el pre-check.

    El pre-check y ``compute_dry_run`` son dos corridas separadas del chequeo. Si
    un proceso toma el worktree entre ambas, solo la segunda lo ve. Este caso lo
    fuerza en el unico lugar donde se puede observar —mutando el lock mientras el
    flujo consulta ``status``, entre el pre-check y la recomputacion— y por eso
    espera ``not_safe``: es la unica via que llega a la recomputacion.
    """
    write_lock(env, _lock(pid=DEAD_PID))
    phase1 = remove(env)
    assert phase1["ok"] is True
    echoed = phase1["data"]

    env["ex"].on_status = lambda: write_lock(env, _lock(pid=live_foreign_pid))
    result = remove(env, confirmed_data=echoed)
    assert error_type(result) == "not_safe", result
    assert not env["ex"].ran_removal()


# ---------------------------------------------------------------------------
# Alcance: release no se gatea
# ---------------------------------------------------------------------------


def test_release_is_not_blocked_by_a_live_foreign_pid(env, live_foreign_pid):
    """``git_worktree_release`` NO gana este gate.

    Release solo borra el lock y la entrada del indice: no borra archivos. Un
    gate de PID ahi expulsaria al segundo proceso de una sesion compartida sin
    evitar ninguna perdida de datos, y ademas contradiria al propio lock, que
    release es justamente lo que se usa para soltar.
    """
    write_lock(env, _lock(owner=OWNER, pid=live_foreign_pid))
    handler = env["server"].tools["git_worktree_release"]
    result = asyncio.run(handler(repo_path=REPO, change=CHANGE, owner=OWNER))
    assert error_type(result) != "active_agents", result


# ---------------------------------------------------------------------------
# El predicado compartido
# ---------------------------------------------------------------------------


def test_lock_pid_is_parsed_once_and_reused(monkeypatch):
    """``lock_pid`` es la unica fuente del PID; ``lock_has_live_pid`` lo usa.

    Si el parseo del PID viviera duplicado, el gate podria decidir "vivo" con una
    regla y la safety net con otra, sin que ninguna prueba lo note.
    """
    lock = _lock(pid=os.getpid())
    assert ws.lock_pid(lock) == os.getpid()
    assert ws.lock_has_live_pid(lock) is True
    assert ws.lock_pid(_lock(pid=DEAD_PID)) == DEAD_PID
    assert ws.lock_has_live_pid(_lock(pid=DEAD_PID)) is False


@pytest.mark.parametrize("pid_value", [None, "", "abc", 0, -1, "0"])
def test_lock_pid_is_none_for_unusable_values(pid_value):
    """Un PID ausente o no parseable es "stale", no una excepcion.

    El reporte de verificacion del change archivado reporto "live-pid -> active_agents"
    con un caso que no existia; estos son los bordes que un gate nuevo tiene que
    no convertir en crashes.
    """
    lock = _lock(pid=pid_value)
    assert ws.lock_pid(lock) is None
    assert ws.lock_has_live_pid(lock) is False


def test_the_gate_is_registered_and_advertised_in_the_tool_description(env):
    """Guarda de que este test no pase por estar testeando otra cosa.

    Un test de gate que enmudece porque el handler dejo de llamarse, o porque la
    tool dejo de registrarse, seria verde sin cubrir nada. Ademas la descripcion
    que ve el modelo es parte del contrato: si el gate deniega con
    ``active_agents`` y la descripcion no lo dice, el agente no tiene forma de
    saber que buscar.
    """
    assert "git_worktree_remove" in env["server"].tools
    assert "active_agents" in env["server"].descriptions["git_worktree_remove"]
    source = Path(wm.__file__).read_text()
    assert "_held_by_live_foreign_pid" in source, "el gate desaparecio del handler"

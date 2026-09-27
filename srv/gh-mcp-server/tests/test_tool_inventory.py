"""El inventario de tools describe EXACTAMENTE lo que el codigo registra.

Este test es el enforcement del lado del servidor. La unica verificacion
automatizada del repo es el guard RED T67 de ``tests/run_red_checks.sh``, porque
la suite pytest se corre a mano (no hay CI y el sandbox RED no tiene ``uv``).
Los dos consumen ``src.tool_inventory`` a proposito: duplicar la derivacion
dentro del test produciria dos verdades que pueden divergir, que es el defecto
que este change viene a eliminar.

Convencion de path: la suite no tenia ninguna lectura de archivos del repo (solo
``tmp_path``). Se establece aqui con ``__file__`` para no depender del cwd.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from src.tool_inventory import (
    EXPECTED_TOTAL,
    INVENTORY_FILENAME,
    all_problems,
    check_equality,
    check_total,
    derive_from_source,
    load_declared,
    server_root,
    total,
)

ROOT = server_root()
INVENTORY = ROOT / INVENTORY_FILENAME
HANDLERS = ROOT / "src" / "tool_handlers"


@pytest.fixture(scope="module")
def declared() -> dict[str, list[str]]:
    return load_declared(INVENTORY)


@pytest.fixture(scope="module")
def derived() -> dict[str, list[str]]:
    return derive_from_source(HANDLERS)


def test_inventory_file_is_machine_readable() -> None:
    raw = json.loads(INVENTORY.read_text(encoding="utf-8"))
    assert set(raw) == {"families"}, "el inventario solo debe contener 'families'"
    assert all(isinstance(tools, list) for tools in raw["families"].values())
    assert all(
        isinstance(name, str) and name
        for tools in raw["families"].values()
        for name in tools
    ), "familias y tools son identificadores estables, no prosa"


def test_inventory_omits_a_handwritten_total(declared: dict[str, list[str]]) -> None:
    """El total se deriva de la lista; escribirlo a mano lo deja desincronizable."""
    raw = json.loads(INVENTORY.read_text(encoding="utf-8"))
    assert "total" not in raw, "el total se deriva, no se escribe"
    assert total(declared) == EXPECTED_TOTAL


def test_set_equality_both_directions(derived: dict[str, list[str]]) -> None:
    """Ninguna tool del source puede faltar en el inventario, ni al reves."""
    assert check_equality(derived, load_declared(INVENTORY)) == []


def test_family_assignment_matches(derived: dict[str, list[str]]) -> None:
    """No basta con que el nombre exista: tiene que estar en su familia."""
    declared = load_declared(INVENTORY)
    for family, tools in derived.items():
        assert family in declared, f"familia sin declarar: {family}"
        for name in tools:
            assert name in declared[family], (
                f"{name} se registra en {family} pero el inventario la declara en "
                f"{[f for f, t in declared.items() if name in t] or 'ninguna'}"
            )


def test_no_duplicate_tool_names() -> None:
    """`git_delete_branch` (local) y `gh_delete_branch` (remote) no son la misma."""
    declared = load_declared(INVENTORY)
    every_name = [name for tools in declared.values() for name in tools]
    assert len(every_name) == len(set(every_name)), "tools duplicadas en el inventario"


def test_total_is_derived_from_the_list(declared: dict[str, list[str]]) -> None:
    counts = {family: len(tools) for family, tools in sorted(declared.items())}
    assert sum(counts.values()) == EXPECTED_TOTAL, counts


def test_tool_in_source_missing_from_inventory_is_detected(
    derived: dict[str, list[str]], declared: dict[str, list[str]]
) -> None:
    """Direccion source -> inventario: una tool registrada y no declarada.

    Simula el drift real —alguien agrega un ``@server.tool()`` y olvida el
    inventario— comparando el source REAL contra un inventario al que le falta
    una tool. El guard tiene que notar la ausencia POR NOMBRE.
    """
    drifted = {family: list(tools) for family, tools in declared.items()}
    drifted["local_read"].remove("git_status")
    problems = check_equality(derived, drifted)
    assert any("git_status" in p and "ausente" in p for p in problems), problems


def test_tool_in_inventory_missing_from_source_is_detected(
    derived: dict[str, list[str]], declared: dict[str, list[str]]
) -> None:
    """Direccion inventario -> source: una tool declarada que ya no existe.

    Un conteo igual no delata esto: si el source pierde una tool y el inventario
    tambien, el total sigue cuadrando y el drift pasa inadvertido.
    """
    drifted = {family: list(tools) for family, tools in declared.items()}
    drifted["remote_mutation"].append("gh_rerun_workflow_typo")
    problems = check_equality(derived, drifted)
    assert any(
        "gh_rerun_workflow_typo" in p and "no registrado" in p for p in problems
    ), problems


def test_moving_a_tool_to_another_family_is_detected(
    derived: dict[str, list[str]], declared: dict[str, list[str]]
) -> None:
    """Un nombre presente en las dos listas no es conformismo: la familia importa."""
    drifted = {family: list(tools) for family, tools in declared.items()}
    drifted["local_read"].remove("git_worktree_list")
    drifted["worktree_mutation"].append("git_worktree_list")
    problems = check_equality(derived, drifted)
    assert any(
        "familia incorrecta" in p and "git_worktree_list" in p for p in problems
    ), problems


def test_duplicate_tool_name_is_detected(
    derived: dict[str, list[str]], declared: dict[str, list[str]]
) -> None:
    """`git_delete_branch` (local) y `gh_delete_branch` (remote) no son la misma."""
    drifted = {family: list(tools) for family, tools in declared.items()}
    drifted["local_mutation"].append("git_delete_branch")
    problems = check_equality(derived, drifted)
    assert any("duplicadas" in p for p in problems), problems


def test_wrong_total_is_detected(declared: dict[str, list[str]]) -> None:
    """El total derivado de la lista, cuando no es el esperado, se reporta."""
    drifted = {family: list(tools) for family, tools in declared.items()}
    drifted["local_read"].remove("git_status")
    assert check_total(drifted), "un total derivado distinto del esperado debe fallar"


def test_all_problems_is_empty() -> None:
    assert all_problems() == []


def test_inventory_lives_next_to_the_server_and_not_in_the_test_dir() -> None:
    """El inventario es del servidor, no del test: el spec lo referencia asi."""
    assert INVENTORY.is_file()
    assert INVENTORY.parent == ROOT
    assert INVENTORY.parent != Path(__file__).resolve().parent

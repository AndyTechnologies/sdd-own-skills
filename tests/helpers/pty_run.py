#!/usr/bin/env python3
"""pty_run.py — ejecuta un comando bajo un pty y le responde lineas en orden.

Para probar los prompts interactivos de setup.sh (read -rs / read -r) de forma
deterministica. Cada entrada de "answers" se envia cuando el pty emite su
"prompt" (substring) hacia stderr.

Uso: pty_run.py <timeout_s> <outfile> <prompt=answer,...> -- <cmd> [args...]

  timeout_s  limite total en segundos; si se excede, exit 201 ("timeout")
  outfile    captura TODO lo emitido por el pty (stdout+stderr mezclado)
  prompts    lista prompt=answer separada por ";": cuando aparece "prompt" en
             la salida acumulada, se escribe "answer" (sin su Enter; ver nota)
  cmd        comando a ejecutar bajo el pty

Exit code: el del comando; 201 = timeout; 202 = se terminaron los answers sin
haber consumido todos los prompts y el comando aun corria.

Nota de nuevas lineas: si el answer necesita Enter, escribirlo como "\\n"
dentro del valor (p. ej. "Conservar el token existente? [k/R]=R\\n"). Se envia
el answer tal cual, sin Enter implicito, porque los prompts de setup.sh usan
read -rs (solo consume el token) y read -r (lee la linea completa).
"""
import os
import pty
import select
import subprocess
import sys
import time


def main():
    if len(sys.argv) < 5 or "--" not in sys.argv:
        sys.stderr.write("uso: pty_run.py <timeout> <outfile> <p> -- <cmd> [args]\n")
        return 201
    timeout = float(sys.argv[1])
    outfile = sys.argv[2]
    spec = sys.argv[3]
    idx = sys.argv.index("--")
    cmd = sys.argv[idx + 1:]
    pairs = []
    for item in spec.split(";") if spec else []:
        if "=" in item:
            p, a = item.split("=", 1)
            pairs.append((p, a.encode().decode("unicode_escape").encode()))
        else:
            pairs.append((item, b""))
    pairs = [(p.encode(), a) for p, a in pairs]

    output = bytearray()
    answers = list(pairs)
    fired = []  # prompts ya respondidos (para matcheo por ocurrencias)
    deadline = time.monotonic() + timeout

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)

    def save_output():
        with open(outfile, "wb") as f:
            f.write(bytes(output))

    try:
        while time.monotonic() < deadline:
            r, _, _ = select.select([fd], [], [], 0.2)
            if fd in r:
                try:
                    chunk = os.read(fd, 4096)
                except OSError:
                    break  # EIO: el slave se cerro; el hijo pudo haber salido
                if not chunk:
                    break
                output.extend(chunk)
            if answers:
                p, a = answers[0]
                # Los prompts de retry (p. ej. "Token de GitHub (PAT): ") son
                # identicos entre intentos: matchear por CONTEO de apariciones,
                # no por pertenencia — si no, los answers de retry se disparan
                # en rafaga contra la primera ocurrencia. El conteo requerido
                # es 1 + los prompts IGUALES ya respondidos (cada answer se
                # atribuye a su propia ocurrencia): si un answer distinto se
                # envio en medio (p. ej. "Mantener..." -> "Token..."), el
                # segundo prompt NO se cuenta como ocurrencia extra del primero.
                needed = 1 + sum(1 for fp in fired if fp == p)
                if bytes(output).count(p) >= needed:
                    # Race con read -s: el harness ve el prompt cuando el hijo lo
                    # printf-ea, pero el hijo todavia no entro a read (que apaga
                    # ECHO). Esperar 50ms para que el termios del read -rs este
                    # activo; si no, el kernel ECOA el answer y queda en la salida.
                    time.sleep(0.05)
                    os.write(fd, a)
                    fired.append(p)
                    answers.pop(0)
            wpid, status = os.waitpid(pid, os.WNOHANG)
            if wpid == pid:
                save_output()
                if os.WIFEXITED(status):
                    return os.WEXITSTATUS(status)
                if os.WIFSIGNALED(status):
                    return 128 + os.WTERMSIG(status)
                return 1
        # salida por break (EIO/EOF) o deadline: reaping paciente antes de
        # declarar timeout — el hijo pudo haber salido justo despues del read
        for _ in range(50):
            try:
                wpid, status = os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                break
            if wpid == pid:
                save_output()
                if os.WIFEXITED(status):
                    return os.WEXITSTATUS(status)
                if os.WIFSIGNALED(status):
                    return 128 + os.WTERMSIG(status)
                return 1
            time.sleep(0.02)
        # timeout real: hijo sigue vivo
        try:
            os.kill(pid, 9)
        except OSError:
            pass
        save_output()
        return 201
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
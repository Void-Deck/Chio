#!/usr/bin/env python3
"""Capture the appearance study from a release binary in real POSIX terminals.

Writes six reviewable casts plus initial-frame casts for browser screenshots.
Add --render-previews to produce six PNGs with the vendored player and an
externally installed Node/Playwright runtime. Nothing is built or published.
Full logs and terminal-restoration evidence stay in the supplied output directory.
This probe reads only the example's fixed synthetic content; no services are used.
"""
import argparse
import codecs
import errno
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import shutil
import struct
import subprocess
import termios
import time


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terminal_smoke", ROOT / "Scripts/ci/terminal-smoke.py")
screen_reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen_reader)


def terminal_events(captured):
    """Omit only the known reader notice before the first ANSI control.

    Keep all terminal setup bytes and timestamps. Unknown startup output fails
    rather than being hidden; full logs and full casts retain the entire session.
    """
    prefix = ""
    for index, event in enumerate(captured):
        control = event[2].find("\x1b")
        if control < 0:
            prefix += event[2]
            continue
        prefix += event[2][:control]
        notice = "Terminal reader available: start with --reader or press F12 in the running app."
        assert prefix.strip() in ("", notice), f"Unexpected terminal startup output: {prefix!r}"
        return [[event[0], event[1], event[2][control:]]] + captured[index + 1:]
    raise AssertionError("Terminal capture has no ANSI setup controls")


def capture(binary, output, recipe, width, height, label, verify_only):
    screen_reader.WIDTH, screen_reader.HEIGHT = width, height
    master, slave = pty.openpty()
    original = termios.tcgetattr(slave)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
    # Record only the terminal UI; the native browser companion has its own UI
    # and announces an ephemeral local URL before the terminal starts.
    environment = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor", SWIFTTUI_COMPANION="off")
    for key in ("NO_COLOR", "CLICOLOR", "CLICOLOR_FORCE", "FORCE_COLOR"):
        environment.pop(key, None)
    command = [str(binary), "--appearance", "--treatment", recipe]
    began = time.monotonic()
    try:
        process = subprocess.Popen(command, cwd=ROOT, stdin=slave, stdout=slave, stderr=slave, env=environment)
    except BaseException:
        os.close(master)
        os.close(slave)
        raise
    decoder = codecs.getincrementaldecoder("utf-8")()
    raw, events, phases = bytearray(), [], []
    name = f"{recipe}-{label}"

    def receive(timeout=0.05):
        if not select.select([master], [], [], timeout)[0]:
            return False
        try:
            data = os.read(master, 65536)
        except OSError as error:
            if error.errno == errno.EIO:
                return False
            raise
        if not data:
            return False
        raw.extend(data)
        assert len(raw) < 2_000_000, "Unexpected unbounded terminal output"
        events.append([round(time.monotonic() - began, 4), "o", decoder.decode(data)])
        return True

    def phase(title, expected, keys=b"", hold=0.5, absent=()):
        if keys:
            os.write(master, keys)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            receive()
            screen = screen_reader.screen(raw)
            if all(text in screen for text in expected) and all(text not in screen for text in absent):
                break
        else:
            raise AssertionError(f"{name}: {title}\n{screen_reader.screen(raw)}")
        until = time.monotonic() + hold
        while time.monotonic() < until:
            receive()
        assert all(text in screen_reader.screen(raw) for text in expected), title
        assert all(text not in screen_reader.screen(raw) for text in absent), title
        phases.append(dict(title=title, elapsed=round(time.monotonic() - began, 4)))

    def write_cast(path, captured):
        header = dict(version=2, width=width, height=height,
                      env=dict(TERM="xterm-256color", COLORTERM="truecolor", SWIFTTUI_COMPANION="off"),
                      title=f"Chio appearance · {recipe} · synthetic content")
        path.write_text("\n".join(json.dumps(item, ensure_ascii=False) for item in [header] + captured) + "\n")

    try:
        phase("initial", ["appearance", "Build Agent", "^Q quit"], hold=1)
        initial_events = terminal_events(list(events)) + [[round(time.monotonic() - began, 4), "o", ""]]
        (output / f"{name}-initial.txt").write_text(screen_reader.screen(raw))
        phase("edit", ["Field notes", "^Q quit"], b"\x05")
        # Move left first: native no-op End currently bubbles to ScrollView.
        # Exercise an actual End movement while keeping editing visible.
        phase("type", ["Field notes!"], b"\x1b[D\x1b[F!")
        phase("restore text", ["Field notes"], b"\x7f", absent=["Field notes!"])
        phase("compact spacing", ["spacing: compact"], b"\x04")
        phase("roomy spacing", ["spacing: roomy"], b"\x04")
        phase("recipe spacing", ["spacing: recipe"], b"\x04")
        phase("graphs", ["Instruments", "21.4 °C"], b"\x07")
        phase("agents", ["Agents", "Build Agent"], b"\x0c", hold=1)
        published = terminal_events(list(events)) + [[round(time.monotonic() - began, 4), "o", ""]]
        assert not termios.tcgetattr(slave)[3] & (termios.ECHO | termios.ICANON)
        os.write(master, b"\x11")
        deadline = time.monotonic() + 10
        while process.poll() is None and time.monotonic() < deadline:
            receive()
        process.wait(timeout=1)
        while receive(0):
            pass
        assert process.returncode == 0
        assert termios.tcgetattr(slave) == original, "Terminal settings were not restored"
        assert b"\x1b[?1049l" in raw and b"\x1b[?25h" in raw
        clip_text = "".join(event[2] for event in published)
        for unwanted in ("\x1b[?1049l", "runtime warning", "error:", "/Users/",
                         "Browser accessibility companion", "http://127.0.0.1:", "Terminal reader available:"):
            assert unwanted not in clip_text, f"Unexpected published diagnostic: {unwanted}"
        assert b"error:" not in raw.lower()
        if not verify_only:
            write_cast(output / f"{name}.cast", published)
            write_cast(output / f"{name}-initial.cast", initial_events)
        return dict(name=name, cells=[width, height], phases=phases, exit=process.returncode,
                    termios_restored=True, cursor_restored=True, alternate_screen_restored=True,
                    diagnostics=[line for line in raw.decode("utf-8").splitlines() if "runtime warning" in line.lower()])
    finally:
        try:
            (output / f"{name}-full.log").write_bytes(raw)
            write_cast(output / f"{name}-full.cast", events)
        finally:
            try:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
            finally:
                os.close(master)
                os.close(slave)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / ".build/appearance-captures")
    parser.add_argument("--verify-only", action="store_true", help="Check three 36×18 sessions; do not produce publishable clips.")
    parser.add_argument("--render-previews", action="store_true", help="Also render six PNGs; requires Node, Playwright and its Chromium browser.")
    parser.add_argument("--node", default="node", help="Node executable name or path (default: node on PATH).")
    parser.add_argument("--playwright", help="Installed Playwright module directory; otherwise Node resolves playwright normally.")
    args = parser.parse_args()
    args.binary = args.binary.resolve()
    args.output = args.output.resolve()
    if not args.binary.is_file() or not os.access(args.binary, os.X_OK):
        parser.error(f"Executable release binary not found: {args.binary}; build it separately first.")
    if args.verify_only and args.render_previews:
        parser.error("--verify-only does not produce the clips needed by --render-previews.")
    renderer = ROOT / "Scripts/docs/render-terminal-previews.cjs"
    render_command = None
    if args.render_previews:
        if args.output.is_relative_to(ROOT) and not args.output.is_relative_to(ROOT / ".build"):
            parser.error("Render output must be outside the checkout or beneath its ignored .build directory; copy reviewed media separately.")
        node = shutil.which(args.node)
        if node is None:
            parser.error("Node executable not found; supply --node with an installed runtime path.")
        if args.output.exists() and (not args.output.is_dir() or any(args.output.iterdir())):
            parser.error("Rendering requires a fresh output directory; choose a new --output.")
        render_command = [node, str(renderer)]
        if args.playwright:
            render_command.extend(["--playwright", str(Path(args.playwright).resolve())])
        try:
            subprocess.run(render_command + ["--check"], check=True, timeout=30)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            parser.error(f"Preview rendering prerequisite failed: {error}")
    args.output.mkdir(parents=True, exist_ok=True)
    sizes = [(36, 18, "compact")] if args.verify_only else [(100, 30, "wide"), (36, 64, "narrow")]
    results = [capture(args.binary.resolve(), args.output, recipe, width, height, label, args.verify_only)
               for recipe in ("chio", "opencode", "btop") for width, height, label in sizes]
    evidence = dict(binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),
                    synthetic_only=True, sessions=results)
    (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"PASS: {len(results)} real terminal sessions with clean exit and restored settings", flush=True)
    diagnostic_count = sum(len(result["diagnostics"]) for result in results)
    if diagnostic_count:
        print(f"NOTE: {diagnostic_count} runtime warnings retained in full logs and evidence.json; trimming does not fix them.", flush=True)
    if render_command:
        initial_casts = [str(args.output / f"{result['name']}-initial.cast") for result in results]
        subprocess.run(render_command + initial_casts, check=True, timeout=180)
        print(f"PASS: six PNG previews in {args.output}; inspect clips, stills and full logs before copying media.")


if __name__ == "__main__":
    main()

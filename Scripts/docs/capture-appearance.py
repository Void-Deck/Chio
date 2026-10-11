#!/usr/bin/env python3
"""Capture the appearance study from a release binary in real POSIX terminals.

Writes six reviewable casts plus initial-frame casts for browser screenshots.
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
import struct
import subprocess
import termios
import time


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terminal_smoke", ROOT / "Scripts/ci/terminal-smoke.py")
screen_reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen_reader)


def capture(binary, output, recipe, width, height, label, verify_only):
    screen_reader.WIDTH, screen_reader.HEIGHT = width, height
    master, slave = pty.openpty()
    original = termios.tcgetattr(slave)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
    environment = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor")
    for key in ("NO_COLOR", "CLICOLOR", "CLICOLOR_FORCE", "FORCE_COLOR"):
        environment.pop(key, None)
    command = [str(binary), "--appearance", "--treatment", recipe]
    began = time.monotonic()
    process = subprocess.Popen(command, cwd=ROOT, stdin=slave, stdout=slave, stderr=slave, env=environment)
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
                      env=dict(TERM="xterm-256color", COLORTERM="truecolor"),
                      title=f"Chio appearance · {recipe} · synthetic content")
        path.write_text("\n".join(json.dumps(item, ensure_ascii=False) for item in [header] + captured) + "\n")

    try:
        phase("initial", ["appearance", "Build Agent", "^Q quit"], hold=1)
        initial_events = list(events) + [[round(time.monotonic() - began, 4), "o", ""]]
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
        published = list(events) + [[round(time.monotonic() - began, 4), "o", ""]]
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
        for unwanted in ("\x1b[?1049l", "runtime warning", "error:", "/Users/"):
            assert unwanted not in clip_text, f"Unexpected published diagnostic: {unwanted}"
        assert b"error:" not in raw.lower()
        if not verify_only:
            write_cast(output / f"{name}.cast", published)
            write_cast(output / f"{name}-initial.cast", initial_events)
        return dict(name=name, cells=[width, height], phases=phases, exit=process.returncode,
                    termios_restored=True, cursor_restored=True, alternate_screen_restored=True,
                    diagnostics=[line for line in raw.decode("utf-8").splitlines() if "runtime warning" in line.lower()])
    finally:
        (output / f"{name}-full.log").write_bytes(raw)
        write_cast(output / f"{name}-full.cast", events)
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
        os.close(master)
        os.close(slave)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / ".build/appearance-captures")
    parser.add_argument("--verify-only", action="store_true", help="Check three 36×18 sessions; do not produce publishable clips.")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    sizes = [(36, 18, "compact")] if args.verify_only else [(100, 30, "wide"), (36, 64, "narrow")]
    results = [capture(args.binary.resolve(), args.output, recipe, width, height, label, args.verify_only)
               for recipe in ("chio", "opencode", "btop") for width, height, label in sizes]
    evidence = dict(binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),
                    synthetic_only=True, sessions=results)
    (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"PASS: {len(results)} real terminal sessions with clean exit and restored settings")


if __name__ == "__main__":
    main()

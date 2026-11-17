#!/usr/bin/env python3
"""Record the built waveform example in a bounded real POSIX terminal.

Only local synthetic content is exercised. Nothing is built, installed or
published. Replay the resulting *-initial.cast files with the repository's
Scripts/docs/render-terminal-previews.cjs to produce PNGs separately.
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


def load_script(name, relative):
    specification = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


appearance = load_script("appearance_capture", "Scripts/docs/capture-appearance.py")
screen_reader = appearance.screen_reader


def capture(binary, output, theme):
    name = f"waveform-{theme}"
    width, height = 80, 32
    screen_reader.WIDTH, screen_reader.HEIGHT = width, height
    master, slave = pty.openpty()
    original = termios.tcgetattr(slave)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
    environment = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor",
                       SWIFTTUI_COMPANION="off")
    for key in ("NO_COLOR", "CLICOLOR", "CLICOLOR_FORCE", "FORCE_COLOR"):
        environment.pop(key, None)
    began = time.monotonic()
    raw, events, phases = bytearray(), [], []
    process = None

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

    def phase(title, expected, keys=b"", hold=0.3, absent=()):
        expected = [*expected, "chio waveform · synthetic CPAP night"]
        if keys:
            os.write(master, keys)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            receive()
            screen = screen_reader.screen(raw)
            if all(text in screen for text in expected) and all(text not in screen for text in absent):
                break
            assert process.poll() is None, f"Preview exited during {title}"
        else:
            raise AssertionError(f"{title}\n{screen_reader.screen(raw)}")
        until = time.monotonic() + hold
        while time.monotonic() < until:
            receive()
        screen = screen_reader.screen(raw)
        assert all(text in screen for text in expected), f"Unstable {title}\n{screen}"
        assert all(text not in screen for text in absent), f"Unstable {title}\n{screen}"
        phases.append(dict(title=title, elapsed=round(time.monotonic() - began, 4),
                           cells=[width, height]))
        return screen

    def write_cast(path, captured, columns=80, rows=32):
        header = dict(version=2, width=columns, height=rows,
                      env=dict(TERM="xterm-256color", COLORTERM="truecolor", SWIFTTUI_COMPANION="off"),
                      title=f"Chio waveform · {theme} · synthetic content")
        path.write_text("\n".join(json.dumps(item, ensure_ascii=False)
                                  for item in [header] + captured) + "\n")

    def still(capture_name):
        captured = appearance.terminal_events(list(events))
        captured.append([round(time.monotonic() - began, 4), "o", ""])
        write_cast(output / f"{capture_name}-initial.cast", captured, width, height)
        (output / f"{capture_name}.txt").write_text(screen_reader.screen(raw))

    try:
        process = subprocess.Popen([str(binary), "--theme", theme, "--window", "8h"], cwd=ROOT, stdin=slave, stdout=slave,
                                   stderr=slave, env=environment)
        decoder = codecs.getincrementaldecoder("utf-8")()
        phase("whole night", ["22:31–06:31 · 8h", theme], hold=1.2)
        assert any(0x2801 <= ord(c) <= 0x28FF for c in screen_reader.screen(raw)), "No waveform braille painted"
        phase("one hour", ["02:01–03:01 · 1h"], b"+", hold=0.5)
        phase("ten minutes", ["02:26–02:36 · 10m"], b"+", hold=1.2)
        phase("two minutes", ["02:30:00–02:32:00 · 2m"], b"+", hold=1.2)
        # Breath-level detail reads better than the whole-night band as the still.
        still(name)
        for step, clock in enumerate(("02:30:30–02:32:30", "02:31:00–02:33:00", "02:31:30–02:33:30"), 1):
            phase(f"pan right {step}", [f"{clock} · 2m"], b"\x1b[C", hold=0.6)
        next_theme = {"default": "light", "light": "btop", "btop": "default"}[theme]
        phase("theme", [f"02:31:30–02:33:30 · 2m · {next_theme}"], b"t", hold=1.2)
        published = appearance.terminal_events(list(events))
        published.append([round(time.monotonic() - began, 4), "o", ""])
        clip_text = "".join(event[2] for event in published if event[1] == "o")
        for unwanted in ("\x1b[?1049l", "runtime warning", "error:", "/Users/",
                         "Browser accessibility companion", "http://127.0.0.1:", "Terminal reader available:"):
            assert unwanted not in clip_text, f"Unexpected captured diagnostic: {unwanted}"
        assert not termios.tcgetattr(slave)[3] & (termios.ECHO | termios.ICANON), "Terminal was not raw"
        os.write(master, b"q")
        deadline = time.monotonic() + 10
        while process.poll() is None and time.monotonic() < deadline:
            receive()
        process.wait(timeout=1)
        while receive(0):
            pass
        assert process.returncode == 0, f"Preview exit: {process.returncode}"
        assert termios.tcgetattr(slave) == original, "Terminal settings were not restored"
        assert b"\x1b[?1049l" in raw and b"\x1b[?25h" in raw, "Screen/cursor restoration absent"
        assert b"error:" not in raw.lower(), "Error diagnostic in full terminal output"
        write_cast(output / f"{name}.cast", published)
        return dict(name=name, cells=[80, 32], theme=theme,
                    binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                    phases=phases, synthetic_only=True, exit=process.returncode,
                    termios_restored=True, cursor_restored=True, alternate_screen_restored=True)
    finally:
        try:
            if process is not None and process.poll() is None:
                process.kill()
                process.wait(timeout=5)
                while receive(0):
                    pass
            (output / f"{name}-full.log").write_bytes(raw)
            write_cast(output / f"{name}-full.cast", events)
        finally:
            os.close(master)
            os.close(slave)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    binary, output = arguments.binary.resolve(), arguments.output.resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        parser.error("Supply the existing executable release binary; build it separately first.")
    if output.is_relative_to(ROOT) and not output.is_relative_to(ROOT / ".build"):
        parser.error("Output must be outside the checkout or beneath ignored .build.")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        parser.error("Choose a fresh output directory; existing captures are never replaced.")
    output.mkdir(parents=True, exist_ok=True)
    evidence = [capture(binary, output, theme) for theme in ("default", "light", "btop")]
    (output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"PASS: three themes, whole night, zoom, pan, theme and terminal restoration; captures in {output}")


if __name__ == "__main__":
    main()

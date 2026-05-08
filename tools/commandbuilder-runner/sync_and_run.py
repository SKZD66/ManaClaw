from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
RUNNER_DIR = ROOT / "tools" / "commandbuilder-runner"
RUNNER_SRC = RUNNER_DIR / "src"
SOURCE_COMMAND_BUILDER = ROOT / "entry" / "src" / "main" / "cangjie" / "CommandBuilder.cj"
TARGET_COMMAND_BUILDER = RUNNER_SRC / "CommandBuilder.cj"


def run_cmd(cmd: list[str], cwd: pathlib.Path) -> int:
    proc = subprocess.run(cmd, cwd=str(cwd), text=True)
    return proc.returncode


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync CommandBuilder.cj and run commandbuilder-runner"
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "Reference" / "commandbuilder_manual_output.txt"),
        help="Output file path for generated commands",
    )
    args = parser.parse_args()

    if not SOURCE_COMMAND_BUILDER.exists():
        print(f"[ERROR] Source file not found: {SOURCE_COMMAND_BUILDER}")
        return 2

    RUNNER_SRC.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE_COMMAND_BUILDER, TARGET_COMMAND_BUILDER)
    print(f"[OK] Synced: {SOURCE_COMMAND_BUILDER} -> {TARGET_COMMAND_BUILDER}")

    output_path = pathlib.Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8", newline="\n") as f:
        proc = subprocess.run(
            ["cjpm", "run"],
            cwd=str(RUNNER_DIR),
            stdout=f,
            stderr=subprocess.STDOUT,
            text=True,
        )

    if proc.returncode != 0:
        print(f"[ERROR] cjpm run failed, see: {output_path}")
        return proc.returncode

    print(f"[OK] Generated output: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

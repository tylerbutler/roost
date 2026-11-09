"""Offline checks for release workflow guards and shell arguments."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github/workflows"


class ReleaseWorkflowTests(unittest.TestCase):
    def test_git_only_workspace_and_native_continuation(self):
        config = tomllib.loads((ROOT / "gleam.toml").read_text())["tools"]["trellis"]
        self.assertEqual(config["members"], ["."])
        self.assertEqual(config["publish"]["lifecycle"]["default"], "git_only")
        self.assertEqual(config["publish"]["exact_tag_format"], "v{version}")
        self.assertEqual(config["publish"]["package_tags"], ["exact"])
        self.assertEqual(config["release"], {
            "resume": True, "auto_pre": True, "skip_unchanged": True,
        })
        tools = tomllib.loads((ROOT / "mise.toml").read_text())["tools"]
        self.assertEqual(tools["github:tylerbutler/trellis"], "1.3.0")

    def test_trusted_merge_guard_and_checkout(self):
        workflow = (WORKFLOWS / "auto-tag.yml").read_text()
        guard = workflow.split("    if: >-\n", 1)[1].split("    runs-on:", 1)[0]
        self.assertEqual(" ".join(guard.split()), (
            "(github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main') || "
            "(github.event_name == 'pull_request' && "
            "github.event.pull_request.merged == true && "
            "github.event.pull_request.merge_commit_sha != '' && "
            "github.event.pull_request.base.ref == 'main' && "
            "github.event.pull_request.head.ref == 'release/pending' && "
            "github.event.pull_request.head.repo.full_name == github.repository)"
        ))
        self.assertIn(
            "ref: ${{ github.event_name == 'workflow_dispatch' && 'main' || "
            "github.event.pull_request.merge_commit_sha }}",
            workflow,
        )
        self.assertIn("fetch-depth: 0", workflow)
        self.assertIn("run: trellis tag create --github-release", workflow)

    def test_main_only_preparation_and_serialized_writes(self):
        workflow = (WORKFLOWS / "release.yml").read_text()
        self.assertIn("if: github.ref == 'refs/heads/main'", workflow)
        self.assertIn("ref: main", workflow)
        for name in ("release.yml", "auto-tag.yml"):
            text = (WORKFLOWS / name).read_text()
            self.assertIn(
                "concurrency:\n  group: trellis-release\n  queue: max\n"
                "  cancel-in-progress: false",
                text,
            )
            self.assertIn("secrets.RELEASE_APP_ID", text)
            self.assertIn("secrets.RELEASE_APP_PRIVATE_KEY", text)
            self.assertIn("permissions:\n  contents: read", text)
            self.assertNotIn("pull_request_target", text)

    def test_ci_covers_tags_without_publication(self):
        self.assertIn("tags: ['v*']", (WORKFLOWS / "ci.yml").read_text())
        for path in WORKFLOWS.glob("*.yml"):
            text = path.read_text()
            self.assertNotRegex(text, r"\b(?:gleam|trellis)\s+publish\b|HEX_API_KEY")

    def test_mise_replaces_legacy_tool_installation(self):
        self.assertFalse((ROOT / ".tool-versions").exists())
        tools = tomllib.loads((ROOT / "mise.toml").read_text())["tools"]
        for tool, version in (
            ("erlang", "27.2.1"), ("gleam", "1.16.0"),
            ("just", "1.38.0"), ("rebar", "3.26.0"),
            ("node", "22"), ("pnpm", "10"),
        ):
            self.assertEqual(tools[tool], version)
        workflow = (WORKFLOWS / "ci.yml").read_text()
        self.assertNotIn("actions/setup-gleam@", workflow)
        self.assertIn(
            "install_args: erlang gleam rebar "
            "${{ matrix.target == 'javascript' && 'node' || '' }}",
            workflow,
        )
        self.assertIn("run: gleam deps download", workflow)

    def test_local_commands_preserve_argument_boundaries(self):
        recipes = (ROOT / "justfile").read_text()
        for name, command in (
            ("change", "changelog new"),
            ("changelog-preview", "version plan"),
            ("changelog", "version apply"),
        ):
            self.assertIn(
                f'[positional-arguments]\n{name} *ARGS:\n    trellis {command} "$@"',
                recipes,
            )

    def prepare(self, pre="", version=""):
        workflow = (WORKFLOWS / "release.yml").read_text()
        match = re.search(r"        run: \|\n((?:          .*\n)+)", workflow)
        self.assertIsNotNone(match)
        script = "\n".join(line[10:] for line in match[1].splitlines())
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "args"
            stub = Path(directory) / "trellis"
            stub.write_text('#!/bin/bash\nprintf "%s\\0" "$@" > "$CAPTURE"\n')
            stub.chmod(0o755)
            result = subprocess.run(
                ["bash", "-c", script],
                env={
                    **os.environ, "PATH": f"{directory}:{os.environ['PATH']}",
                    "CAPTURE": str(capture), "INPUT_PRE": pre, "INPUT_VERSION": version,
                },
                capture_output=True, text=True,
            )
            args = capture.read_bytes().split(b"\0")[:-1] if capture.exists() else None
            return result, [arg.decode() for arg in args] if args is not None else None

    def test_release_mode_arguments(self):
        base = ["release", "pr", "--base", "main", "--branch", "release/pending"]
        for pre in ("", "rc", "none"):
            with self.subTest(pre=pre):
                result, args = self.prepare(pre, "1.0.0")
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = base + (["--pre", pre] if pre else [])
                self.assertEqual(args, expected + ["--set", "roost=1.0.0"])
        result, args = self.prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args, base)

    def test_invalid_mode_and_shell_metacharacters(self):
        result, args = self.prepare("beta")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("::error::", result.stdout)
        self.assertIsNone(args)
        value = '1.0.0; echo unsafe $(echo unsafe) " --pre none'
        result, args = self.prepare("rc", value)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[-2:], ["--set", f"roost={value}"])
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()

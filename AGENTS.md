# AGENTS.md

Rules for every agent working on this Godot web game. The goal is an efficient, conflict-free team.

## General Principles

- Follow existing project conventions and architecture.
- Inspect relevant code before making changes.
- Make the smallest change that fully solves the task.
- Run relevant tests and checks before reporting completion.
- Never claim a test passed unless it was actually run.

## Workflow

- Explain significant trade-offs when they affect the implementation.
- Flag ambiguous requirements instead of making risky assumptions.
- Summarize changes and verification results when finished.

## Coordination (avoiding conflicts)

- Claim a task before starting it, and work only on what you claimed.
- One agent owns a file or scene at a time; ask the owner before editing it.
- Work on a dedicated branch per task (e.g. `agent-name/short-task`); never commit directly to `main`.
- Keep branches short-lived: pull and rebase on `main` before opening a pull request.
- Keep pull requests small and focused on a single task.
- Don't reformat, rename, or move files outside your task's scope.
- If you find a bug outside your task, report it instead of fixing it silently.

## Godot Practices

- Use the project's pinned Godot version; don't upgrade the engine or export templates without approval.
- Use GDScript static typing (`var speed: float = 200.0`) and follow the official GDScript style guide: `snake_case` for files, functions, and variables; `PascalCase` for classes and nodes.
- Prefer small, reusable scenes composed together over large monolithic scenes.
- Use signals to decouple nodes; avoid hard-coded `get_node()` paths across scene boundaries.
- Keep autoloads (singletons) minimal and document each one.
- Edit `.tscn` and `.tres` files through the editor when possible; never hand-merge conflicting scene files. Resolve by re-doing the change in the editor.
- Don't commit the `.godot/` cache folder or export build output.
- Put assets in their agreed folders and keep import settings consistent.

## Web Export

- Test changes in the HTML5 (web) export, not only in the editor.
- Watch build size and load time; flag any new asset or addon that adds significant weight.
- Avoid features unsupported on web (threads without proper headers, native-only plugins, filesystem assumptions).
- Keep input working for both mouse/keyboard and touch where the game supports it.

## Code Quality

- Write clear names and comment the "why", not the "what".
- Don't leave debug prints, dead code, or commented-out code in commits.
- Add or update tests (e.g. GUT or GdUnit) for gameplay logic you change, when the project has a test setup.
- Never commit secrets, keys, or credentials.

## Reporting

When finishing a task, report:
1. What changed and which files.
2. How it was verified (tests run, export tested), with actual results.
3. Any open questions, risks, or follow-ups.

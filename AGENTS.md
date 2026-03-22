# AGENTS.md — Coding Agent Guide for `molecule`

## Project Overview

`molecule` is a module-centric generative/meta language written in **Nim**. It is a
transpiler that reads `.mole` source files, tokenizes and parses them into an AST,
then emits JavaScript output. The project is in early development (lexer + partial
AST + JS backend).

- Entry point: `src/mole.nim`
- Example source: `example/main.mole`
- Output target: `example/main.js`
- Nim package manifest: `mole.nimble`

No Cursor rules, Copilot instructions, or existing AGENTS.md were present.

---

## Build Commands

```sh
# Build the binary (debug)
nimble build

# Build in release mode
nimble build -d:release

# Compile directly with nim (debug)
nim c src/mole.nim

# Compile in release mode
nim c -d:release -o:mole src/mole.nim

# Run the transpiler (reads example/main.mole, writes example/main.js)
nimble run
# or after building:
./mole
```

---

## Lint / Check Commands

Nim does not have a separate lint step; the compiler itself enforces correctness.

```sh
# Type-check and report errors without producing a binary
nim check src/mole.nim

# Check with extra warnings (recommended before committing)
nim check --hints:on --warnings:on src/mole.nim
```

There is no dedicated linter configured. Use `nim check` as the lint equivalent.

---

## Testing

No test suite exists yet. When adding tests:

- Place test files under `tests/` (nimble convention).
- Name test files `t<name>.nim` (e.g., `tests/tlexer.nim`).
- Use the stdlib `std/unittest` module.

```sh
# Run all tests (once tests/ directory exists)
nimble test

# Run a single test file directly
nim c -r tests/tlexer.nim

# Run a single named test suite / case (unittest filter)
nim c -r tests/tlexer.nim "suite name"
```

---

## Repository Layout

```
mole.nimble          # Package manifest, version, dependencies
src/
  mole.nim           # All source code (single file for now)
example/
  main.mole          # Example .mole program
  main.js            # Transpiler output (generated, do not edit)
```

---

## Code Style Guidelines

### General

- **Language**: Nim (requires `>= 1.6.4`; project currently uses 2.2.0).
- Keep the codebase simple and direct. Avoid over-abstraction.
- Prefer short, single-responsibility `proc`s.
- Commented-out code (e.g., disabled `echo` debug calls) is acceptable during
  active development but should be removed before merging stable features.

### Formatting

- **Indentation**: 4 spaces (no tabs).
- Keep lines reasonably short; no hard limit enforced, but aim for ≤ 100 chars.
- Opening braces / `do:` blocks follow Nim conventions — no brace-style choice
  needed (Nim uses indentation).
- Align multi-line `Token(...)` / object constructor calls so each field is on
  its own line, indented 4 spaces under the constructor:
  ```nim
  tokens.add(
      Token(
          value: id,
          tokenType: loopDef
      )
  )
  ```

### Imports

- Use the grouped import syntax for stdlib modules:
  ```nim
  import std/[strutils, re, syncio]
  ```
- List stdlib imports first, then third-party, then local modules (when the
  project grows to multiple files).
- Do not use wildcard imports (`import foo` that pulls everything into scope
  without qualification) unless it is the Nim idiomatic default for that module.

### Naming Conventions

| Construct | Convention | Example |
|-----------|-----------|---------|
| Types / enums | `PascalCase` | `TokenType`, `NodeRef` |
| Enum variants | `camelCase` | `rootProgram`, `funcDef`, `varDef` |
| Procs / funcs | `camelCase` | `constructAST`, `characterAnalyse` |
| Variables | `camelCase` | `nodeStack`, `strLiteral` |
| Constants / compile-time | `camelCase` or `ALL_CAPS` (prefer `camelCase`) | `keywords` |
| File-scope mutable state | `camelCase` module-level `var` | `tokens`, `bracesStack` |

- Use descriptive names: `handleKeywordIdentifiers`, `constructAST`, `astToLanguage`.
- Abbreviations are acceptable when widely understood: `tok`, `ch`, `id`, `prog`.

### Types

- Define related types together in a single `type` block.
- Use `ref object` (`NodeRef = ref Node`) for heap-allocated recursive structures
  (AST nodes).
- Use plain `object` for value types (e.g., `Token`).
- Prefer `seq[T]` for dynamic lists; use `array` only for fixed-size data.
- Annotate proc return types explicitly when the return type is non-trivial:
  ```nim
  proc constructAST(): NodeRef =
  proc astToLanguage(ast: NodeRef): string =
  ```

### Error Handling

- Use `quit "error message"` for unrecoverable parse errors (current pattern).
- Prefer descriptive error messages that include context (e.g., the offending line).
- Do not use exceptions for expected parse failures during early development;
  introduce structured error types when the error surface grows.
- Validate stack state before `pop()` operations and call `quit` with context if
  invariants are violated.

### AST / Transpiler Patterns

- Every AST node case should be handled explicitly in `case` statements; use
  `else: continue` (or `else: return prog`) to safely skip unhandled nodes rather
  than letting control fall through silently.
- Use a `nodeStack: seq[NodeRef]` to track the current parent during tree
  construction; push on open-bracket tokens, pop on close-bracket tokens.
- `NodeRef` fields `id`, `parent`, `params` are present but may be `nil`; guard
  before dereferencing.
- The `debug` proc is a no-op stub (comment-based toggle). Use it for temporary
  tracing; do not leave live `echo` calls in production code paths.

### Comments

- Use `#` for single-line comments.
- Describe *why*, not *what*, for non-obvious logic.
- Comment-out debugging `echo` calls rather than deleting them during active work:
  ```nim
  # echo "[debug]" & msg
  ```

### Commit Style

Commits in this repo follow a lightweight conventional-commits style:
```
fix: add `print` functionality
add partial look ahead and node translations
add primitives
```
Prefer short, imperative present-tense summaries. Use `fix:` prefix for bug fixes.

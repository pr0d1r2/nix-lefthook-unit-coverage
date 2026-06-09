# SPEC — nix-lefthook-unit-coverage

## §G Goal

Lefthook-compatible test-coverage enforcer. Verify every implementation
file under configured source dirs has a matching test spec, using
language-agnostic `[[rules]]` defined in a `.unit-coverage.toml`. One repo
can mix many languages/frameworks (bats, RSpec, minitest, …) via multiple
rules. Nix flake pkg. Opensource-safe: zero credentials, zero local paths,
zero private refs.

## §C Constraints

- C1: Pure bash — no Python/Ruby/etc runtime deps; config parsed with `taplo`
- C2: Nix flake — `writeShellApplication` pkg, devShells via inline
  `pkgs.mkShell` (flattened: `flake = false` `-src` inputs +
  `nixpkgs-lock`, no `nix-dev-shell-agentic`)
- C3: MIT license
- C4: Multi-platform: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`,
  `aarch64-linux`
- C5: Detached from parent project — no credential leaks, no hardcoded
  local paths, no private repo refs
- C6: All config via `.unit-coverage.toml` rules plus env-var overrides —
  no other config files beyond the lint baseline
- C7: Exit non-zero when any impl file lacks its spec — hard enforcement,
  blocks the hook stage

## §I Interfaces

- I.cli: `lefthook-unit-coverage` — main binary, exit 1 when specs missing
  or config invalid, exit 0 on pass
- I.config: `.unit-coverage.toml` — top-level `allowlist` key plus `[[rules]]`
  array. Per-rule fields: `glob` (required, e.g. `*.sh`), `dirs` (required),
  `test_dir` (required), `pattern` (`mirror`|`flat`, default `mirror`),
  `test_ext`, `test_suffix`, `strip`, `normalize` (bool), `exclude`
- I.env: `LEFTHOOK_UNIT_COVERAGE_CONFIG` (default `.unit-coverage.toml`),
  `LEFTHOOK_UNIT_COVERAGE_ROOT` (default git toplevel; switches file listing
  from `git ls-files` to `find` for testing),
  `LEFTHOOK_UNIT_COVERAGE_TIMEOUT` (seconds, default `30`, applied by the hook)
- I.allowlist: file named by config `allowlist` key (default
  `.coverage-allowlist`) — newline-separated impl paths to skip; `#` comments
  and blank lines ignored
- I.remote: `lefthook-remote.yml` — consumers add as lefthook remote; binds
  to `pre-push`
- I.flake: `packages.${system}.default` — Nix pkg output, name
  `lefthook-unit-coverage`, `runtimeInputs = [ git taplo coreutils findutils ]`
- I.devshell: `devShells.${system}.default` + `.#ci` — dev/CI shells built
  inline with `pkgs.mkShell`
- I.ci: `.github/workflows/ci.yml` — linux + macos via
  `nix-lefthook-ci-action`; `.github/workflows/update-pins.yml` — daily
  `nixpkgs-lock` bump PR

## §V Invariants

- V1: Each rule scans `list_files` for entries matching `glob`'s extension
  that live under one of `dirs`; every such impl file must have its mapped
  spec on disk or the run exits 1
- V2: `mirror` pattern preserves the source directory tree under `test_dir`;
  `flat` pattern maps to `test_dir` using the stem only
- V3: `strip` removes a leading path prefix from the impl dir before mapping
  (e.g. `app/models/user.rb` → `spec/models/user_spec.rb`)
- V4: `test_ext` overrides the spec extension (e.g. `.sh` impl → `.bats`
  spec); absent, the spec reuses the source extension
- V5: `test_suffix` is appended to the stem (e.g. `_spec`, `_test`)
- V6: `normalize = true` converts underscores to dashes in the stem; both the
  normalized and the raw-stem spec names are accepted
- V7: `exclude` directory prefixes suppress matching impl files within a rule
- V8: Allowlisted impl paths (config `allowlist` file) are skipped; `#`
  comments and blank lines in the allowlist are ignored
- V9: Missing config file → exit 1 with a `not found` message and remediation
  hint
- V10: Unknown `pattern` value → exit 1 with an `unknown pattern` message
- V11: Empty config / no `[[rules]]` → vacuous pass (exit 0)
- V12: Multiple rules are all evaluated; a gap in any rule fails the whole run;
  total missing count is reported on stderr
- V13: `LEFTHOOK_UNIT_COVERAGE_ROOT` set → list files via `find` (untracked
  files visible); unset → list via `git ls-files`
- V14: Hook binds to `pre-push` and wraps the binary in
  `timeout ${LEFTHOOK_UNIT_COVERAGE_TIMEOUT:-30}`
- V15: No credentials, secrets, tokens, API keys, or private paths in any
  tracked file
- V16: No hardcoded local filesystem paths (enforced by
  `nix-lefthook-git-no-local-paths` hook)
- V17: `dev.sh` sets `BATS_LIB_PATH` and auto-installs lefthook when hooks
  are missing; `@BATS_LIB_PATH@` is substituted by the default devShell
- V18: CI runs the full lefthook pre-commit + pre-push suite on linux + macos
- V19: All linters pass: shellcheck, shfmt, nixfmt, statix, deadnix, yamllint,
  typos, editorconfig-checker, trailing-whitespace, missing-final-newline,
  git-conflict-markers, git-no-local-paths, file-size-check,
  nix-no-embedded-shell
- V20: `packages.${system}.default` is built `writeShellApplication` from
  `./lefthook-unit-coverage.sh` with the four runtime inputs above —
  preserved verbatim across the flatten
- V21: `flake.lock` carries only `flake = false` `-src` leaves +
  `nixpkgs-lock`; no `nix-dev-shell-agentic` and no near-cyclic
  `agentic → cavekit` graph

## §T Tasks

| id | status | task | cites |
| --- | --- | --- | --- |
| T1 | x | core enforcer: per-rule scan, map impl→spec, exit 1 on gaps | V1,V12,I.cli |
| T2 | x | TOML rule parsing via taplo (glob, dirs, test_dir, pattern, …) | C1,I.config |
| T3 | x | mirror + flat patterns, strip prefix, test_ext, test_suffix | V2,V3,V4,V5 |
| T4 | x | normalize underscores→dashes with raw-stem fallback | V6 |
| T5 | x | exclude dirs + allowlist file with comment/blank handling | V7,V8,I.allowlist |
| T6 | x | error handling: missing config, unknown pattern, vacuous pass | V9,V10,V11 |
| T7 | x | file listing: git ls-files vs find via ROOT env override | V13,I.env |
| T8 | x | Nix flake pkg (`writeShellApplication`, 4 runtime inputs) | C2,I.flake,V20 |
| T9 | x | flatten flake: `-src` leaves + nixpkgs-lock, inline devShells | C2,V21,I.devshell |
| T10 | x | lefthookWrappersFor + batsWithLibsFor helpers in flake | C2,I.devshell |
| T11 | x | lefthook-remote.yml binding pre-push with timeout wrapper | V14,I.remote |
| T12 | x | dev.sh — BATS_LIB_PATH + auto-install | V17 |
| T13 | x | unit tests: lefthook-unit-coverage.bats (22 tests) | V1-V13 |
| T14 | x | GitHub Actions CI: linux + macos | V18,I.ci |
| T15 | x | update-pins workflow: daily nixpkgs-lock bump PR | I.ci |
| T16 | x | linter suite via lefthook remotes | V19 |
| T17 | x | opensource audit: no credentials/local-paths/private-refs | V15,V16,C5 |
| T18 | x | .gitignore: result, result-*, .direnv | V15,C5 |

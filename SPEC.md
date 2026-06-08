# SPEC — flatten nix-lefthook-unit-coverage (drop nix-dev-shell-agentic)

## Goal
Remove the heavy `nix-dev-shell-agentic` flake input from this repo's
`flake.nix`. That input drags the near-cyclic
`agentic → cavekit → 6 hooks → agentic` graph into our `flake.lock`
(59 nodes today). Replace it with `flake = false` `-src` source leaves and
rebuild the `ci` + `default` devShells inline with `pkgs.mkShell`, mirroring
the proven `nix-lefthook-statix` flattened template.

## Hard constraints
- Preserve the `packages.<sys>.default = lefthook-unit-coverage` build
  VERBATIM, including its `runtimeInputs = with pkgs; [ git taplo coreutils
  findutils ]` list and `text = builtins.readFile ./lefthook-unit-coverage.sh`.
- Preserve all 4 supported systems and `forAllSystems`.
- Preserve `nixConfig` (cachix substituters).
- `dev.sh` `@BATS_LIB_PATH@` substitution must keep working.
- Only the *input structure* + devShell wiring changes. No hook logic moves.

## Input changes
Remove:
```
nix-dev-shell-agentic = { url = "github:pr0d1r2/nix-dev-shell-agentic"; inputs.nixpkgs.follows = "nixpkgs"; };
```
Keep:
```
nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
nixpkgs.follows = "nixpkgs-lock/nixpkgs";
```
Add `flake = false` `-src` leaves for the lefthook hooks this repo's own
`lefthook-remote.yml` references and that the flattened statix template wraps
(siblings-in-remotes rule). Set:
- nix-lefthook-deadnix-src
- nix-lefthook-editorconfig-checker-src
- nix-lefthook-file-size-check-src
- nix-lefthook-git-conflict-markers-src
- nix-lefthook-git-no-local-paths-src
- nix-lefthook-missing-final-newline-src
- nix-lefthook-nixfmt-src
- nix-lefthook-shellcheck-src
- nix-lefthook-shfmt-src
- nix-lefthook-trailing-whitespace-src
- nix-lefthook-typos-src
- nix-lefthook-yamllint-src

## Output changes
- Add a `lefthookWrappersFor pkgs` helper with the `wrap` builder copied
  verbatim from the statix template, restricted to the hooks above.
- Add `batsWithLibsFor pkgs` (bats-support/assert/file) for `BATS_LIB_PATH`.
- Build `ci` + `default` devShells inline with `pkgs.mkShell`:
  - `ciCommon = [ default batsWithLibs bats coreutils git lefthook nix parallel ] ++ wrappers`
  - `ci`: `packages = ciCommon; BATS_LIB_PATH = "${batsWithLibs}/share/bats";`
  - `default`: `packages = ciCommon; shellHook = replaceStrings @BATS_LIB_PATH@ dev.sh`

## Anti-bloat
No external files vendored. Only flake.nix rewrite + (if file-size-check
flags it) `config/lefthook/file_size_limits.yml` nix limit bump to 10240,
and `shfmt -i2 -ci` reformat if shfmt flags. Net addition a few hundred
lines max.

## Gate
1. `nix flake check` green.
2. `nix flake show` still lists `packages.<sys>.default = lefthook-unit-coverage`.
3. `lefthook run pre-commit --all-files` inside `nix develop` passes (no --no-verify).
4. `jq '.nodes|keys|length' flake.lock` drops substantially from 59.
Only then: branch `flatten-drop-agentic`, commit, push, draft PR.

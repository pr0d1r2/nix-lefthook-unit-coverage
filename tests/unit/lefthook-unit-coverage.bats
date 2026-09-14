#!/usr/bin/env bats

setup() {
    # BATS_LIB_PATH may contain one share/bats directory per library.  Do not
    # assume both libraries live below the first entry (as in the CI wrapper).
    load_bats_lib() {
        local library="$1" root candidate
        IFS=: read -ra bats_lib_roots <<< "${BATS_LIB_PATH:-}"
        for root in "${bats_lib_roots[@]}"; do
            # Depending on how the Nix package is assembled, BATS_LIB_PATH
            # may point at share/bats, share, or the library package itself.
            for candidate in \
                "$root/$library/load.bash" \
                "$root/bats/$library/load.bash" \
                "$root/share/bats/$library/load.bash" \
                "$root/share/$library/load.bash" \
                "$root/load.bash"; do
                if [ -f "$candidate" ]; then
                    # Source the resolved file directly.  The shared CI
                    # wrapper may set BATS_LIB_PATH to a package root rather
                    # than a Bats library search path; using `load` here
                    # re-interprets that path and can fail even after the
                    # library was resolved successfully.
                    source "$candidate"
                    return 0
                fi
            done
        done

        # Some Nix compositions expose a package root rather than the
        # conventional share/bats root.  Search that root as a last resort;
        # BATS_LIB_PATH is intentionally allowed to contain either form.
        for root in "${bats_lib_roots[@]}"; do
            [ -d "$root" ] || continue
            candidate="$(find "$root" -type f -path "*/$library/load.bash" -print -quit 2>/dev/null)"
            if [ -n "$candidate" ]; then
                source "$candidate"
                return 0
            fi
        done

        bats_bin="$(command -v bats 2>/dev/null || true)"
        if [ -n "$bats_bin" ]; then
            root="$(dirname "$bats_bin")/../share/bats"
            if [ -f "$root/$library/load.bash" ]; then
                source "$root/$library/load.bash"
                return 0
            fi
        fi
        return 1
    }
    load_bats_lib bats-support
    load_bats_lib bats-assert

    TMP="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$TMP"
    export LEFTHOOK_UNIT_COVERAGE_ROOT="$TMP"
}

write_config() {
    cat > "$TMP/.unit-coverage.toml" <<EOF
$1
EOF
}

@test "fails when config file missing" {
    LEFTHOOK_UNIT_COVERAGE_CONFIG=".unit-coverage.toml" \
    run lefthook-unit-coverage
    assert_failure
    assert_output --partial "not found"
}

@test "mirror pattern: passes when all specs exist" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
'
    mkdir -p "$TMP/scripts" "$TMP/tests/unit/scripts"
    touch "$TMP/scripts/build.sh"
    touch "$TMP/tests/unit/scripts/build.bats"

    run lefthook-unit-coverage
    assert_success
}

@test "mirror pattern: fails when spec missing" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
'
    mkdir -p "$TMP/scripts"
    touch "$TMP/scripts/build.sh"

    run lefthook-unit-coverage
    assert_failure
    assert_output --partial "scripts/build.sh"
    assert_output --partial "tests/unit/scripts/build.bats"
}

@test "mirror pattern: nested directories preserved" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts/just"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
'
    mkdir -p "$TMP/scripts/just/build" "$TMP/tests/unit/scripts/just/build"
    touch "$TMP/scripts/just/build/deploy.sh"
    touch "$TMP/tests/unit/scripts/just/build/deploy.bats"

    run lefthook-unit-coverage
    assert_success
}

@test "mirror with strip: strips prefix from impl path" {
    write_config '
[[rules]]
glob = "*.rb"
dirs = ["app"]
test_dir = "spec"
pattern = "mirror"
strip = "app"
test_suffix = "_spec"
'
    mkdir -p "$TMP/app/models" "$TMP/spec/models"
    touch "$TMP/app/models/user.rb"
    touch "$TMP/spec/models/user_spec.rb"

    run lefthook-unit-coverage
    assert_success
}

@test "mirror with strip: fails when spec missing" {
    write_config '
[[rules]]
glob = "*.rb"
dirs = ["app"]
test_dir = "spec"
pattern = "mirror"
strip = "app"
test_suffix = "_spec"
'
    mkdir -p "$TMP/app/models"
    touch "$TMP/app/models/user.rb"

    run lefthook-unit-coverage
    assert_failure
    assert_output --partial "app/models/user.rb"
    assert_output --partial "spec/models/user_spec.rb"
}

@test "flat pattern: maps to test dir without path" {
    write_config '
[[rules]]
glob = "*.rb"
dirs = ["lib"]
test_dir = "test"
pattern = "flat"
test_suffix = "_test"
'
    mkdir -p "$TMP/lib/bundix" "$TMP/test"
    touch "$TMP/lib/bundix/convert.rb"
    touch "$TMP/test/convert_test.rb"

    run lefthook-unit-coverage
    assert_success
}

@test "flat pattern: fails when spec missing" {
    write_config '
[[rules]]
glob = "*.rb"
dirs = ["lib"]
test_dir = "test"
pattern = "flat"
test_suffix = "_test"
'
    mkdir -p "$TMP/lib/bundix"
    touch "$TMP/lib/bundix/convert.rb"

    run lefthook-unit-coverage
    assert_failure
    assert_output --partial "lib/bundix/convert.rb"
    assert_output --partial "test/convert_test.rb"
}

@test "normalize: converts underscores to dashes in stem" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["nix/dev"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
normalize = true
'
    mkdir -p "$TMP/nix/dev" "$TMP/tests/unit/nix/dev"
    touch "$TMP/nix/dev/shell_hook.sh"
    touch "$TMP/tests/unit/nix/dev/shell-hook.bats"

    run lefthook-unit-coverage
    assert_success
}

@test "normalize: also accepts unnormalized name" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["nix/dev"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
normalize = true
'
    mkdir -p "$TMP/nix/dev" "$TMP/tests/unit/nix/dev"
    touch "$TMP/nix/dev/shell_hook.sh"
    touch "$TMP/tests/unit/nix/dev/shell_hook.bats"

    run lefthook-unit-coverage
    assert_success
}

@test "exclude: skips excluded directories" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
exclude = ["scripts/lefthook"]
'
    mkdir -p "$TMP/scripts/lefthook" "$TMP/scripts/build" "$TMP/tests/unit/scripts/build"
    touch "$TMP/scripts/lefthook/install.sh"
    touch "$TMP/scripts/build/deploy.sh"
    touch "$TMP/tests/unit/scripts/build/deploy.bats"

    run lefthook-unit-coverage
    assert_success
}

@test "allowlist: skips allowlisted files" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
'
    mkdir -p "$TMP/scripts"
    touch "$TMP/scripts/legacy.sh"
    echo "scripts/legacy.sh" > "$TMP/.coverage-allowlist"

    run lefthook-unit-coverage
    assert_success
}

@test "allowlist: comments and blank lines ignored" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
'
    mkdir -p "$TMP/scripts"
    touch "$TMP/scripts/legacy.sh"
    cat > "$TMP/.coverage-allowlist" <<'AL'
# This is a comment

scripts/legacy.sh
AL

    run lefthook-unit-coverage
    assert_success
}

@test "custom allowlist path from config" {
    cat > "$TMP/.unit-coverage.toml" <<'TOML'
allowlist = ".my-allowlist"

[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
TOML
    mkdir -p "$TMP/scripts"
    touch "$TMP/scripts/legacy.sh"
    echo "scripts/legacy.sh" > "$TMP/.my-allowlist"

    run lefthook-unit-coverage
    assert_success
}

@test "multiple rules: both checked" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"

[[rules]]
glob = "*.rb"
dirs = ["app"]
test_dir = "spec"
pattern = "mirror"
strip = "app"
test_suffix = "_spec"
'
    mkdir -p "$TMP/scripts" "$TMP/tests/unit/scripts"
    mkdir -p "$TMP/app/models" "$TMP/spec/models"
    touch "$TMP/scripts/build.sh" "$TMP/tests/unit/scripts/build.bats"
    touch "$TMP/app/models/user.rb" "$TMP/spec/models/user_spec.rb"

    run lefthook-unit-coverage
    assert_success
}

@test "multiple rules: failure in one rule fails overall" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"

[[rules]]
glob = "*.rb"
dirs = ["app"]
test_dir = "spec"
pattern = "mirror"
strip = "app"
test_suffix = "_spec"
'
    mkdir -p "$TMP/scripts" "$TMP/tests/unit/scripts"
    mkdir -p "$TMP/app/models"
    touch "$TMP/scripts/build.sh" "$TMP/tests/unit/scripts/build.bats"
    touch "$TMP/app/models/user.rb"

    run lefthook-unit-coverage
    assert_failure
    assert_output --partial "app/models/user.rb"
}

@test "files outside configured dirs are ignored" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
'
    mkdir -p "$TMP/scripts" "$TMP/tests/unit/scripts" "$TMP/other"
    touch "$TMP/scripts/build.sh" "$TMP/tests/unit/scripts/build.bats"
    touch "$TMP/other/random.sh"

    run lefthook-unit-coverage
    assert_success
}

@test "test_suffix with _test for minitest" {
    write_config '
[[rules]]
glob = "*.rb"
dirs = ["app"]
test_dir = "test"
pattern = "mirror"
strip = "app"
test_suffix = "_test"
'
    mkdir -p "$TMP/app/controllers" "$TMP/test/controllers"
    touch "$TMP/app/controllers/users_controller.rb"
    touch "$TMP/test/controllers/users_controller_test.rb"

    run lefthook-unit-coverage
    assert_success
}

@test "unknown pattern fails with error" {
    write_config '
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests"
pattern = "unknown"
'
    mkdir -p "$TMP/scripts"
    touch "$TMP/scripts/build.sh"

    run lefthook-unit-coverage
    assert_failure
    assert_output --partial "unknown pattern"
}

@test "no rules in config: passes vacuously" {
    write_config ''

    run lefthook-unit-coverage
    assert_success
}

@test "custom config path via env var" {
    cat > "$TMP/custom.toml" <<'TOML'
[[rules]]
glob = "*.sh"
dirs = ["scripts"]
test_dir = "tests/unit"
pattern = "mirror"
test_ext = "bats"
TOML
    mkdir -p "$TMP/scripts" "$TMP/tests/unit/scripts"
    touch "$TMP/scripts/build.sh" "$TMP/tests/unit/scripts/build.bats"

    LEFTHOOK_UNIT_COVERAGE_CONFIG="custom.toml" \
    run lefthook-unit-coverage
    assert_success
}

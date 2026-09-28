# shellcheck shell=bash
# Lefthook-compatible test coverage check.
# Verifies every implementation file has a corresponding test spec,
# using rules defined in .unit-coverage.toml.
#
# Supports multiple languages/frameworks via [[rules]] entries.
# Each rule maps a glob+dirs combination to a test file pattern.
#
# Usage: lefthook-unit-coverage
# NOTE: sourced by writeShellApplication — no shebang or set needed.

CONFIG="${LEFTHOOK_UNIT_COVERAGE_CONFIG:-.unit-coverage.toml}"
ROOT="${LEFTHOOK_UNIT_COVERAGE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 1

if [ ! -f "$CONFIG" ]; then
  echo "lefthook-unit-coverage: $CONFIG not found" >&2
  echo "  Create a .unit-coverage.toml with [[rules]] entries." >&2
  exit 1
fi

if ! taplo check "$CONFIG" >/dev/null 2>&1; then
  echo "lefthook-unit-coverage: invalid TOML in $CONFIG" >&2
  exit 1
fi

ALLOWLIST_FILE="$(taplo get -f "$CONFIG" -o value 'allowlist' 2>/dev/null || echo ".coverage-allowlist")"

declare -A allow=()
if [ -f "$ALLOWLIST_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '' | '#'*) continue ;;
    esac
    allow["$line"]=1
  done <"$ALLOWLIST_FILE"
fi

total_missing=0
idx=0
rule_count="$(taplo get -f "$CONFIG" -o json rules 2>/dev/null |
  grep -cE '^[[:space:]]*\{' || true)"
rule_count="${rule_count:-0}"
while [ "$idx" -lt "$rule_count" ]; do
  rule_glob="$(taplo get -f "$CONFIG" -o value "rules[$idx].glob" 2>/dev/null || true)"
  rule_test_dir="$(taplo get -f "$CONFIG" -o value "rules[$idx].test_dir" 2>/dev/null || true)"
  if [ -z "$rule_glob" ] || [ -z "$rule_test_dir" ]; then
    echo "lefthook-unit-coverage: rule $idx must define glob, dirs, and test_dir" >&2
    exit 1
  fi
  rule_pattern="$(taplo get -f "$CONFIG" -o value "rules[$idx].pattern" 2>/dev/null || echo "mirror")"
  rule_test_ext="$(taplo get -f "$CONFIG" -o value "rules[$idx].test_ext" 2>/dev/null || echo "")"
  rule_test_suffix="$(taplo get -f "$CONFIG" -o value "rules[$idx].test_suffix" 2>/dev/null || echo "")"
  rule_strip="$(taplo get -f "$CONFIG" -o value "rules[$idx].strip" 2>/dev/null || echo "")"
  rule_normalize="$(taplo get -f "$CONFIG" -o value "rules[$idx].normalize" 2>/dev/null || echo "false")"

  mapfile -t rule_dirs < <(taplo get -f "$CONFIG" -o value "rules[$idx].dirs[*]" 2>/dev/null)
  mapfile -t rule_excludes < <(taplo get -f "$CONFIG" -o value "rules[$idx].exclude[*]" 2>/dev/null)
  if [ "${#rule_dirs[@]}" -eq 0 ] || [ -z "${rule_dirs[0]}" ]; then
    echo "lefthook-unit-coverage: rule $idx must define glob, dirs, and test_dir" >&2
    exit 1
  fi

  ext="${rule_glob#\*.}"

  mapfile -t impls < <(
    if [ -n "${LEFTHOOK_UNIT_COVERAGE_ROOT:-}" ]; then
      find . -type f ! -path './.git/*' | sed 's|^\./||'
    else
      git ls-files
    fi | while IFS= read -r f; do
      case "$f" in
        *."$ext") ;;
        *) continue ;;
      esac
      matched=0
      for d in "${rule_dirs[@]}"; do
        [ -z "$d" ] && continue
        case "$f" in
          "$d"/*)
            matched=1
            break
            ;;
        esac
      done
      [ "$matched" -eq 1 ] || continue
      excluded=0
      for e in "${rule_excludes[@]}"; do
        [ -z "$e" ] && continue
        case "$f" in
          "$e"/*)
            excluded=1
            break
            ;;
        esac
      done
      [ "$excluded" -eq 0 ] && echo "$f"
    done
  )

  missing=()
  for f in "${impls[@]}"; do
    [ -z "$f" ] && continue
    if [ -n "${allow[$f]:-}" ]; then
      continue
    fi

    raw_stem="$(basename "$f")"
    raw_stem="${raw_stem%."$ext"}"
    impl_dir="$(dirname "$f")"

    if [ "$rule_normalize" = "true" ]; then
      norm_stem="${raw_stem//_/-}"
    else
      norm_stem="$raw_stem"
    fi

    rel_path="$impl_dir"
    if [ -n "$rule_strip" ]; then
      case "$impl_dir" in
        "$rule_strip"/*) rel_path="${impl_dir#"$rule_strip"/}" ;;
      esac
    fi

    if [ -n "$rule_test_ext" ]; then
      t_ext="$rule_test_ext"
    else
      t_ext="$ext"
    fi

    case "$rule_pattern" in
      mirror)
        spec="$rule_test_dir/$rel_path/${norm_stem}${rule_test_suffix}.$t_ext"
        ;;
      flat)
        spec="$rule_test_dir/${norm_stem}${rule_test_suffix}.$t_ext"
        ;;
      *)
        echo "lefthook-unit-coverage: unknown pattern '$rule_pattern' in rule $idx" >&2
        exit 1
        ;;
    esac

    if [ ! -f "$spec" ]; then
      alt_spec=""
      if [ "$raw_stem" != "$norm_stem" ]; then
        case "$rule_pattern" in
          mirror) alt_spec="$rule_test_dir/$rel_path/${raw_stem}${rule_test_suffix}.$t_ext" ;;
          flat) alt_spec="$rule_test_dir/${raw_stem}${rule_test_suffix}.$t_ext" ;;
        esac
      fi
      if [ -z "$alt_spec" ] || [ ! -f "$alt_spec" ]; then
        missing+=("$f -> $spec")
      fi
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    {
      echo "lefthook-unit-coverage: rule $idx ($rule_glob): ${#missing[@]} file(s) missing spec:"
      printf '  %s\n' "${missing[@]}"
    } >&2
    total_missing=$((total_missing + ${#missing[@]}))
  fi

  idx=$((idx + 1))
done

if [ "$total_missing" -gt 0 ]; then
  {
    echo
    echo "Fix: add missing test files or allowlist paths in $ALLOWLIST_FILE."
  } >&2
  exit 1
fi
exit 0

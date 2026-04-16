#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_ROOT="$ROOT_DIR/nanga"
STRICT_WARNINGS=0

if [[ "${1:-}" == "--strict" ]]; then
  STRICT_WARNINGS=1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required to run AGENTS status checks."
  exit 2
fi

if [[ ! -d "$SWIFT_ROOT" ]]; then
  echo "error: expected Swift sources under '$SWIFT_ROOT'."
  exit 2
fi

ERROR_COUNT=0
WARNING_COUNT=0

print_section() {
  local level="$1"
  local label="$2"
  local pattern="$3"
  local flags="${4:-}"
  local output=""

  if [[ -n "$flags" ]]; then
    output="$(rg $flags --no-heading --line-number --glob '*.swift' -- "$pattern" "$SWIFT_ROOT" || true)"
  else
    output="$(rg --no-heading --line-number --glob '*.swift' -- "$pattern" "$SWIFT_ROOT" || true)"
  fi

  if [[ -n "$output" ]]; then
    echo
    echo "$level: $label"
    echo "$output"
    if [[ "$level" == "error" ]]; then
      ERROR_COUNT=$((ERROR_COUNT + 1))
    else
      WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
  fi
}

echo "AGENTS status check"
echo "repo: $ROOT_DIR"
echo "swift sources: $SWIFT_ROOT"

# Forbidden per AGENTS.md
print_section "error" "legacy observation type (ObservableObject) is forbidden" "\\bObservableObject\\b"
print_section "error" "legacy @Published is forbidden" "@Published\\b"
print_section "error" "legacy @StateObject is forbidden" "@StateObject\\b"
print_section "error" "legacy @ObservedObject is forbidden" "@ObservedObject\\b"
print_section "error" "legacy @EnvironmentObject is forbidden" "@EnvironmentObject\\b"
print_section "error" "force unwrap appears to be used" "(?<=[[:alnum:]_\\)\\]])!(?=\\s*(?:[\\)\\],\\.:;\\?]|$))" "-P"
print_section "error" "try! is forbidden" "\\btry!\\b"

# Strongly discouraged by AGENTS.md (warn by default, fail in --strict)
print_section "warning" "AnyView detected (avoid unless there is no cleaner type-safe path)" "\\bAnyView\\b"
print_section "warning" "GeometryReader detected (avoid unless layout depends on geometry)" "\\bGeometryReader\\b"
print_section "warning" "onTapGesture detected (prefer semantic controls like Button)" "\\.onTapGesture\\b"
print_section "warning" "String(format:) detected (prefer Swift formatting APIs)" "\\bString\\s*\\(\\s*format:"

echo
echo "summary: errors=$ERROR_COUNT warnings=$WARNING_COUNT"

if (( ERROR_COUNT > 0 )); then
  echo "result: FAIL"
  exit 1
fi

if (( STRICT_WARNINGS == 1 && WARNING_COUNT > 0 )); then
  echo "result: FAIL (--strict treats warnings as errors)"
  exit 1
fi

echo "result: PASS"

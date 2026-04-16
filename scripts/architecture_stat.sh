#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/nanga"

if [[ ! -d "$APP_DIR" ]]; then
  echo "error: expected app sources under '$APP_DIR'."
  exit 2
fi

ERROR_COUNT=0

echo "Architecture status check"
echo "repo: $ROOT_DIR"
echo "app sources: $APP_DIR"

required_dirs=(
  "$APP_DIR/Features/ProjectSelection"
  "$APP_DIR/Features/TaskInput"
  "$APP_DIR/Features/SignalPanel"
  "$APP_DIR/Features/ScopePanel"
  "$APP_DIR/Features/RunLoop"
  "$APP_DIR/Features/IterationHistory"
  "$APP_DIR/Core/Persistence"
  "$APP_DIR/Core/AgentRuntime"
  "$APP_DIR/Core/SignalExtraction"
  "$APP_DIR/Core/ScopeResolution"
  "$APP_DIR/DesignSystem/Components"
  "$APP_DIR/DesignSystem/Styles"
)

for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "error: missing required architecture directory '$dir'."
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done

# Existing root-level files are allowed as a migration baseline.
# New root-level Swift files are blocked and must go under
# Features/, Core/, or DesignSystem/.
legacy_root_allowlist=(
  "AgentRuntime.swift"
  "ContentView.swift"
  "ExecutionPackage.swift"
  "ExecutionPackageBuilder.swift"
  "ExecutionResult.swift"
  "FileDiscoveryService.swift"
  "NangaAppModel.swift"
  "ProjectStore.swift"
  "nangaApp.swift"
)

is_legacy_allowed() {
  local candidate="$1"
  local entry
  for entry in "${legacy_root_allowlist[@]}"; do
    if [[ "$entry" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

while IFS= read -r file_path; do
  file_name="$(basename "$file_path")"
  if ! is_legacy_allowed "$file_name"; then
    echo "error: root-level Swift file '$file_name' violates architecture. Move it under Features/Core/DesignSystem."
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done < <(find "$APP_DIR" -maxdepth 1 -type f -name '*.swift' | sort)

while IFS= read -r file_path; do
  rel="${file_path#"$APP_DIR"/}"
  if [[ "$rel" == */* ]]; then
    top="${rel%%/*}"
    if [[ "$top" != "Features" && "$top" != "Core" && "$top" != "DesignSystem" && "$top" != "Assets.xcassets" ]]; then
      echo "error: '$rel' is outside allowed architecture roots (Features/Core/DesignSystem)."
      ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
  fi
done < <(find "$APP_DIR" -type f -name '*.swift' | sort)

if (( ERROR_COUNT > 0 )); then
  echo "summary: errors=$ERROR_COUNT"
  echo "result: FAIL"
  exit 1
fi

echo "summary: errors=0"
echo "result: PASS"

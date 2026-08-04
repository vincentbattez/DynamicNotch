#!/usr/bin/env bash
# Verification gate for sandcastle agents: build the CLI, then run the unit suite.
#
# Runs from the repo root (or a git worktree of it). `-derivedDataPath build` is
# relative on purpose: each worktree gets its own DerivedData, so concurrent
# runs can't corrupt each other.
set -euo pipefail

PROJECT="DynamicNotch.xcodeproj"
SIGNING=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="")

# Environmental failures, listed in scripts/lib/skipped-tests.txt (shared with
# the `test:unit` mise task). See docs/agents/domain.md.
skip_args=()
while IFS= read -r test || [ -n "$test" ]; do
  case "$test" in ''|'#'*) continue ;; esac
  skip_args+=("-skip-testing:$test")
done < "$(dirname "$0")/lib/skipped-tests.txt"

xcodebuild build \
  -project "$PROJECT" -scheme DynamicNotchCLI -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build \
  "${SIGNING[@]}"

# UI tests drive the real screen and the inbox tests race each other, so the
# gate is unit-only and serial.
xcodebuild test \
  -project "$PROJECT" -scheme DynamicNotch \
  -destination 'platform=macOS' -derivedDataPath build \
  -parallel-testing-enabled NO \
  -only-testing:DynamicNotchTests \
  "${skip_args[@]}" \
  "${SIGNING[@]}"

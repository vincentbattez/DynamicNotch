#!/usr/bin/env bash
# Verification gate for sandcastle agents: build the CLI, then run the unit suite.
#
# Runs from the repo root (or a git worktree of it). `-derivedDataPath build` is
# relative on purpose: each worktree gets its own DerivedData, so concurrent
# runs can't corrupt each other.
set -euo pipefail

PROJECT="DynamicNotch.xcodeproj"
SIGNING=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="")

# Environmental failures: these assert against this machine's real display /
# notch geometry, not against any code. See docs/agents/domain.md.
SKIP=(
  DynamicNotchTests/NotchTransitionMetricsTests/testHorizontalCompensationOffsetIsConstantRegardlessOfNotchWidth
  DynamicNotchTests/NotchTransitionMetricsTests/testHorizontalCompensationOffsetMatchesExpandedReferenceWidth
  DynamicNotchTests/NotchViewModelIntegrationTests/testDismissSwipeCompressesCollapsedNotchAlongWidth
  DynamicNotchTests/NotchViewModelIntegrationTests/testPresentedNotchSizeStagesHeightDuringClosingTransition
  DynamicNotchTests/NotchViewModelIntegrationTests/testUpdateDimensionsUsesSelectedDisplayMetrics
  DynamicNotchTests/NotchViewModelIntegrationTests/testUpdateDimensionsUsesSpecificDisplayMetrics
)
skip_args=()
for test in "${SKIP[@]}"; do skip_args+=("-skip-testing:$test"); done

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

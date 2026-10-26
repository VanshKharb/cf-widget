#!/bin/bash
# Compiles and runs the core verification harness.
# Requires only the Swift toolchain from Command Line Tools — no Xcode needed.
set -euo pipefail

cd "$(dirname "$0")/.."

# Deliberately an explicit file list: the SwiftUI files in Shared/ (RankStyle,
# HeatmapGridView, ...) cannot be compiled by a plain swiftc invocation, and the
# harness only covers the Foundation-only core.
FILES=(
  Shared/CodeforcesModels.swift
  Shared/CodeforcesAPI.swift
  Shared/Formatting.swift
  Shared/Heatmap.swift
  Shared/StatsSnapshot.swift
  Shared/StatsSnapshot+Sample.swift
  Shared/SnapshotLoader.swift
  Shared/SharedStore.swift
  Tools/verify.swift
)

BIN="$(mktemp -d)/verify"
swiftc -parse-as-library -O -o "$BIN" "${FILES[@]}"
"$BIN"

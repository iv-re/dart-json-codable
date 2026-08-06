#!/usr/bin/env bash
set -e

# Change directory to package root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

echo "Running AOT benchmarks via benchmark_harness:bench..."
dart run benchmark_harness:bench --flavor aot --target benchmark/main.dart

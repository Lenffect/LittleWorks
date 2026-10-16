#!/bin/sh
# Runs the tests. Needs Xcode (the old Command Line Tools workaround broke with Xcode 27).
cd "$(dirname "$0")"
swift test "$@"

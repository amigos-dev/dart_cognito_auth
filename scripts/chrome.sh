#!/bin/bash

#set -x
set -e

# Environment variable CHROME_EXECUTABLE may be pointed at this script to wrap the
# real chrome browser and allow the environment to override flutter's attempt to
# set --user-data-dir to a temporary directory. This enables debugging of web targets that
# maintain persistent data between runs.

# Set UNWRAPPED_CHROME_EXECUTABLE to the real chrome executable. If unset, the result of
# "$(command -v chrome)" is used--if desired you can put a "chrome" script in your path.

# Set FLUTTER_CHROME_USER_DATA_DIR to the directory that will contain persistent browser data
# for use by chrome whenever this script detects that chrome is being launched by flutter.
# This script will have no effect when launched by other than flutter, or if this environment
# variable is not set.
# WARNING: There is a bug in chrome/chromium where it claims it cannot read/write the user data
# directory if any part of the path has a directory name that starts with '.'. Do not
# set FLUTTER_CHROME_USER_DATA_DIR 


beginsWith() { case "$2" in "$1"*) true;; *) false;; esac; }

# NOTE: Flutter launches chrome with:
#   "$CHROME_EXECUTABLE" \
#      --user-data-dir=/tmp/flutter_tools.IEITVI/flutter_tools_chrome_device.<random-string> \
#      --remote-debugging-port=41293 \
#      --disable-background-timer-throttling \
#      --disable-extensions \
#      --disable-popup-blocking \
#      --bwsi \
#      --no-first-run \
#      --no-default-browser-check \
#      --disable-default-apps \
#      --disable-translate \
#      http://localhost:<web-port>

if [ -z "$UNWRAPPED_CHROME_EXECUTABLE" ]; then
  UNWRAPPED_CHROME_EXECUTABLE="$(command -v chrome)"
fi

if [ -n "$FLUTTER_CHROME_USER_DATA_DIR" ]; then
  mkdir -p -m 700 "$FLUTTER_CHROME_USER_DATA_DIR"
  FLUTTER_CHROME_USER_DATA_DIR="$(cd "$FLUTTER_CHROME_USER_DATA_DIR" >/dev/null; pwd -P)"
fi

if [ -n "$LOG_CHROME_LAUNCHES" ]; then
  cmdname="$(printf '%q' "$0")"
  if [[ $# -eq 0 ]]; then
    cmdargs=''
  else
    cmdargs="$(printf ' %q' "$@")"
  fi
  #echo "chrome wrapper launched with [$cmdname$cmdargs]" >&2
  mkdir -p -m 700 "$HOME/.private"
  echo "chrome wrapper launched with [$cmdname$cmdargs]" >> "$HOME/.private/chrome-launch.log"
fi

newArgs=()

for arg in "$@"; do
  newArg="$arg"
  if [ -n "$FLUTTER_CHROME_USER_DATA_DIR" ]; then
    if beginsWith "--user-data-dir=/tmp/flutter_tools" "$newArg"; then
      newArg="--user-data-dir=$FLUTTER_CHROME_USER_DATA_DIR"
    fi
  fi
  newArgs+=("$newArg")
done

if [ -n "$LOG_CHROME_LAUNCHES" ]; then
  cmdname="$(printf '%q' "$UNWRAPPED_CHROME_EXECUTABLE")"
  if [[ $# -eq 0 ]]; then
    cmdargs=''
  else
    cmdargs="$(printf ' %q' "${newArgs[@]}")"
  fi
  #echo "actual chrome launched with [$cmdname$cmdargs]" >&2
  echo "actual chrome launched with [$cmdname$cmdargs]" >> "$HOME/.private/chrome-launch.log"
fi

export CHROME_EXECUTABLE="$UNWRAPPED_CHROME_EXECUTABLE"
unset UNWRAPPED_CHROME_EXECUTABLE
unset FLUTTER_CHROME_USER_DATA_DIR
"$CHROME_EXECUTABLE" "${newArgs[@]}" || exit $?

#!/usr/bin/env bash
# bootstrap.sh -- set up the Python virtual environment for mu2edaq-controlroom
# and install/update its dependencies.
#
# Usage: ./bootstrap.sh [--dev]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HERE/venv"
DEV=0

for arg in "$@"; do
    case "$arg" in
        --dev) DEV=1 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    echo "error: python3 not found. Install Python 3.9+ first." >&2
    exit 1
fi

PYVER=$("$PYTHON" -c 'import sys; print("%d.%d" % sys.version_info[:2])')
"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' || {
    echo "error: Python >= 3.9 required, found $PYVER" >&2; exit 1;
}
echo "Using Python $PYVER at $(command -v "$PYTHON")"

if [ ! -d "$VENV" ]; then
    echo "Creating virtual environment in $VENV"
    "$PYTHON" -m venv "$VENV"
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install --upgrade pip >/dev/null

echo "Installing dependencies from requirements.txt"
pip install -r "$HERE/requirements.txt"

if [ "$DEV" = 1 ]; then
    echo "Installing dev tools (pytest)"
    pip install pytest
fi

echo ""
echo "Bootstrap complete. Activate with:  source venv/bin/activate"
echo "Run the DAQ env tools with:         python3 daq_env_tools.py"

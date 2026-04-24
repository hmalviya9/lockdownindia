#!/usr/bin/env bash
# Optional local HTTP server for the dashboard.
# The dashboard works fine via file:// (it uses script-tag loading), but if you'd prefer
# a real http://localhost URL (cleaner share URL, fewer browser caching quirks), run this.
#
# Usage:
#   ./scripts/serve.sh           # serves on http://localhost:8080
#   PORT=9000 ./scripts/serve.sh # custom port

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8080}"

cd "$ROOT"
echo "Serving $ROOT at http://localhost:$PORT"
echo "Open: http://localhost:$PORT/dashboard.html"
echo "Press Ctrl+C to stop."

# Ruby is bundled with macOS — use it as a tiny static server
exec ruby -run -e httpd . -p "$PORT" --bind-address 127.0.0.1

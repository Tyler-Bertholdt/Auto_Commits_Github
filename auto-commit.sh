#!/bin/bash

WATCH_DIR="$1"
BRANCH="main"
FLAG_FILE="/tmp/auto_commit_flag"
STOP_FILE="/tmp/auto_commit_stop"

if [[ -z "$WATCH_DIR" ]]; then
    echo "❌ Usage: $0 <path-to-watch>"
    exit 1
fi

WATCH_DIR="$(realpath "$WATCH_DIR")"
cd "$WATCH_DIR" || exit 1

cleanup() {
    rm -f "$FLAG_FILE" "$STOP_FILE"
}
trap cleanup EXIT

# 🔹 KEY LISTENER: runs in main shell (foreground) so it can read input
keypress_listener() {
    while true; do
        read -rsn1 key < /dev/tty
        case "$key" in
            y)
                echo "🟢 y pressed: commit requested"
                touch "$FLAG_FILE"
                ;;
            q)
                echo "🔴 q pressed: exiting script"
                touch "$STOP_FILE"
                break
                ;;
        esac
    done
}

# 🔹 FILE WATCHER: runs in background
file_watcher() {
    while true; do
        [[ -f "$STOP_FILE" ]] && break

        # Wait for any file change in directory
        inotifywait -qq -r -e modify "$WATCH_DIR"
        
        # Wait up to 300s or until y/q pressed
        for i in {1..3000}; do
            [[ -f "$STOP_FILE" ]] && break
            if [[ -f "$FLAG_FILE" ]]; then
                echo "📦 Committing changes..."
                git add .
                git commit -m "Auto commit"
                git push origin "$BRANCH"
                rm -f "$FLAG_FILE"
                break
            fi
            sleep 0.1
        done
    done
}

echo "Your branches in '$(basename "$WATCH_DIR")':"
git branch
echo
echo "ℹ️  No branch specified. Using current branch: '$BRANCH'"
echo "⌨️  Press 'y' anytime to commit & push, 'q' to quit."

file_watcher &   # background file watcher
keypress_listener  # blocking in main shell

#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-watch>"
    exit 1
fi

DOTFILES_PATH="$(realpath "$1")"

cd "$DOTFILES_PATH" || { echo "❌ Failed to cd into $DOTFILES_PATH"; exit 1; }

check_and_commit_and_push() {
    if [[ -n $(git status --porcelain) ]]; then
        echo "🔍 Changed files:"
        git status -s
        git add -A
        git commit -m "Auto commit at $(date '+%Y-%m-%d %H:%M:%S')"
        
        git pull --rebase origin testing
        git push origin testing

        notify-send "✅ Git Auto Commit" "Committed and pushed to testing"
        git status
    else
        notify-send "ℹ️ Git Auto Commit" "No changes to commit"
    fi
}

while true; do
    inotifywait -qr -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"
    while true; do
        if inotifywait -qr -t 300 -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"; then
            continue
        else
            break
        fi
    done
    cd "$DOTFILES_PATH"
    check_and_commit_and_push
done

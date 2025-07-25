#!/bin/bash


if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-watch>"
    exit 1
fi

# Expand relative path to absolute path
DOTFILES_PATH="$(realpath "$1")"

# Check if path exists
cd "$DOTFILES_PATH" || { echo "❌ Failed to cd into $DOTFILES_PATH"; exit 1; }

check_and_commit() {
    if [[ -n $(git status --porcelain) ]]; then
git add -A
        git commit -m "Auto commit at $(date '+%Y-%m-%d %H:%M:%S')"
        notify-send "✅ Git Auto Commit" "Changes committed"
    else
        notify-send "ℹ️ Git Auto Commit" "No changes to commit"
    fi
}

while true; do
    inotifywait -qr -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"
    while true; do
        if inotifywait -qr -t 30 -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"; then
            continue  
        else
            break 
        fi
    done
    check_and_commit
    git push origin testing
    git status
done

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

    FLAG_FILE="/tmp/git_autocommit_triggered"
    EXIT_FILE="/tmp/git_autocommit_exit"

    rm -f "$FLAG_FILE" "$EXIT_FILE"

    (
        while true; do
            IFS= read -rsn1 key < /dev/tty
            case "${key,,}" in
                y) touch "$FLAG_FILE"; break ;;
                q) touch "$EXIT_FILE"; break ;;
                *) continue ;;
            esac
        done
    ) &

    for _ in {1..300}; do
        if [[ -f "$FLAG_FILE" || -f "$EXIT_FILE" ]]; then
            break
        fi
        if inotifywait -q -t 1 -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"; then
            continue
        fi
    done

    if [[ -f "$EXIT_FILE" ]]; then
        echo "[FORCE EXIT] Exiting Git Auto Commit script"
        rm -f "$EXIT_FILE" "$FLAG_FILE"
        exit 0
    fi

    if [[ -f "$FLAG_FILE" ]]; then
        echo "🟢 Detected 'y' press — committing immediately..."
        rm -f "$FLAG_FILE"
        check_and_commit_and_push
    else
        echo -n "[Git Auto Commit] Press 'y' to commit & push, or 'q' to quit: "
        while true; do
            IFS= read -rsn1 key < /dev/tty
            echo
            case "${key,,}" in
                y) check_and_commit_and_push; break ;;
                q) echo "[FORCE EXIT] Exiting Git Auto Commit script"; exit 0 ;;
                *) echo "❌ Cancelled"; break ;;
            esac
        done
    fi
done

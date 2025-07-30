#!/bin/bash

if [ -z "$1" ]; then
    echo -e "Usage: $0 <path-to-watch> <branch-to-push>\n"
    echo "❌ No path provided"
    exit 1
fi

if [ -d "$1/.git" ]; then
    echo "Your branches in '$1':"
    git -C "$1" branch --format=" - %(refname:short)" | sed 's/^\*/👉/'
    echo
elif [ ! -d "$1" ]; then
    echo "❌ '$1' is not a valid directory"
    exit 1
else
    echo "❌ '$1' is not a valid Git repository"
    exit 1
fi

DOTFILES_PATH="$(realpath "$1")"
BRANCH="${2:-$(git -C "$DOTFILES_PATH" rev-parse --abbrev-ref HEAD)}"
echo "ℹ️  Using branch: '$BRANCH'"
cd "$DOTFILES_PATH" || exit 1

# temp files
FLAG_FILE="/tmp/git_autocommit_triggered"
EXIT_FILE="/tmp/git_autocommit_exit"
rm -f "$FLAG_FILE" "$EXIT_FILE"

# keypress listener in background
(
    while true; do
        IFS= read -rsn1 key
        case "${key,,}" in
            y) touch "$FLAG_FILE" ;;
            q) touch "$EXIT_FILE" ;;
        esac
    done
) </dev/tty &

echo "⌨️  Press 'y' anytime to commit & push, 'q' to quit."

check_and_commit_and_push() {
    if [[ -n $(git status --porcelain) ]]; then
        echo "🔍 Changed files:"
        git status -s
        git add -A
        git commit -m "Auto commit at $(date '+%Y-%m-%d %H:%M:%S')"
        git pull --rebase origin "$BRANCH"
        git push origin "$BRANCH"
        notify-send "✅ Git Auto Commit" "Committed and pushed to '$BRANCH'"
    else
        notify-send "ℹ️ Git Auto Commit" "No changes to commit"
    fi
}

while true; do
    inotifywait -qr -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"

    for _ in {1..300}; do
        if [[ -f "$EXIT_FILE" ]]; then
            echo "[FORCE EXIT] Exiting Git Auto Commit script"
            rm -f "$EXIT_FILE" "$FLAG_FILE"
            exit 0
        elif [[ -f "$FLAG_FILE" ]]; then
            echo "🟢 'y' pressed — committing now..."
            rm -f "$FLAG_FILE"
            check_and_commit_and_push
            break
        fi
        sleep 1
    done
done

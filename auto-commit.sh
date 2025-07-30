#!/bin/bash

if [ -z "$1" ]; then
    echo -e "Usage: $0 <path-to-watch> <branch-to-push>\n"
    echo "❌ No path provided"
    exit 1
fi

DOTFILES_PATH="$(realpath "$1")"
DUMMY_FILE="$DOTFILES_PATH/.auto_commit_72837179281"

if [ ! -d "$DOTFILES_PATH/.git" ]; then
    echo "❌ '$DOTFILES_PATH' is not a valid Git repository"
    exit 1
fi

if [ -z "$2" ]; then
    BRANCH=$(git -C "$DOTFILES_PATH" rev-parse --abbrev-ref HEAD)
    echo "ℹ️  No branch specified. Using current branch: '$BRANCH'"
else
    BRANCH="$2"
fi

cd "$DOTFILES_PATH" || exit 1

# Create dummy file if not exists
touch "$DUMMY_FILE"

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
    touch "$DUMMY_FILE"
}

while true; do
    # Wait for any real file change (excluding .git) or dummy file touch
    inotifywait -qr -e modify,create,delete --exclude '\.git/' "$DOTFILES_PATH"

    echo -n "[Git Auto Commit] Press 'y' to commit & push, or 'q' to quit: "
    while true; do
        IFS= read -rsn1 key
        echo
        case "${key,,}" in
            y)
                echo "🟢 Committing..."
                check_and_commit_and_push
                break
                ;;
            q)
                echo "👋 Quitting Git Auto Commit script"
                rm -f "$DUMMY_FILE"
                exit 0
                ;;
            *)
                echo "❌ Cancelled"
                break
                ;;
        esac
    done
done

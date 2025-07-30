#!/bin/bash

if [ -z "$1" ]; then
    echo -e "Usage: $0 <path-to-watch> <branch-to-push>\n"
    echo "❌ No path provided"
    exit 1
fi

# If path is valid, show available branches
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
DUMMY_FILE="$DOTFILES_PATH/.auto_commit_dummy_$(uuidgen | cut -d- -f1)"

if [ -z "$2" ]; then
    BRANCH=$(git -C "$DOTFILES_PATH" rev-parse --abbrev-ref HEAD)
    echo "ℹ️  No branch specified. Using current branch: '$BRANCH'"
else
    BRANCH="$2"
fi

cd "$DOTFILES_PATH" || { echo "❌ Failed to cd into $DOTFILES_PATH"; exit 1; }

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
        git status
    else
        notify-send "ℹ️ Git Auto Commit" "No changes to commit"
    fi

    # Trigger file system change, but not Git change
    echo "# $(date)" >> "$DUMMY_FILE"
    sleep 0.2
    git checkout -- "$DUMMY_FILE" 2>/dev/null || true
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
        rm -f "$DUMMY_FILE"
        exit 0
    fi

    if [[ -f "$FLAG_FILE" ]]; then
        echo "🟢 Detected 'y' press — committing immediately..."
        rm -f "$FLAG_FILE"
        check_and_commit_and_push
    else
        echo -n "[Git Auto Commit] Press 'y' to commit & push, or 'q' to quit: "
        touch "$DUMMY_FILE"
        while true; do
            IFS= read -rsn1 key < /dev/tty
            echo
            case "${key,,}" in
                y)
                    check_and_commit_and_push
                    break
                    ;;
                q)
                    echo "[FORCE EXIT] Exiting Git Auto Commit script"
                    rm -f "$DUMMY_FILE"
                    exit 0
                    ;;
                *)
                    echo "❌ Cancelled"
                    break
                    ;;
            esac
        done
    fi
done

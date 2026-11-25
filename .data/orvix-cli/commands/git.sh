# orvix git - Passthrough to git in the dotfiles repo

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: orvix git <args...>"
    echo ""
    echo "Run git commands scoped to the dotfiles repository."
    echo ""
    echo "Examples:"
    echo "  orvix git status"
    echo "  orvix git log --oneline -5"
    echo "  orvix git diff"
    return 0
fi

git -C "$DOTS_DIR" "$@"

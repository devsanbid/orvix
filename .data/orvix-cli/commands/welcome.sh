# orvix welcome - Open the welcome screen

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: orvix welcome"
    echo ""
    echo "Open the welcome screen: the first choices and the main shortcuts."
    echo "It opens by itself on the first login after the install; Settings ›"
    echo "About opens it too."
    return 0
fi

if ! qs ipc call welcome open 2>/dev/null; then
    echo "orvix welcome: Quickshell isn't running (start it with: orvix reload)"
    return 1
fi

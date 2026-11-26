# orvix doctor - Check that the desktop has everything it needs

local subcmd="${1:-status}"

source "$DOTS_DIR/.data/orvix-cli/lib/doctor.sh"

# Colour, only on a terminal
_doctor_color() {
    if [[ -t 1 ]]; then
        printf '\033[%sm' "$1"
    fi
}
_doctor_off() {
    if [[ -t 1 ]]; then
        printf '\033[0m'
    fi
}

# Count the levels of the checks run, into DOCTOR_OK/WARN/FAIL
_doctor_count() {
    DOCTOR_OK=0 DOCTOR_WARN=0 DOCTOR_FAIL=0
    local level
    while IFS=$'\t' read -r level _; do
        case "$level" in
        ok) ((DOCTOR_OK++)) ;;
        warn) ((DOCTOR_WARN++)) ;;
        fail) ((DOCTOR_FAIL++)) ;;
        esac
    done < <(orvix_doctor_checks)
}

case "$subcmd" in
    -h|--help)
        echo "Usage: orvix doctor [status|--json|--quiet]"
        echo ""
        echo "Checks that the desktop has what it needs: Hyprland and its config,"
        echo "Quickshell, the wallpaper daemon and polkit agent, the clipboard, the"
        echo "theme files and matugen, your default apps, the tools behind the"
        echo "shortcuts (screenshots, OCR, media keys), the update source and, when"
        echo "it's installed, Omarchy. Nothing is changed and nothing is installed:"
        echo "each problem comes with the command that fixes it."
        echo ""
        echo "The same checks are in Settings › System › Health."
        echo ""
        echo "Subcommands:"
        echo "  status    One line per check, problems first (default)"
        echo "  --json    The checks as JSON, for scripts"
        echo "  --quiet   Only the failures, with the command that fixes each;"
        echo "            nothing when they all pass"
        echo ""
        echo "Exit status: 0 everything is fine or only warnings, 1 with a"
        echo "failure, 2 with a usage error."
        ;;
    --json)
        if ! command -v jq &>/dev/null; then
            echo "orvix doctor: jq is required for --json" >&2
            return 2
        fi
        orvix_doctor_checks | jq -R -s '
            split("\n") | map(select(length > 0) | split("\t")) |
            map({ level: .[0], id: .[1], what: .[2], state: .[3], fix: .[4] }) |
            { checks: ., ok: (map(select(.level == "ok")) | length),
              warn: (map(select(.level == "warn")) | length),
              fail: (map(select(.level == "fail")) | length) }'
        _doctor_count
        ((DOCTOR_FAIL == 0)) || return 1
        ;;
    status | --quiet)
        local quiet=0
        [[ "$subcmd" == "--quiet" ]] && quiet=1
        local level id what state fix label
        _doctor_count
        if ((quiet == 0)); then
            echo "orvix doctor"
            echo ""
        fi
        # Problems first: warnings and failures, then what works
        local pass
        for pass in problem good; do
            while IFS=$'\t' read -r level id what state fix; do
                if [[ "$pass" == "good" && "$level" != "ok" ]]; then
                    continue
                fi
                if [[ "$pass" == "problem" && "$level" == "ok" ]]; then
                    continue
                fi
                case "$level" in
                ok) label="ok  " ;;
                warn) label="warn" ;;
                fail) label="FAIL" ;;
                esac
                if ((quiet)); then
                    # Only what needs a hand: failures, with the command that fixes them
                    [[ "$level" == "fail" ]] || continue
                    printf '%s\t%s: %s (fix: %s)\n' "$label" "$what" "$state" "$fix"
                    continue
                fi
                case "$level" in
                ok) _doctor_color "0;32" ;;
                warn) _doctor_color "1;33" ;;
                fail) _doctor_color "0;31" ;;
                esac
                printf '  %s  ' "$label"
                _doctor_off
                printf '%-20s %s\n' "$what" "$state"
                if [[ -n "$fix" && "$level" != "ok" ]]; then
                    printf '        %s\n' "$fix"
                fi
            done < <(orvix_doctor_checks)
        done
        if ((quiet == 0)); then
            echo ""
            printf '%d ok, %d warning(s), %d failure(s)\n' "$DOCTOR_OK" "$DOCTOR_WARN" "$DOCTOR_FAIL"
        fi
        ((DOCTOR_FAIL == 0)) || return 1
        ;;
    *)
        echo "orvix doctor: unknown option '$subcmd' (orvix doctor --help lists them)" >&2
        return 2
        ;;
esac

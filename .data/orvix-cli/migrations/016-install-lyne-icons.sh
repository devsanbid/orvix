# 016-install-orvix-icons.sh - Install the orvix logo as a system icon
#
# `orvix update` notifications use the "orvix" icon. From now on every
# update refreshes it; this covers the first one.

echo "   Installing the orvix icon..."
source "$DOTS_DIR/.data/orvix-cli/lib/install-icons.sh"

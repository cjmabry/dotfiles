#!/usr/bin/env bash
set -e

DOTFILES_DIR="$HOME/.dotfiles"
OUTPUT_FILE="$DOTFILES_DIR/flatpak.txt"

TMP_FILE=$(mktemp)

# ----------------------------
# List all installed Flatpak apps
# ----------------------------
echo "Listing installed Flatpak apps..."
flatpak list --app --columns=application > "$TMP_FILE"

echo
echo "All installed Flatpak apps:"
cat "$TMP_FILE"
echo

# ----------------------------
# Let user edit the list
# ----------------------------
echo "You can now remove apps you don't want to include."
echo "The list will be saved to $OUTPUT_FILE"
echo "Leave the file unchanged to include all."

# Open the file in the user's default editor, or fallback to nano
${EDITOR:-nano} "$TMP_FILE"

# ----------------------------
# Save final list
# ----------------------------
cp "$TMP_FILE" "$OUTPUT_FILE"
rm "$TMP_FILE"

echo "Flatpak list saved to $OUTPUT_FILE"

#!/bin/bash

# Script to uninstall EisenVault context menu

echo "Uninstalling EisenVault context menu..."

# Remove the Automator workflow
AUTOMATOR_APP="$HOME/Library/Services/Upload to EisenVault.workflow"

if [ -d "$AUTOMATOR_APP" ]; then
    rm -rf "$AUTOMATOR_APP"
    echo "Context menu removed successfully!"
else
    echo "Context menu not found. It may have already been removed."
fi

echo "You may need to restart Finder for the changes to take effect."
echo "To restart Finder, run: killall Finder"

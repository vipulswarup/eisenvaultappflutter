#!/bin/bash

# Simple context menu installation using a basic shell script approach

echo "Installing simple EisenVault context menu..."

# Create the service directory
SERVICE_DIR="$HOME/Library/Services"
mkdir -p "$SERVICE_DIR"

# Create a simple shell script
SCRIPT_PATH="$SERVICE_DIR/eisenvault_upload.sh"
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

# Get the file paths from arguments
for file in "$@"; do
    # Convert file:// URLs to regular paths
    file_path=$(echo "$file" | sed 's|file://||' | sed 's|%20| |g')
    
    # Launch EisenVault with the file
    open -a "EisenVault Desktop" --args "eisenvault://upload?files=$file_path"
done
EOF

chmod +x "$SCRIPT_PATH"

# Create a simple Automator workflow using the command line
WORKFLOW_PATH="$SERVICE_DIR/Upload to EisenVault.workflow"

# Use Automator command line to create a simple workflow
cat > "/tmp/create_workflow.applescript" << 'EOF'
tell application "Automator"
    set newWorkflow to make new workflow
    set name of newWorkflow to "Upload to EisenVault"
    set workflow type of newWorkflow to service workflow
    
    -- Add a "Run Shell Script" action
    set shellAction to make new action with properties {name:"Run Shell Script"}
    add shellAction to newWorkflow
    
    -- Set the shell script content
    set shell script of shellAction to "for file in \"$@\"; do
    file_path=$(echo \"$file\" | sed 's|file://||' | sed 's|%20| |g')
    open -a \"EisenVault Desktop\" --args \"eisenvault://upload?files=$file_path\"
done"
    
    -- Save the workflow
    save newWorkflow in (path to services folder as string) & "Upload to EisenVault.workflow"
    close newWorkflow
end tell
EOF

# Run the AppleScript to create the workflow
osascript "/tmp/create_workflow.applescript"

# Clean up
rm -f "/tmp/create_workflow.applescript"

echo "Context menu installed successfully!"
echo "You may need to restart Finder for the changes to take effect."
echo "To restart Finder, run: killall Finder"
echo ""
echo "To uninstall, run: rm -rf '$WORKFLOW_PATH'"

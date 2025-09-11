#!/bin/bash

# Simple script to install context menu for EisenVault using Automator

echo "Installing EisenVault context menu..."

# Create the service directory
SERVICE_DIR="$HOME/Library/Services"
mkdir -p "$SERVICE_DIR"

# Create a simple shell script that will be called by the service
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

# Create the Automator workflow
WORKFLOW_PATH="$SERVICE_DIR/Upload to EisenVault.workflow"
mkdir -p "$WORKFLOW_PATH/Contents"

# Create Info.plist
cat > "$WORKFLOW_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Automator Application</string>
    <key>CFBundleIdentifier</key>
    <string>com.eisenvault.upload-service</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Upload to EisenVault</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Upload to EisenVault</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSRequiredContext</key>
            <dict>
                <key>NSApplicationIdentifier</key>
                <string>com.apple.finder</string>
            </dict>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.item</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create the workflow document
cat > "$WORKFLOW_PATH/Contents/document.wflow" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>422</string>
    <key>AMApplicationName</key>
    <string>Automator</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentSavePath</key>
    <string></string>
    <key>AMDocumentSavePathWasTildeExpanded</key>
    <false/>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>AMSystemBuild</key>
    <string>22F82</string>
    <key>AMSystemVersion</key>
    <string>13.0</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <true/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <dict/>
                    <key>CheckedForUserDefaultShell</key>
                    <dict/>
                    <key>inputMethod</key>
                    <dict/>
                    <key>shell</key>
                    <dict/>
                    <key>source</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>for file in "$@"; do
    # Convert file:// URLs to regular paths
    file_path=$(echo "$file" | sed 's|file://||' | sed 's|%20| |g')
    
    # Launch EisenVault with the file
    open -a "EisenVault Desktop" --args "eisenvault://upload?files=$file_path"
done</string>
                    <key>CheckedForUserDefaultShell</key>
                    <string>1</string>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>7B8B2B8B-8B8B-8B8B-8B8B-8B8B8B8B8B8B</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                    <string>Command</string>
                    <string>Run</string>
                    <string>Unix</string>
                </array>
                <key>OutputUUID</key>
                <string>7B8B2B8B-8B8B-8B8B-8B8B-8B8B8B8B8B8C</string>
                <key>UUID</key>
                <string>7B8B2B8B-8B8B-8B8B-8B8B-8B8B8B8B8B8B</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict>
                    <key>0</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>COMMAND_STRING</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>0</string>
                    </dict>
                    <key>1</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>CheckedForUserDefaultShell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>1</string>
                    </dict>
                    <key>2</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>inputMethod</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>2</string>
                    </dict>
                    <key>3</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>shell</key>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>3</string>
                    </dict>
                    <key>4</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>source</key>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>4</string>
                    </dict>
                </dict>
                <key>isViewVisible</key>
                <integer>0</integer>
                <key>location</key>
                <string>444.000000:318.000000</string>
                <key>nibPath</key>
                <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
            </dict>
            <key>isViewVisible</key>
            <integer>0</integer>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowType</key>
    <string>Service</string>
</dict>
</plist>
EOF

echo "Context menu installed successfully!"
echo "You may need to restart Finder for the changes to take effect."
echo "To restart Finder, run: killall Finder"
echo ""
echo "To uninstall, run: rm -rf '$WORKFLOW_PATH'"

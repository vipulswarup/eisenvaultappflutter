#!/bin/bash

# Test script for context menu functionality
# This simulates what would happen when files are selected via context menu

echo "Testing EisenVault context menu functionality..."

# Get the current directory
CURRENT_DIR=$(pwd)

# Create a test file
TEST_FILE="$CURRENT_DIR/test_file.txt"
echo "This is a test file for EisenVault context menu" > "$TEST_FILE"

echo "Created test file: $TEST_FILE"

# Launch EisenVault with the test file
echo "Launching EisenVault with test file..."
open -a "EisenVault Desktop" --args "eisenvault://upload?files=$TEST_FILE"

echo "Test completed. Check if EisenVault opened with the upload screen."
echo "Test file location: $TEST_FILE"
echo "You can delete the test file with: rm '$TEST_FILE'"

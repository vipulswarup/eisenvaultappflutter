#!/bin/bash

# Check if folder is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Navigate to the specified directory
cd "$1" || { echo "Invalid directory: $1"; exit 1; }

# Find all files, remove './' from paths, and prepend '@'
find . -type f | sed 's|^\./|@|' > paths.txt

echo "File list saved to paths.txt"


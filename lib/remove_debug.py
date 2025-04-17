import os
import re

def remove_debug_statements(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # Regex to match EVLogger.debug statements, including multi-line
    pattern = re.compile(r'EVLogger\.debug\([^;]*?\);', re.DOTALL)
    new_content = re.sub(pattern, '', content)

    with open(file_path, 'w') as file:
        file.write(new_content)

def process_directory(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                remove_debug_statements(file_path)

if __name__ == '__main__':
    process_directory('.')
# This script removes all EVLogger.debug statements from Dart files in the current directory and its subdirectories.
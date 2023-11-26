#!/usr/bin/env bash

# Get the root directory of the Git repository
git_repo_root=$(git rev-parse --show-toplevel)

# Get the list of modified files in the repository with full paths
modified_files=$(git status --porcelain | awk -v root="$git_repo_root" '{print root "/" $2}')

# Add instructions to the list of modified files
instructions="
=== stash slected files ===
Please select one or more files from the list below.
You can type to filter the list and press Enter to confirm your selection.
Use TAB to select multiple files.
====================
"
file_list=$(echo -e "$instructions\n$modified_files")

# Reverse the order of files and instructions using `tac`
reversed_file_list=$(echo "$file_list" | tac)

# Use fzf to select multiple files
selected_files=$(echo "$reversed_file_list" | fzf --multi)

# Check if any files were selected
if [ -z "$selected_files" ]; then
    echo "No files selected. Exiting."
    exit 1
fi

# Store the selected files in an array
IFS=$'\n' read -rd '' -a files_array <<<"$selected_files"

# Filter out the instructions from the array
filtered_files_array=()
for file in "${files_array[@]}"; do
    if [[ $file != *"==="* ]]; then
        filtered_files_array+=("$file")
    fi
done

# Prompt for a stash message
echo "Enter a stash message:"
read stash_message

# Stash the selected files
git stash push -u -m "$stash_message" -- "${filtered_files_array[@]}"

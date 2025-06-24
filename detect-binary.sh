#!/bin/bash
set -e

git fetch origin "$GITHUB_BASE_REF"

echo "new_files=" >> "$GITHUB_ENV"
echo "binary_changed=false" >> "$GITHUB_ENV"

changed_files=$(git diff --numstat origin/"$GITHUB_BASE_REF" | awk '{ if ($1 == "-" && $2 == "-" ) print $3 }')

if [ -z "$changed_files" ]; then
  echo "No binary changes detected."
  exit 0
fi

echo "Binary changes detected:"
echo "$changed_files"

echo "binary_changed=true" >> "$GITHUB_ENV"
{
  echo "new_files<<EOF"
  echo "$changed_files"
  echo "EOF"
} >> "$GITHUB_ENV"

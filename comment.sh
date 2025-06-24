#!/bin/bash
set -e

PR_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

if [ -z "$PR_NUMBER" ] || [ "$PR_NUMBER" == "null" ]; then
  echo "Error: Could not determine PR number from event payload."
  exit 1
fi

COMMENTS_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments"

echo "Fetching existing comments from $COMMENTS_URL"
existing_comments=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "$COMMENTS_URL")

comment_id=""

for row in $(echo "$existing_comments" | jq -r '.[] | @base64'); do
  _jq() {
    echo "$row" | base64 --decode | jq -r "$1"
  }
  body=$(_jq '.body')
  if echo "$body" | grep -q "⚠️ Warning: Binary File Changed or Added! ⚠️"; then
    comment_id=$(_jq '.id')
    break
  fi
done

# Build the comment body with real newlines (not \n)
COMMENT_BODY="### ⚠️ Warning: Binary File Changed or Added! ⚠️

This PR has modified or added the following binary file(s):

"
while IFS= read -r file; do
  COMMENT_BODY+="- \`${file}\`
"
done <<< "${new_files}"

COMMENT_BODY+="

While these changes may be intentional, please ensure a thorough review is conducted to avoid any potential issues or backdoors."

# Use jq to escape JSON safely
JSON_BODY=$(jq -nc --arg body "$COMMENT_BODY" '{body: $body}')

if [ -z "$comment_id" ]; then
  echo "Posting new comment..."
  curl -s -H "Authorization: token ${GITHUB_TOKEN}" -X POST \
    -d "$JSON_BODY" "$COMMENTS_URL"
else
  echo "Updating existing comment with id $comment_id..."
  curl -s -H "Authorization: token ${GITHUB_TOKEN}" -X PATCH \
    -d "$JSON_BODY" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}"
fi

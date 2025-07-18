#!/bin/bash
set -e

WEBHOOK_URL=$WEBHOOK_URL
FILE=$FILE
MAX_DISCORD_LEN=1900

echo "📄 URL : $WEBHOOK_URL"
echo "📄 Diffing file: $FILE"

git diff HEAD^ HEAD -- "$FILE" \
  | grep -E '^[+-]' \
  | grep -vE '^\+\+\+|^---' \
  > filtered.diff

DIFF_CONTENT=$(cat filtered.diff)

PAGE_CONTENT=""
CHAR_COUNT=0
PAGE_NUM=1

send_page() {
  if [ -z "$PAGE_CONTENT" ]; then return; fi

  MESSAGE="Diff pour \`$FILE\` (page $PAGE_NUM):\n\`\`\`diff
$PAGE_CONTENT
\`\`\`"

  jq -n --arg content "$MESSAGE" '{content: $content}' | \
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d @-

  sleep 1
  PAGE_CONTENT=""
  CHAR_COUNT=0
  ((PAGE_NUM++))
}

while IFS= read -r line; do
  LINE_LEN=${#line}
  if (( CHAR_COUNT + LINE_LEN + 1 > MAX_DISCORD_LEN )); then
    send_page
  fi
  PAGE_CONTENT+="$line"$'\n'
  ((CHAR_COUNT += LINE_LEN + 1))
done <<< "$DIFF_CONTENT"

send_page

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "✅ Diff envoyé à Discord avec succès."}'

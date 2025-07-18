#!/bin/bash
set -e

WEBHOOK_URL="https://discord.com/api/webhooks/1395666955201150986/-4CYXIpa5HsCyiXAS5vD1FmZ056xZDVnioNKf8RVPUgy1KIKZLW6v3KMiZr51xkDr5TQ"
FILE="regles.md"
MAX_DISCORD_LEN=1900

# Vérifier l'existence du fichier
if [ ! -f "$FILE" ]; then
  echo "Erreur : Le fichier $FILE n'existe pas."
  exit 1
fi

echo "📄 URL : $WEBHOOK_URL"
echo "📄 Diffing file: $FILE"

# Exécuter git diff et filtrer les lignes ajoutées ou supprimées
git diff HEAD^ HEAD -- "$FILE" \
  | grep -E '^[+-]' \
  | grep -vE '^\+\+\+|^---' \
  > filtered.diff

# Vérifier si le fichier diff est vide
if [ ! -s filtered.diff ]; then
  echo "Aucune modification dans $FILE. Aucune action effectuée."
  exit 0
fi

# Lire le contenu du diff
DIFF_CONTENT=$(cat filtered.diff)

PAGE_CONTENT=""
CHAR_COUNT=0
PAGE_NUM=1

send_page() {
  if [ -z "$PAGE_CONTENT" ]; then return; fi

  # On échappe les guillemets dans MESSAGE et on remplace les retours à la ligne
  MESSAGE="Diff pour \`$FILE\` (page $PAGE_NUM):\n\`\`\`diff
$PAGE_CONTENT
\`\`\`"
  
  # Échapper les guillemets pour éviter une erreur de formatage JSON
  ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

  # Envoyer le message via webhook Discord
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"$ESCAPED_MESSAGE\"}"

  sleep 1
  PAGE_CONTENT=""
  CHAR_COUNT=0
  ((PAGE_NUM++))
}

# Processer chaque ligne du diff et découper si nécessaire
while IFS= read -r line; do
  LINE_LEN=${#line}
  if (( CHAR_COUNT + LINE_LEN + 1 > MAX_DISCORD_LEN )); then
    send_page
  fi
  PAGE_CONTENT+="$line"$'\n'
  ((CHAR_COUNT += LINE_LEN + 1))
done <<< "$DIFF_CONTENT"

# Envoyer la dernière page si elle existe
send_page

# Confirmer que le diff a été envoyé
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "✅ Diff envoyé à Discord avec succès."}'

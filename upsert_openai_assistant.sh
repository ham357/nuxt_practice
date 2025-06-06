#!/bin/bash

PROJECT_API_KEY="$1"
DIR="$2"

SETTING_FILE="${DIR}/setting.json"
ASSISTANT_ID=$(jq -r '.assistant_id' "$SETTING_FILE")
ASSISTANT_NAME=$(jq -r '.assistant_name' "$SETTING_FILE")
MODEL=$(jq -r '.model' "$SETTING_FILE")
TOP_P=$(jq -r '.top_p' "$SETTING_FILE")
TEMPERATURE=$(jq -r '.temperature' "$SETTING_FILE")
RESPONSE_FORMAT=$(jq '.response_format' "$SETTING_FILE")
INSTRUCTION_FILE="${DIR}/instruction.txt"
INSTRUCTION=$(cat "$INSTRUCTION_FILE")

# JSONデータの安全な生成
JSON_PAYLOAD=$(jq -n \
  --arg name "$ASSISTANT_NAME" \
  --arg instructions "$INSTRUCTION" \
  --arg model "$MODEL" \
  --argjson response_format "$RESPONSE_FORMAT" \
  --argjson top_p "$TOP_P" \
  --argjson temperature "$TEMPERATURE" \
  '{
    name: $name,
    instructions: $instructions,
    model: $model,
    top_p: $top_p,
    temperature: $temperature,
    response_format: $response_format
  }')

# ASSISTANT_IDの有無でcreate or updateを判定
if [[ -n "$ASSISTANT_ID" ]]; then
  URL="https://api.openai.com/v1/assistants/${ASSISTANT_ID}"
  ACTION_TYPE="update"
else
  URL="https://api.openai.com/v1/assistants"
  ACTION_TYPE="create"
fi

echo "ACTION_TYPE=$ACTION_TYPE" >> $GITHUB_ENV

# curlコマンドでリクエストを送信
RESPONSE=$(curl -s -o response.json -w "%{http_code}" \
  -X POST \
  "$URL" \
  -H "Content-Type: application/json" \
  -H "OpenAI-Beta: assistants=v2" \
  -H "Authorization: Bearer ${PROJECT_API_KEY}" \
  -d "$JSON_PAYLOAD")

# HTTPステータスコードの確認
if [[ "$RESPONSE" -ne 200 ]]; then
  echo "Error: API request failed with status code $RESPONSE."
  echo "Response:"
  cat response.json
  exit 1
fi

# 正常終了の場合
echo "Request was successful. Response:"
cat response.json

id=$(jq -r '.id' response.json)
jq --arg assistant_id "$id" '.assistant_id = $assistant_id' "$SETTING_FILE" > tmp.json
mv tmp.json "$SETTING_FILE"
rm response.json

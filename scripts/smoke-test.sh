#!/usr/bin/env bash
set -euo pipefail

: "${FRONTEND_URL:?Set FRONTEND_URL to the https CloudFront URL}"
: "${API_URL:?Set API_URL to the HTTP API invoke URL}"

session_one="$(python3 -c 'import uuid; print(uuid.uuid4())')"
session_two="$(python3 -c 'import uuid; print(uuid.uuid4())')"

curl --fail --silent --show-error "${FRONTEND_URL}/" >/dev/null
first="$(curl --fail --silent --show-error \
  -H 'content-type: application/json' \
  -d "{\"sessionId\":\"${session_one}\",\"message\":\"What is a Terraform plan?\"}" \
  "${API_URL}/chat")"
echo "${first}" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["answer"]; assert isinstance(d["citations"], list)'

history="$(curl --fail --silent --show-error "${API_URL}/sessions/${session_one}/messages")"
echo "${history}" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d["messages"]) >= 2'

isolated="$(curl --fail --silent --show-error "${API_URL}/sessions/${session_two}/messages")"
echo "${isolated}" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["messages"] == []'

echo "Frontend, chat, persistence, and session-isolation smoke checks passed."

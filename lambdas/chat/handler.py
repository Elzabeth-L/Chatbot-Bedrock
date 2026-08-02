"""HTTP API handler for session-backed Bedrock Knowledge Base chat."""

from __future__ import annotations

import json
import logging
import os
import time
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any
from urllib.parse import unquote, urlparse

import boto3
from boto3.dynamodb.conditions import Key
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

LOGGER = logging.getLogger()
LOGGER.setLevel(os.getenv("LOG_LEVEL", "INFO"))

AWS_CONFIG = Config(retries={"max_attempts": 3, "mode": "adaptive"})
DYNAMODB = boto3.resource("dynamodb", config=AWS_CONFIG)
BEDROCK = boto3.client("bedrock-agent-runtime", config=AWS_CONFIG)
TABLE = DYNAMODB.Table(os.environ["TABLE_NAME"])

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
GENERATION_MODEL_ARN = os.environ["GENERATION_MODEL_ARN"]
SESSION_TTL_SECONDS = int(os.getenv("SESSION_TTL_SECONDS", "86400"))
MAX_MESSAGE_LENGTH = int(os.getenv("MAX_MESSAGE_LENGTH", "2000"))
MAX_HISTORY_MESSAGES = int(os.getenv("MAX_HISTORY_MESSAGES", "12"))
MAX_HISTORY_RESPONSE_MESSAGES = int(os.getenv("MAX_HISTORY_RESPONSE_MESSAGES", "100"))
MAX_CITATIONS = int(os.getenv("MAX_CITATIONS", "5"))

INSUFFICIENT_ANSWER = (
    "I don't have enough information in the knowledge base to answer that question."
)
SESSION_ID_ERROR = "sessionId must be a valid UUID."
GENERATION_PROMPT = f"""You are a documentation assistant.
Answer using only facts explicitly present in the retrieved sources below.
Do not add facts from general knowledge, assumptions, or the conversation history.
If the sources do not fully support an answer, respond exactly with:
{INSUFFICIENT_ANSWER}
Do not append an explanation to that fallback response.

Retrieved sources:
$search_results$

User request and bounded conversation context:
$query$

$output_format_instructions$"""


def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, default=_json_default),
    }


def _json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"Cannot serialize {type(value)!r}")


def validate_session_id(value: Any) -> str:
    if not isinstance(value, str) or len(value) > 64:
        raise ValueError(SESSION_ID_ERROR)
    try:
        parsed = uuid.UUID(value)
    except (ValueError, AttributeError) as exc:
        raise ValueError(SESSION_ID_ERROR) from exc
    if str(parsed) != value.lower():
        raise ValueError(SESSION_ID_ERROR)
    return str(parsed)


def validate_chat_body(raw_body: Any) -> tuple[str, str]:
    if not isinstance(raw_body, str) or not raw_body.strip():
        raise ValueError("Request body must be a JSON object.")
    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValueError("Request body must contain valid JSON.") from exc
    if not isinstance(body, dict):
        raise ValueError("Request body must be a JSON object.")

    session_id = validate_session_id(body.get("sessionId"))
    message = body.get("message")
    if not isinstance(message, str):
        raise ValueError("message must be a string.")
    message = message.strip()
    if not message:
        raise ValueError("message must not be empty.")
    if len(message) > MAX_MESSAGE_LENGTH:
        raise ValueError(f"message must be at most {MAX_MESSAGE_LENGTH} characters.")
    return session_id, message


def ttl_from_epoch(now_epoch: int) -> int:
    return now_epoch + SESSION_TTL_SECONDS


def load_messages(session_id: str, limit: int) -> list[dict[str, Any]]:
    result = TABLE.query(
        KeyConditionExpression=Key("session_id").eq(session_id),
        ScanIndexForward=False,
        Limit=limit,
        ProjectionExpression=(
            "message_id, #role, content, citations, created_at, expires_at"
        ),
        ExpressionAttributeNames={"#role": "role"},
    )
    now = int(time.time())
    current = [item for item in result.get("Items", []) if int(item["expires_at"]) > now]
    current.reverse()
    return current


def format_history(messages: list[dict[str, Any]], question: str) -> str:
    lines = [
        "Use only the retrieved knowledge-base sources to answer.",
        f'If the sources are insufficient, answer exactly: "{INSUFFICIENT_ANSWER}"',
        "Conversation context is provided only to resolve references; do not treat it as a source.",
        "",
        "Conversation:",
    ]
    for message in messages[-MAX_HISTORY_MESSAGES:]:
        label = "User" if message.get("role") == "user" else "Assistant"
        content = str(message.get("content", ""))[:MAX_MESSAGE_LENGTH]
        lines.append(f"{label}: {content}")
    lines.append(f"User: {question}")
    lines.append("Assistant:")
    return "\n".join(lines)


def _citation_location(reference: dict[str, Any]) -> tuple[str, str | None]:
    location = reference.get("location", {})
    location_type = location.get("type", "")
    if location_type == "S3":
        uri = location.get("s3Location", {}).get("uri", "")
        name = unquote(urlparse(uri).path.rsplit("/", 1)[-1]) or "Knowledge-base document"
        return name, None
    if location_type == "WEB":
        url = location.get("webLocation", {}).get("url")
        return location.get("webLocation", {}).get("url", "Web source"), url
    return "Knowledge-base source", None


def extract_citations(result: dict[str, Any]) -> list[dict[str, str]]:
    citations: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for citation in result.get("citations", []):
        for reference in citation.get("retrievedReferences", []):
            title, uri = _citation_location(reference)
            excerpt = str(reference.get("content", {}).get("text", "")).strip()
            excerpt = excerpt[:500]
            key = (title, excerpt)
            if key in seen:
                continue
            seen.add(key)
            item = {"title": title, "excerpt": excerpt}
            if uri:
                item["uri"] = uri
            citations.append(item)
            if len(citations) >= MAX_CITATIONS:
                return citations
    return citations


def call_knowledge_base(history: list[dict[str, Any]], question: str) -> tuple[str, list]:
    result = BEDROCK.retrieve_and_generate(
        input={"text": format_history(history, question)},
        retrieveAndGenerateConfiguration={
            "type": "KNOWLEDGE_BASE",
            "knowledgeBaseConfiguration": {
                "knowledgeBaseId": KNOWLEDGE_BASE_ID,
                "modelArn": GENERATION_MODEL_ARN,
                "retrievalConfiguration": {
                    "vectorSearchConfiguration": {"numberOfResults": 5}
                },
                "generationConfiguration": {
                    "promptTemplate": {"textPromptTemplate": GENERATION_PROMPT},
                    "inferenceConfig": {
                        "textInferenceConfig": {
                            "maxTokens": 600,
                            "temperature": 0.1,
                            "topP": 0.9,
                        }
                    }
                },
            },
        },
    )
    citations = extract_citations(result)
    answer = str(result.get("output", {}).get("text", "")).strip()
    if (
        not citations
        or not answer
        or INSUFFICIENT_ANSWER.casefold() in answer.casefold()
    ):
        return INSUFFICIENT_ANSWER, []
    return answer, citations


def save_turn(session_id: str, question: str, answer: str, citations: list) -> None:
    now_epoch = int(time.time())
    created_at = datetime.fromtimestamp(now_epoch, UTC).isoformat()
    expiry = ttl_from_epoch(now_epoch)
    base = f"{now_epoch * 1000:013d}"
    with TABLE.batch_writer() as batch:
        batch.put_item(
            Item={
                "session_id": session_id,
                "message_id": f"{base}#0#{uuid.uuid4()}",
                "role": "user",
                "content": question,
                "citations": [],
                "created_at": created_at,
                "expires_at": expiry,
            }
        )
        batch.put_item(
            Item={
                "session_id": session_id,
                "message_id": f"{base}#1#{uuid.uuid4()}",
                "role": "assistant",
                "content": answer,
                "citations": citations,
                "created_at": created_at,
                "expires_at": expiry,
            }
        )


def public_message(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "role": item["role"],
        "content": item["content"],
        "citations": item.get("citations", []),
        "createdAt": item["created_at"],
    }


def _route_key(event: dict[str, Any]) -> str:
    return event.get("routeKey") or event.get("requestContext", {}).get("routeKey", "")


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    route = _route_key(event)
    request_id = event.get("requestContext", {}).get("requestId", "unknown")
    LOGGER.info(json.dumps({"event": "request_started", "route": route, "requestId": request_id}))
    try:
        if route == "POST /chat":
            session_id, message = validate_chat_body(event.get("body"))
            history = load_messages(session_id, MAX_HISTORY_MESSAGES)
            answer, citations = call_knowledge_base(history, message)
            save_turn(session_id, message, answer, citations)
            return response(
                200,
                {"sessionId": session_id, "answer": answer, "citations": citations},
            )

        if route == "GET /sessions/{sessionId}/messages":
            session_id = validate_session_id(
                event.get("pathParameters", {}).get("sessionId")
            )
            messages = load_messages(session_id, MAX_HISTORY_RESPONSE_MESSAGES)
            return response(
                200,
                {"sessionId": session_id, "messages": [public_message(item) for item in messages]},
            )

        return response(404, {"error": {"code": "not_found", "message": "Route not found."}})
    except ValueError as exc:
        return response(400, {"error": {"code": "invalid_request", "message": str(exc)}})
    except (ClientError, BotoCoreError) as exc:
        error_code = getattr(exc, "response", {}).get("Error", {}).get("Code", "AwsError")
        LOGGER.exception(
            json.dumps({"event": "aws_error", "requestId": request_id, "code": error_code})
        )
        status = 429 if "Throttl" in error_code else 502
        return response(
            status,
            {
                "error": {
                    "code": "temporarily_unavailable",
                    "message": "The chat service is temporarily unavailable.",
                }
            },
        )
    except Exception:
        LOGGER.exception(json.dumps({"event": "unhandled_error", "requestId": request_id}))
        return response(
            500,
            {"error": {"code": "internal_error", "message": "An unexpected error occurred."}},
        )

from __future__ import annotations

import json
import uuid
from decimal import Decimal

import pytest


def test_request_validation_accepts_uuid_and_trimmed_message(chat):
    session_id = str(uuid.uuid4())
    actual = chat.validate_chat_body(
        json.dumps({"sessionId": session_id, "message": "  What is a plan?  "})
    )
    assert actual == (session_id, "What is a plan?")


def test_response_serializes_dynamodb_numbers(chat):
    result = chat.response(200, {"whole": Decimal("2"), "fraction": Decimal("2.5")})
    assert json.loads(result["body"]) == {"whole": 2, "fraction": 2.5}

    with pytest.raises(TypeError, match="Cannot serialize"):
        chat._json_default(object())


@pytest.mark.parametrize(
    "body, message",
    [
        ("not-json", "valid JSON"),
        (None, "JSON object"),
        (json.dumps([]), "JSON object"),
        (json.dumps({"sessionId": "unknown", "message": "hello"}), "valid UUID"),
        (json.dumps({"sessionId": str(uuid.uuid4()), "message": 3}), "must be a string"),
        (json.dumps({"sessionId": str(uuid.uuid4()), "message": "   "}), "must not be empty"),
    ],
)
def test_invalid_requests(chat, body, message):
    with pytest.raises(ValueError, match=message):
        chat.validate_chat_body(body)


def test_ttl_generation(chat, monkeypatch):
    monkeypatch.setattr(chat, "SESSION_TTL_SECONDS", 86_400)
    assert chat.ttl_from_epoch(1_700_000_000) == 1_700_086_400


def test_request_validation_rejects_noncanonical_uuid_and_long_message(chat, monkeypatch):
    session_id = str(uuid.uuid4())
    with pytest.raises(ValueError, match="valid UUID"):
        chat.validate_session_id("{" + session_id + "}")

    monkeypatch.setattr(chat, "MAX_MESSAGE_LENGTH", 4)
    with pytest.raises(ValueError, match="at most 4"):
        chat.validate_chat_body(json.dumps({"sessionId": session_id, "message": "12345"}))


def test_load_messages_filters_expired_items_and_restores_order(chat, monkeypatch):
    class Table:
        def query(self, **_kwargs):
            return {
                "Items": [
                    {"message_id": "new", "expires_at": 200},
                    {"message_id": "expired", "expires_at": 99},
                    {"message_id": "old", "expires_at": 150},
                ]
            }

    monkeypatch.setattr(chat, "TABLE", Table())
    monkeypatch.setattr(chat.time, "time", lambda: 100)
    assert [item["message_id"] for item in chat.load_messages("session", 10)] == [
        "old",
        "new",
    ]


def test_extract_citations_sanitizes_private_s3_uri(chat):
    result = {
        "citations": [
            {
                "retrievedReferences": [
                    {
                        "content": {"text": "A plan proposes infrastructure changes."},
                        "location": {
                            "type": "S3",
                            "s3Location": {
                                "uri": (
                                    "s3://private-bucket/knowledge-base/documents/"
                                    "terraform-basics.md"
                                )
                            },
                        },
                    }
                ]
            }
        ]
    }
    assert chat.extract_citations(result) == [
        {
            "title": "terraform-basics.md",
            "excerpt": "A plan proposes infrastructure changes.",
        }
    ]


def test_extract_citations_supports_web_sources_and_removes_duplicates(chat):
    reference = {
        "content": {"text": "Official guidance"},
        "location": {
            "type": "WEB",
            "webLocation": {"url": "https://docs.example.test/guide"},
        },
    }
    result = {
        "citations": [
            {"retrievedReferences": [reference]},
            {"retrievedReferences": [reference]},
        ]
    }
    assert chat.extract_citations(result) == [
        {
            "title": "https://docs.example.test/guide",
            "excerpt": "Official guidance",
            "uri": "https://docs.example.test/guide",
        }
    ]


def test_empty_retrieval_is_insufficient(chat, monkeypatch):
    class EmptyBedrock:
        def retrieve_and_generate(self, **_kwargs):
            return {"output": {"text": "An unsupported guess"}, "citations": []}

    monkeypatch.setattr(chat, "BEDROCK", EmptyBedrock())
    answer, citations = chat.call_knowledge_base([], "Unknown topic?")
    assert answer == chat.INSUFFICIENT_ANSWER
    assert citations == []


def test_contradictory_insufficient_answer_is_collapsed(chat, monkeypatch):
    class ContradictoryBedrock:
        def retrieve_and_generate(self, **kwargs):
            prompt = kwargs["retrieveAndGenerateConfiguration"][
                "knowledgeBaseConfiguration"
            ]["generationConfiguration"]["promptTemplate"]["textPromptTemplate"]
            assert "$search_results$" in prompt
            assert "$output_format_instructions$" in prompt
            return {
                "output": {
                    "text": f"{chat.INSUFFICIENT_ANSWER} Unsupported extra facts."
                },
                "citations": [
                    {
                        "retrievedReferences": [
                            {
                                "content": {"text": "A partial source."},
                                "location": {
                                    "type": "S3",
                                    "s3Location": {"uri": "s3://bucket/doc.md"},
                                },
                            }
                        ]
                    }
                ],
            }

    monkeypatch.setattr(chat, "BEDROCK", ContradictoryBedrock())
    answer, citations = chat.call_knowledge_base([], "Question?")
    assert answer == chat.INSUFFICIENT_ANSWER
    assert citations == []


def test_public_message_transformation(chat):
    item = {
        "role": "assistant",
        "content": "Grounded answer",
        "citations": [{"title": "doc.md"}],
        "created_at": "2026-07-28T10:00:00+00:00",
        "expires_at": 1_800_000_000,
        "message_id": "ignored",
    }
    assert chat.public_message(item) == {
        "role": "assistant",
        "content": "Grounded answer",
        "citations": [{"title": "doc.md"}],
        "createdAt": "2026-07-28T10:00:00+00:00",
    }


def test_save_turn_writes_consistent_dynamodb_records(chat, monkeypatch):
    written = []

    class Batch:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def put_item(self, Item):
            written.append(Item)

    class Table:
        def batch_writer(self):
            return Batch()

    monkeypatch.setattr(chat, "TABLE", Table())
    monkeypatch.setattr(chat.time, "time", lambda: 1_700_000_000)
    chat.save_turn("session", "question", "answer", [{"title": "doc.md"}])

    assert [item["role"] for item in written] == ["user", "assistant"]
    assert written[0]["expires_at"] == written[1]["expires_at"]
    assert written[0]["message_id"] < written[1]["message_id"]
    assert written[1]["citations"] == [{"title": "doc.md"}]


def test_unknown_session_returns_empty_history(chat, monkeypatch):
    session_id = str(uuid.uuid4())
    monkeypatch.setattr(chat, "load_messages", lambda *_args: [])
    result = chat.handler(
        {
            "routeKey": "GET /sessions/{sessionId}/messages",
            "pathParameters": {"sessionId": session_id},
            "requestContext": {"requestId": "test"},
        },
        None,
    )
    assert result["statusCode"] == 200
    assert json.loads(result["body"])["messages"] == []

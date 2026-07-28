"""Coalesce document events and start one Bedrock Knowledge Base ingestion job."""

from __future__ import annotations

import hashlib
import json
import logging
import os
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

LOGGER = logging.getLogger()
LOGGER.setLevel(os.getenv("LOG_LEVEL", "INFO"))
BEDROCK = boto3.client(
    "bedrock-agent",
    config=Config(retries={"max_attempts": 3, "mode": "adaptive"}),
)
KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
DATA_SOURCE_ID = os.environ["DATA_SOURCE_ID"]
ACTIVE_STATUSES = {"STARTING", "IN_PROGRESS", "STOPPING"}


def record_ids(event: dict[str, Any]) -> list[str]:
    return [
        record["messageId"]
        for record in event.get("Records", [])
        if isinstance(record.get("messageId"), str)
    ]


def failures(ids: list[str]) -> dict[str, list[dict[str, str]]]:
    return {"batchItemFailures": [{"itemIdentifier": item_id} for item_id in ids]}


def has_active_job(jobs: list[dict[str, Any]]) -> bool:
    return any(job.get("status") in ACTIVE_STATUSES for job in jobs)


def client_token(ids: list[str]) -> str:
    """Stable Bedrock idempotency token for an at-least-once SQS batch."""
    return hashlib.sha256("\n".join(sorted(ids)).encode()).hexdigest()


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    ids = record_ids(event)
    if not ids:
        LOGGER.info(json.dumps({"event": "empty_batch"}))
        return failures([])

    try:
        jobs = BEDROCK.list_ingestion_jobs(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
            maxResults=10,
            sortBy={"attribute": "STARTED_AT", "order": "DESCENDING"},
        ).get("ingestionJobSummaries", [])
        if has_active_job(jobs):
            LOGGER.info(
                json.dumps(
                    {
                        "event": "ingestion_deferred",
                        "reason": "active_job",
                        "count": len(ids),
                    }
                )
            )
            return failures(ids)

        job = BEDROCK.start_ingestion_job(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
            clientToken=client_token(ids),
            description=f"Automatic S3 synchronization for {len(ids)} queued event(s)",
        )["ingestionJob"]
        LOGGER.info(
            json.dumps(
                {
                    "event": "ingestion_started",
                    "jobId": job.get("ingestionJobId"),
                    "status": job.get("status"),
                    "eventCount": len(ids),
                }
            )
        )
        return failures([])
    except (ClientError, BotoCoreError):
        LOGGER.exception(json.dumps({"event": "ingestion_start_failed", "eventCount": len(ids)}))
        # Raising increments the Lambda Errors metric and lets the SQS event source
        # retry the complete batch before redriving it to the DLQ.
        raise

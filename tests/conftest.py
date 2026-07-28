from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]

os.environ.setdefault("AWS_ACCESS_KEY_ID", "testing")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "testing")
os.environ.setdefault("AWS_SESSION_TOKEN", "testing")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("AWS_EC2_METADATA_DISABLED", "true")
os.environ.setdefault("TABLE_NAME", "test-sessions")
os.environ.setdefault("KNOWLEDGE_BASE_ID", "TESTKB1234")
os.environ.setdefault(
    "GENERATION_MODEL_ARN",
    "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-micro-v1:0",
)
os.environ.setdefault("DATA_SOURCE_ID", "TESTDS1234")


def load_module(name: str, relative_path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    assert spec.loader
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="session")
def chat():
    return load_module("chat_handler", "lambdas/chat/handler.py")


@pytest.fixture(scope="session")
def ingestion():
    return load_module("ingestion_handler", "lambdas/ingestion/handler.py")

from __future__ import annotations


def test_record_ids(ingestion):
    event = {"Records": [{"messageId": "one"}, {"messageId": "two"}, {}]}
    assert ingestion.record_ids(event) == ["one", "two"]


def test_active_job_detection(ingestion):
    assert ingestion.has_active_job([{"status": "IN_PROGRESS"}])
    assert not ingestion.has_active_job([{"status": "COMPLETE"}])


def test_batch_token_is_order_independent(ingestion):
    assert ingestion.client_token(["two", "one"]) == ingestion.client_token(["one", "two"])
    assert len(ingestion.client_token(["one"])) == 64


def test_active_job_retries_entire_batch(ingestion, monkeypatch):
    class BusyBedrock:
        def list_ingestion_jobs(self, **_kwargs):
            return {"ingestionJobSummaries": [{"status": "STARTING"}]}

    monkeypatch.setattr(ingestion, "BEDROCK", BusyBedrock())
    result = ingestion.handler({"Records": [{"messageId": "one"}]}, None)
    assert result == {"batchItemFailures": [{"itemIdentifier": "one"}]}


def test_starts_only_one_job_for_batch(ingestion, monkeypatch):
    class ReadyBedrock:
        starts = 0

        def list_ingestion_jobs(self, **_kwargs):
            return {"ingestionJobSummaries": []}

        def start_ingestion_job(self, **_kwargs):
            self.starts += 1
            return {"ingestionJob": {"ingestionJobId": "JOB1", "status": "STARTING"}}

    client = ReadyBedrock()
    monkeypatch.setattr(ingestion, "BEDROCK", client)
    result = ingestion.handler(
        {"Records": [{"messageId": "one"}, {"messageId": "two"}]}, None
    )
    assert client.starts == 1
    assert result == {"batchItemFailures": []}

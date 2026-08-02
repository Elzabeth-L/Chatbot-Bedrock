from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_new_chat_uses_the_defined_session_storage_key():
    source = (ROOT / "frontend" / "app.js").read_text(encoding="utf-8")
    assert "SESSION_KEY" not in source
    assert 'newChatButton.addEventListener("click", startNewChat)' in source
    assert "SESSION_STORAGE_ITEM" in source
    assert "SESSION_INDEX_ITEM" in source


def test_session_navigation_elements_exist():
    markup = (ROOT / "frontend" / "index.html").read_text(encoding="utf-8")
    for element_id in ("new-chat", "session-list", "conversation", "chat-form"):
        assert f'id="{element_id}"' in markup

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
    for element_id in (
        "new-chat",
        "session-list",
        "sidebar-toggle",
        "sidebar-backdrop",
        "active-chat-title",
        "conversation",
        "chat-form",
    ):
        assert f'id="{element_id}"' in markup


def test_professional_sidebar_uses_cache_safe_stylesheet():
    markup = (ROOT / "frontend" / "index.html").read_text(encoding="utf-8")
    styles = (ROOT / "frontend" / "styles.css").read_text(encoding="utf-8")
    terraform = (ROOT / "terraform" / "frontend.tf").read_text(encoding="utf-8")

    assert 'href="chat.css"' in markup
    assert ".sessions-panel" in styles
    assert "body.sidebar-open .sessions-panel" in styles
    assert 'key                    = "chat.css"' in terraform
    assert 'cache_control          = "no-cache"' in terraform


def test_chat_titles_come_from_the_first_question():
    source = (ROOT / "frontend" / "app.js").read_text(encoding="utf-8")
    assert "function titleFromMessage(message)" in source
    assert "titleFromMessage(firstQuestion)" in source
    assert "titleFromMessage(message)" in source

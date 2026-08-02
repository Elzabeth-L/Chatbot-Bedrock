"use strict";

const API_URL = window.APP_CONFIG?.API_URL || "";
const SESSION_STORAGE_ITEM = "bedrock-rag-session-id";
const SESSION_INDEX_ITEM = "bedrock-rag-sessions-v1";
const MAX_STORED_SESSIONS = 25;

const conversation = document.querySelector("#conversation");
const form = document.querySelector("#chat-form");
const input = document.querySelector("#message");
const sendButton = document.querySelector("#send");
const status = document.querySelector("#status");
const sessionList = document.querySelector("#session-list");
const newChatButton = document.querySelector("#new-chat");
const historyCount = document.querySelector("#history-count");
const activeChatTitle = document.querySelector("#active-chat-title");
const sidebarToggle = document.querySelector("#sidebar-toggle");
const sidebarBackdrop = document.querySelector("#sidebar-backdrop");

let currentSessionId = "";
let restoreSequence = 0;
let busy = false;

function newSessionId() {
  return crypto.randomUUID();
}

function isSessionId(value) {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function titleFromMessage(message) {
  const normalized = message.replace(/\s+/g, " ").trim();
  if (normalized.length <= 48) return normalized;
  return `${normalized.slice(0, 47).trimEnd()}...`;
}

function isGenericTitle(title) {
  return !title || title === "New chat" || title === "Chat" || /^Chat\s/.test(title);
}

function formatUpdatedAt(timestamp) {
  if (!timestamp) return "Saved conversation";
  const updated = new Date(timestamp);
  const today = new Date();
  if (updated.toDateString() === today.toDateString()) {
    return updated.toLocaleTimeString([], {hour: "numeric", minute: "2-digit"});
  }
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (updated.toDateString() === yesterday.toDateString()) return "Yesterday";
  return updated.toLocaleDateString([], {month: "short", day: "numeric"});
}

function loadSessions() {
  try {
    const parsed = JSON.parse(localStorage.getItem(SESSION_INDEX_ITEM) || "[]");
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((item) => isSessionId(item?.id) && typeof item.title === "string")
      .map((item) => ({
        id: item.id,
        title: item.title.slice(0, 80) || "Chat",
        updatedAt: Number.isFinite(item.updatedAt) ? item.updatedAt : 0,
      }))
      .sort((left, right) => right.updatedAt - left.updatedAt)
      .slice(0, MAX_STORED_SESSIONS);
  } catch {
    return [];
  }
}

function saveSessions(sessions) {
  localStorage.setItem(SESSION_INDEX_ITEM, JSON.stringify(sessions.slice(0, MAX_STORED_SESSIONS)));
}

function rememberSession(id, updates = {}) {
  const sessions = loadSessions();
  const existing = sessions.find((item) => item.id === id);
  const record = {
    id,
    title: updates.title || existing?.title || "New chat",
    updatedAt: updates.updatedAt || existing?.updatedAt || Date.now(),
  };
  saveSessions([record, ...sessions.filter((item) => item.id !== id)]);
  return record;
}

function activateSession(id) {
  currentSessionId = id;
  localStorage.setItem(SESSION_STORAGE_ITEM, id);
  rememberSession(id);
}

function ensureCurrentSession() {
  const stored = localStorage.getItem(SESSION_STORAGE_ITEM);
  const id = isSessionId(stored) ? stored : newSessionId();
  activateSession(id);
  return id;
}

function setEmptyState(title, message) {
  const empty = document.createElement("div");
  empty.className = "empty";
  const mark = document.createElement("div");
  mark.className = "empty-mark";
  mark.setAttribute("aria-hidden", "true");
  mark.textContent = "D";
  const heading = document.createElement("h2");
  heading.textContent = title;
  const detail = document.createElement("p");
  detail.textContent = message;
  empty.append(mark, heading, detail);
  conversation.replaceChildren(empty);
}

function clearConversation() {
  conversation.replaceChildren();
}

function renderSessions() {
  sessionList.replaceChildren();
  const sessions = loadSessions();
  historyCount.textContent = String(sessions.length);
  const activeSession = sessions.find((session) => session.id === currentSessionId);
  activeChatTitle.textContent = activeSession?.title || "New chat";
  for (const session of sessions) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "session-item";
    button.classList.toggle("active", session.id === currentSessionId);
    button.disabled = busy;
    button.dataset.sessionId = session.id;

    const icon = document.createElement("span");
    icon.className = "session-icon";
    icon.setAttribute("aria-hidden", "true");
    icon.textContent = "...";
    const title = document.createElement("span");
    title.className = "session-title";
    title.textContent = session.title;
    const updated = document.createElement("span");
    updated.className = "session-updated";
    updated.textContent = formatUpdatedAt(session.updatedAt);
    button.append(icon, title, updated);
    button.addEventListener("click", () => selectSession(session.id));
    sessionList.append(button);
  }
}

function setBusy(value) {
  busy = value;
  sendButton.disabled = value;
  newChatButton.disabled = value;
  renderSessions();
}

function citationView(citations) {
  if (!Array.isArray(citations) || citations.length === 0) return null;
  const wrapper = document.createElement("div");
  wrapper.className = "citations";
  const label = document.createElement("strong");
  label.textContent = "Sources";
  wrapper.append(label);
  const list = document.createElement("ol");
  for (const citation of citations) {
    const item = document.createElement("li");
    const title = document.createElement("span");
    title.className = "citation-title";
    title.textContent = citation.title || "Knowledge-base source";
    item.append(title);
    if (citation.excerpt) item.append(document.createTextNode(` - ${citation.excerpt}`));
    list.append(item);
  }
  wrapper.append(list);
  return wrapper;
}

function addMessage(role, content, citations = []) {
  const article = document.createElement("article");
  article.className = `message ${role}`;
  const text = document.createElement("div");
  text.textContent = content;
  article.append(text);
  const sources = citationView(citations);
  if (sources) article.append(sources);
  conversation.append(article);
  conversation.scrollTop = conversation.scrollHeight;
}

async function api(path, options = {}) {
  if (!API_URL) throw new Error("The API endpoint is not configured.");
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {"content-type": "application/json", ...(options.headers || {})},
  });
  let body = {};
  try {
    body = await response.json();
  } catch {
    throw new Error("The service returned an unreadable response.");
  }
  if (!response.ok) throw new Error(body.error?.message || "The request failed.");
  return body;
}

async function restoreHistory(id = currentSessionId) {
  const requestSequence = ++restoreSequence;
  status.textContent = "Restoring conversation...";
  try {
    const body = await api(`/sessions/${encodeURIComponent(id)}/messages`);
    if (requestSequence !== restoreSequence || id !== currentSessionId) return;
    clearConversation();
    const messages = body.messages || [];
    const session = loadSessions().find((item) => item.id === id);
    const firstQuestion = messages.find((message) => message.role === "user")?.content;
    if (firstQuestion && isGenericTitle(session?.title)) {
      rememberSession(id, {title: titleFromMessage(firstQuestion)});
      renderSessions();
    }
    for (const message of messages) {
      addMessage(message.role, message.content, message.citations);
    }
    if (!messages.length) {
      setEmptyState("What can I help you find?", "Ask a question about the documents in this knowledge base.");
    }
    status.textContent = "";
  } catch (error) {
    if (requestSequence === restoreSequence && id === currentSessionId) {
      status.textContent = error.message;
    }
  }
}

async function selectSession(id) {
  if (busy || !isSessionId(id)) return;
  setSidebarOpen(false);
  if (id === currentSessionId) return;
  activateSession(id);
  renderSessions();
  await restoreHistory(id);
  input.focus();
}

function startNewChat() {
  if (busy) return;
  activateSession(newSessionId());
  ++restoreSequence;
  renderSessions();
  setSidebarOpen(false);
  setEmptyState("What can I help you find?", "Ask a question about the documents in this knowledge base.");
  status.textContent = "";
  input.value = "";
  resizeComposer();
  input.focus();
}

function setSidebarOpen(open) {
  document.body.classList.toggle("sidebar-open", open);
  sidebarToggle.setAttribute("aria-expanded", String(open));
  sidebarBackdrop.tabIndex = open ? 0 : -1;
}

function resizeComposer() {
  input.style.height = "auto";
  input.style.height = `${Math.min(input.scrollHeight, 150)}px`;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = input.value.trim();
  if (!message || busy) return;
  const activeSessionId = currentSessionId;
  const session = loadSessions().find((item) => item.id === activeSessionId);
  const title = isGenericTitle(session?.title) ? titleFromMessage(message) : session.title;
  if (conversation.querySelector(".empty")) clearConversation();
  addMessage("user", message);
  input.value = "";
  resizeComposer();
  rememberSession(activeSessionId, {title, updatedAt: Date.now()});
  renderSessions();
  setBusy(true);
  status.textContent = "Searching the knowledge base...";
  try {
    const body = await api("/chat", {
      method: "POST",
      body: JSON.stringify({sessionId: activeSessionId, message}),
    });
    addMessage("assistant", body.answer, body.citations);
    rememberSession(activeSessionId, {updatedAt: Date.now()});
    status.textContent = "";
  } catch (error) {
    status.textContent = error.message;
  } finally {
    setBusy(false);
    input.focus();
  }
});

newChatButton.addEventListener("click", startNewChat);
sidebarToggle.addEventListener("click", () => {
  setSidebarOpen(!document.body.classList.contains("sidebar-open"));
});
sidebarBackdrop.addEventListener("click", () => setSidebarOpen(false));
input.addEventListener("input", resizeComposer);
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") setSidebarOpen(false);
});

ensureCurrentSession();
renderSessions();
restoreHistory();

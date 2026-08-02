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

function chatTitle(date = new Date()) {
  return `Chat ${date.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })}`;
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
    title: updates.title || existing?.title || chatTitle(),
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
  conversation.innerHTML = `<div class="empty"><h2>${title}</h2><p>${message}</p></div>`;
}

function clearConversation() {
  conversation.replaceChildren();
}

function renderSessions() {
  sessionList.replaceChildren();
  for (const session of loadSessions()) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "session-item";
    button.classList.toggle("active", session.id === currentSessionId);
    button.disabled = busy;
    button.dataset.sessionId = session.id;

    const title = document.createElement("span");
    title.className = "session-title";
    title.textContent = session.title;
    const updated = document.createElement("span");
    updated.className = "session-updated";
    updated.textContent = session.updatedAt
      ? new Date(session.updatedAt).toLocaleString()
      : "Saved conversation";
    button.append(title, updated);
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
    for (const message of body.messages || []) {
      addMessage(message.role, message.content, message.citations);
    }
    if (!body.messages?.length) {
      setEmptyState("New conversation", "Ask a question to begin.");
    }
    status.textContent = "";
  } catch (error) {
    if (requestSequence === restoreSequence && id === currentSessionId) {
      status.textContent = error.message;
    }
  }
}

async function selectSession(id) {
  if (busy || !isSessionId(id) || id === currentSessionId) return;
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
  setEmptyState("New conversation", "Ask a question to begin.");
  status.textContent = "";
  input.value = "";
  input.focus();
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = input.value.trim();
  if (!message || busy) return;
  const activeSessionId = currentSessionId;
  if (conversation.querySelector(".empty")) clearConversation();
  addMessage("user", message);
  input.value = "";
  rememberSession(activeSessionId, {updatedAt: Date.now()});
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

ensureCurrentSession();
renderSessions();
restoreHistory();

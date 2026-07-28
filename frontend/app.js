"use strict";

const API_URL = window.APP_CONFIG?.API_URL || "";
const SESSION_KEY = "bedrock-rag-session-id";
const conversation = document.querySelector("#conversation");
const form = document.querySelector("#chat-form");
const input = document.querySelector("#message");
const sendButton = document.querySelector("#send");
const status = document.querySelector("#status");

function newSessionId() {
  return crypto.randomUUID();
}

function isSessionId(value) {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function sessionId() {
  let value = localStorage.getItem(SESSION_KEY);
  if (!isSessionId(value)) {
    value = newSessionId();
    localStorage.setItem(SESSION_KEY, value);
  }
  return value;
}

function clearConversation() {
  conversation.replaceChildren();
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
    if (citation.excerpt) {
      item.append(document.createTextNode(` — ${citation.excerpt}`));
    }
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

async function restoreHistory() {
  status.textContent = "Restoring conversation…";
  try {
    const body = await api(`/sessions/${encodeURIComponent(sessionId())}/messages`);
    clearConversation();
    for (const message of body.messages || []) {
      addMessage(message.role, message.content, message.citations);
    }
    if (!body.messages?.length) {
      conversation.innerHTML = '<div class="empty"><h2>Ask the documentation</h2><p>Answers are grounded in the small technical corpus deployed with this demo.</p></div>';
    }
    status.textContent = "";
  } catch (error) {
    status.textContent = error.message;
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = input.value.trim();
  if (!message) return;
  if (conversation.querySelector(".empty")) clearConversation();
  addMessage("user", message);
  input.value = "";
  sendButton.disabled = true;
  status.textContent = "Searching the knowledge base…";
  try {
    const body = await api("/chat", {
      method: "POST",
      body: JSON.stringify({sessionId: sessionId(), message}),
    });
    addMessage("assistant", body.answer, body.citations);
    status.textContent = "";
  } catch (error) {
    status.textContent = error.message;
  } finally {
    sendButton.disabled = false;
    input.focus();
  }
});

document.querySelector("#new-chat").addEventListener("click", () => {
  localStorage.setItem(SESSION_KEY, newSessionId());
  clearConversation();
  conversation.innerHTML = '<div class="empty"><h2>New conversation</h2><p>Ask a question to begin.</p></div>';
  status.textContent = "";
  input.focus();
});

restoreHistory();

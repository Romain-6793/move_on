// Assistant immobilier : toggle panneau + fetch JSON (pas de navigation Turbo).
function getRoot() {
  return document.getElementById("chatbot-widget")
}

function chatUrlTemplate(root) {
  return root.dataset.chatbotChatUrlTemplate || ""
}

function messagesUrl(root) {
  return root.dataset.chatbotMessagesUrl || ""
}

function csrfToken(root) {
  return root.dataset.chatbotCsrfToken || ""
}

function buildChatUrl(template, chatId) {
  return template.replace("___CHAT_ID___", String(chatId))
}

async function loadHistory(root, panel, messagesEl) {
  const chatId = sessionStorage.getItem("urbanAssistChatId")
  if (!chatId) return

  const template = chatUrlTemplate(root)
  const url = buildChatUrl(template, chatId)
  const res = await fetch(url, {
    headers: { Accept: "application/json" },
    credentials: "same-origin"
  })
  if (!res.ok) return

  const data = await res.json()
  messagesEl.innerHTML = ""
  ;(data.messages || []).forEach((msg) => appendMessage(messagesEl, msg))
}

function appendMessage(container, msg) {
  const wrap = document.createElement("div")
  wrap.className = `chatbot-widget__bubble chatbot-widget__bubble--${msg.role}`
  wrap.innerHTML = msg.html || ""
  container.appendChild(wrap)
  container.scrollTop = container.scrollHeight
}

function setOpen(root, panel, toggle, open) {
  panel.hidden = !open
  toggle.setAttribute("aria-expanded", open ? "true" : "false")
  if (open) {
    const input = document.getElementById("chatbot-input")
    if (input) input.focus()
  }
}

function bindChatbot() {
  const root = getRoot()
  if (!root || root.dataset.chatbotBound === "1") return
  root.dataset.chatbotBound = "1"

  const toggle = document.getElementById("chatbot-toggle")
  const panel = document.getElementById("chatbot-panel")
  const closeBtn = document.getElementById("chatbot-close")
  const form = document.getElementById("chatbot-form")
  const input = document.getElementById("chatbot-input")
  const messagesEl = document.getElementById("chatbot-messages")

  if (!toggle || !panel || !form || !input || !messagesEl) return

  root.removeAttribute("hidden")

  toggle.addEventListener("click", () => {
    const willOpen = panel.hidden
    setOpen(root, panel, toggle, willOpen)
    if (willOpen) loadHistory(root, panel, messagesEl)
  })

  closeBtn.addEventListener("click", () => {
    setOpen(root, panel, toggle, false)
  })

  form.addEventListener("submit", async (e) => {
    e.preventDefault()
    const text = input.value.trim()
    if (!text) return

    const sendBtn = form.querySelector(".chatbot-widget__send")
    sendBtn.disabled = true

    const userStub = { role: "user", html: escapeHtml(text) }
    appendMessage(messagesEl, userStub)
    input.value = ""

    const typing = document.createElement("div")
    typing.className = "chatbot-widget__typing"
    typing.textContent = "L’assistant réfléchit…"
    messagesEl.appendChild(typing)
    messagesEl.scrollTop = messagesEl.scrollHeight

    const chatId = sessionStorage.getItem("urbanAssistChatId")
    const body = { message: { content: text } }
    if (chatId) body.chat_id = chatId

    try {
      const res = await fetch(messagesUrl(root), {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(root)
        },
        body: JSON.stringify(body)
      })
      typing.remove()

      const data = await res.json().catch(() => ({}))
      if (!res.ok || !data.ok) {
        appendError(messagesEl, data.error || "Une erreur est survenue.")
        return
      }

      if (data.chat_id) sessionStorage.setItem("urbanAssistChatId", String(data.chat_id))
      if (data.assistant_message) appendMessage(messagesEl, data.assistant_message)
    } catch (_err) {
      typing.remove()
      appendError(messagesEl, "Impossible de joindre le serveur.")
    } finally {
      sendBtn.disabled = false
    }
  })
}

function appendError(container, text) {
  const el = document.createElement("div")
  el.className = "chatbot-widget__bubble chatbot-widget__bubble--assistant"
  el.textContent = text
  container.appendChild(el)
  container.scrollTop = container.scrollHeight
}

function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

document.addEventListener("turbo:load", bindChatbot)
document.addEventListener("DOMContentLoaded", bindChatbot)

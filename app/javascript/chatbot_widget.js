// Assistant immobilier : toggle panneau + SSE (streaming) ou fallback JSON.
function getRoot() {
  return document.getElementById("chatbot-widget")
}

function chatUrlTemplate(root) {
  return root.dataset.chatbotChatUrlTemplate || ""
}

function messagesUrl(root) {
  return root.dataset.chatbotMessagesUrl || ""
}

function streamUrl(root) {
  return root.dataset.chatbotStreamUrl || ""
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

function humanErrorMessage(code) {
  const map = {
    rate_limit: "Trop de requêtes vers l’IA. Patientez un peu puis réessayez.",
    quota: "Quota ou facturation côté API IA insuffisant.",
    service_unavailable: "Service IA temporairement indisponible.",
    timeout: "Délai dépassé. Réessayez.",
    unauthorized_api: "Configuration API IA invalide.",
    llm_or_database: "Une erreur technique est survenue.",
    blank_content: "Message vide.",
    unknown_chat: "Conversation introuvable."
  }
  return map[code] || "Une erreur est survenue."
}

async function consumeSseStream(response, handlers) {
  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ""

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })

    let sep
    while ((sep = buffer.indexOf("\n\n")) !== -1) {
      const rawEvent = buffer.slice(0, sep)
      buffer = buffer.slice(sep + 2)
      rawEvent.split("\n").forEach((line) => {
        if (!line.startsWith("data: ")) return
        const payload = line.slice(6).trim()
        if (!payload) return
        try {
          const data = JSON.parse(payload)
          handlers.onEvent(data)
        } catch (_e) {
          /* ignore ligne SSE mal formée */
        }
      })
    }
  }
}

async function sendViaSse(root, messagesEl, input, typingEl, draftText) {
  const url = streamUrl(root)
  if (!url) return false

  const chatId = sessionStorage.getItem("urbanAssistChatId")
  const body = { message: { content: draftText } }
  if (chatId) body.chat_id = chatId

  const res = await fetch(url, {
    method: "POST",
    credentials: "same-origin",
    headers: {
      Accept: "text/event-stream",
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken(root)
    },
    body: JSON.stringify(body)
  })

  if (!res.ok || !res.body) {
    return false
  }

  typingEl.remove()

  let assistantEl = null

  await consumeSseStream(res, {
    onEvent(data) {
      if (data.type === "user_message") {
        return
      }
      if (data.type === "delta") {
        if (!assistantEl) {
          assistantEl = document.createElement("div")
          assistantEl.className = "chatbot-widget__bubble chatbot-widget__bubble--assistant chatbot-widget__bubble--streaming"
          messagesEl.appendChild(assistantEl)
        }
        assistantEl.appendChild(document.createTextNode(data.text || ""))
        messagesEl.scrollTop = messagesEl.scrollHeight
      } else if (data.type === "done") {
        if (data.chat_id) sessionStorage.setItem("urbanAssistChatId", String(data.chat_id))
        if (assistantEl && data.assistant_message) {
          assistantEl.innerHTML = data.assistant_message.html || ""
          assistantEl.classList.remove("chatbot-widget__bubble--streaming")
        }
        input.value = ""
      } else if (data.type === "error") {
        if (assistantEl) {
          assistantEl.remove()
          assistantEl = null
        }
        appendError(messagesEl, humanErrorMessage(data.code) || data.message)
        input.value = draftText
      }
    }
  })

  return true
}

async function sendViaJson(root, messagesEl, input, draftText) {
  const chatId = sessionStorage.getItem("urbanAssistChatId")
  const body = { message: { content: draftText } }
  if (chatId) body.chat_id = chatId

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

  const data = await res.json().catch(() => ({}))
  if (!res.ok || !data.ok) {
    const code = data.error || "llm_or_database"
    appendError(messagesEl, humanErrorMessage(code))
    input.value = draftText
    return
  }

  if (data.chat_id) sessionStorage.setItem("urbanAssistChatId", String(data.chat_id))
  if (data.assistant_message) appendMessage(messagesEl, data.assistant_message)
  input.value = ""
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
    const draftText = input.value.trim()
    if (!draftText) return

    const sendBtn = form.querySelector(".chatbot-widget__send")
    sendBtn.disabled = true

    const userStub = { role: "user", html: escapeHtml(draftText) }
    appendMessage(messagesEl, userStub)

    const typing = document.createElement("div")
    typing.className = "chatbot-widget__typing"
    typing.textContent = "L’assistant réfléchit…"
    messagesEl.appendChild(typing)
    messagesEl.scrollTop = messagesEl.scrollHeight

    try {
      const streamed = await sendViaSse(root, messagesEl, input, typing, draftText)
      if (!streamed) {
        typing.remove()
        await sendViaJson(root, messagesEl, input, draftText)
      }
    } catch (_err) {
      typing.remove()
      appendError(messagesEl, "Impossible de joindre le serveur.")
      input.value = draftText
    } finally {
      sendBtn.disabled = false
    }
  })
}

function appendError(container, text) {
  const el = document.createElement("div")
  el.className = "chatbot-widget__bubble chatbot-widget__bubble--assistant chatbot-widget__error"
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

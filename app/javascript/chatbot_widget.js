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

// Retourne le nombre de messages chargés : permet à l'appelant de décider
// s'il doit afficher le hint d'utilisation (panneau ouvert sans historique).
async function loadHistory(root, panel, messagesEl) {
  const chatId = sessionStorage.getItem("urbanAssistChatId")
  if (!chatId) return 0

  const template = chatUrlTemplate(root)
  const url = buildChatUrl(template, chatId)
  const res = await fetch(url, {
    headers: { Accept: "application/json" },
    credentials: "same-origin"
  })
  if (!res.ok) return 0

  const data = await res.json()
  messagesEl.innerHTML = ""
  const messages = data.messages || []
  messages.forEach((msg) => appendMessage(messagesEl, msg))
  return messages.length
}

// Affiche un court guide d'utilisation à l'ouverture du chatbot.
// On le montre uniquement quand la conversation est vide, pour accompagner
// les nouveaux utilisateurs sans polluer les conversations existantes.
function showUsageHint(container) {
  if (container.querySelector(".chatbot-widget__hint")) return

  const hint = document.createElement("div")
  hint.className = "chatbot-widget__hint"
  // Périmètre réel de l'assistant : questions d'achat / vente de bien en
  // France, avec renseignement sur le prix au m² selon la commune ou la ville.
  // On propose un exemple concret pour aider l'utilisateur à formuler sa
  // première requête sans avoir à deviner le format attendu.
  hint.innerHTML = `
    <p class="chatbot-widget__hint-title">Bienvenue sur l'assistant immobilier&nbsp;👋</p>
    <p>
      Vous pouvez me poser vos questions sur l'<strong>achat</strong> ou la
      <strong>vente</strong> d'un bien en France. Je peux notamment vous
      renseigner sur le <strong>prix au m²</strong> en fonction de la
      <strong>commune</strong> ou de la <strong>ville</strong>.
    </p>
    <p class="chatbot-widget__hint-example-label">Exemple&nbsp;:</p>
    <p class="chatbot-widget__hint-example">
      «&nbsp;Je cherche à acheter un bien de 50 m² minimum en France et j'ai
      150 K€ de budget, quelles communes ou villes me conseilles-tu&nbsp;?&nbsp;»
    </p>
  `
  container.appendChild(hint)
}

// Retire le hint dès que l'utilisateur envoie un message :
// il n'a plus d'utilité une fois la conversation amorcée.
function removeUsageHint(container) {
  const hint = container.querySelector(".chatbot-widget__hint")
  if (hint) hint.remove()
}

// Affiche le bouton "effacer la conversation" uniquement quand il y a au
// moins une bulle (user ou assistant) : inutile de l'afficher sur un chat
// vide, et ça évite un clic qui tente de supprimer un chat inexistant.
function updateClearVisibility(messagesEl, clearBtn) {
  if (!clearBtn) return
  const hasBubbles = messagesEl.querySelector(".chatbot-widget__bubble") !== null
  clearBtn.hidden = !hasBubbles
}

// Hauteur maximum (en px) de la textarea auto-growing. Au-delà, on passe en
// scroll interne plutôt que de continuer à grandir — ça évite que la zone
// de saisie envahisse tout le panneau sur un message très long.
const INPUT_MAX_HEIGHT_PX = 140

// Ajuste dynamiquement la hauteur de la textarea en fonction du contenu :
// démarre à 1 ligne, s'agrandit à chaque retour à la ligne ou wrap, jusqu'à
// `INPUT_MAX_HEIGHT_PX`. Technique standard : on reset à `auto` pour laisser
// le navigateur recalculer `scrollHeight` (sinon il ne diminuerait jamais),
// puis on applique la hauteur mesurée.
function autoGrowInput(input) {
  input.style.height = "auto"
  const target = Math.min(input.scrollHeight, INPUT_MAX_HEIGHT_PX)
  input.style.height = `${target}px`
  // Au-delà du plafond, on active le scroll interne pour que l'utilisateur
  // puisse continuer à écrire sans perdre de vue le haut de son message.
  input.style.overflowY = input.scrollHeight > INPUT_MAX_HEIGHT_PX ? "auto" : "hidden"
}

// Reset complet : suppression côté serveur (si chat existant), purge du DOM,
// purge de la sessionStorage, réaffichage du hint.
async function clearConversation(root, messagesEl, input, clearBtn) {
  const chatId = sessionStorage.getItem("urbanAssistChatId")

  // Si un chat existe côté serveur, on le supprime avant de vider le client.
  // Si la requête échoue (réseau, 404…), on efface quand même côté client :
  // l'utilisateur a demandé un reset, on n'a pas à le lui refuser pour autant.
  if (chatId) {
    const url = buildChatUrl(chatUrlTemplate(root), chatId)
    try {
      await fetch(url, {
        method: "DELETE",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(root)
        }
      })
    } catch (_err) {
      /* échec réseau : on continue le reset côté client */
    }
  }

  sessionStorage.removeItem("urbanAssistChatId")
  messagesEl.innerHTML = ""
  showUsageHint(messagesEl)
  updateClearVisibility(messagesEl, clearBtn)
  input.value = ""
  // Reset de la hauteur auto-grow pour revenir à 1 ligne.
  autoGrowInput(input)
  input.focus()
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
        // NB : l'input a déjà été vidé dès l'envoi dans le handler `submit`
        // du formulaire (UX type ChatGPT). Rien à faire ici.
      } else if (data.type === "error") {
        if (assistantEl) {
          assistantEl.remove()
          assistantEl = null
        }
        appendError(messagesEl, humanErrorMessage(data.code) || data.message)
        // Restauration du brouillon en cas d'erreur : l'utilisateur n'a pas
        // à retaper son message pour retenter.
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
    // Restauration du brouillon en cas d'erreur serveur (l'utilisateur peut retenter).
    input.value = draftText
    return
  }

  if (data.chat_id) sessionStorage.setItem("urbanAssistChatId", String(data.chat_id))
  if (data.assistant_message) appendMessage(messagesEl, data.assistant_message)
  // L'input a déjà été vidé côté `submit` — rien à faire ici en cas de succès.
}

function bindChatbot() {
  const root = getRoot()
  if (!root || root.dataset.chatbotBound === "1") return
  root.dataset.chatbotBound = "1"

  const toggle = document.getElementById("chatbot-toggle")
  const panel = document.getElementById("chatbot-panel")
  const closeBtn = document.getElementById("chatbot-close")
  const clearBtn = document.getElementById("chatbot-clear")
  const form = document.getElementById("chatbot-form")
  const input = document.getElementById("chatbot-input")
  const messagesEl = document.getElementById("chatbot-messages")

  if (!toggle || !panel || !form || !input || !messagesEl) return

  root.removeAttribute("hidden")

  toggle.addEventListener("click", async () => {
    const willOpen = panel.hidden
    setOpen(root, panel, toggle, willOpen)
    if (willOpen) {
      // On attend la fin du chargement de l'historique avant de décider
      // si on affiche le hint : inutile de le montrer si une conversation existe.
      const count = await loadHistory(root, panel, messagesEl)
      if (count === 0) showUsageHint(messagesEl)
      // Actualise la visibilité du bouton "effacer" après chargement.
      updateClearVisibility(messagesEl, clearBtn)
    }
  })

  closeBtn.addEventListener("click", () => {
    setOpen(root, panel, toggle, false)
  })

  if (clearBtn) {
    clearBtn.addEventListener("click", async () => {
      // Action destructive → confirmation. On garde le message court et
      // factuel, en français.
      const confirmed = window.confirm("Effacer la conversation ? Cette action est irréversible.")
      if (!confirmed) return

      clearBtn.disabled = true
      try {
        await clearConversation(root, messagesEl, input, clearBtn)
      } finally {
        clearBtn.disabled = false
      }
    })
  }

  // Envoi via Entrée : comportement attendu pour un chat moderne.
  // Maj+Entrée conserve le retour à la ligne (utile pour les messages longs).
  // `isComposing` évite d'intercepter Entrée pendant la saisie d'accents/IME.
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey && !e.isComposing) {
      e.preventDefault()
      form.requestSubmit()
    }
  })

  // Auto-grow : chaque frappe (ou collage) peut changer la hauteur nécessaire.
  input.addEventListener("input", () => autoGrowInput(input))

  form.addEventListener("submit", async (e) => {
    e.preventDefault()
    const draftText = input.value.trim()
    if (!draftText) return

    // Le hint d'utilisation n'a plus lieu d'être dès le premier envoi.
    removeUsageHint(messagesEl)

    const sendBtn = form.querySelector(".chatbot-widget__send")
    sendBtn.disabled = true

    // Vidage immédiat du textarea : UX attendue d'un chat moderne.
    // Le message est déjà capturé dans `draftText`, et sera restauré par
    // les branches d'erreur ci-dessous si la requête échoue.
    input.value = ""
    // Revenir à la hauteur d'origine (1 ligne) après vidage — sinon la
    // textarea resterait figée à la hauteur du dernier message envoyé.
    autoGrowInput(input)

    const userStub = { role: "user", html: escapeHtml(draftText) }
    appendMessage(messagesEl, userStub)
    // Dès qu'une bulle existe dans la conversation, on expose le bouton
    // "effacer" — inutile de le masquer à nouveau avant un reset explicite.
    updateClearVisibility(messagesEl, clearBtn)

    // Indicateur de chargement : bulle avec 3 points rebondissants (animation
    // CSS). `aria-label` + `role="status"` → annonce vocale pour les lecteurs
    // d'écran (sinon l'animation seule ne leur dit rien).
    const typing = document.createElement("div")
    typing.className = "chatbot-widget__typing"
    typing.setAttribute("role", "status")
    typing.setAttribute("aria-label", "L’assistant rédige une réponse")
    for (let i = 0; i < 3; i += 1) {
      const dot = document.createElement("span")
      dot.className = "chatbot-widget__typing-dot"
      typing.appendChild(dot)
    }
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
      // Restauration du brouillon pour permettre une nouvelle tentative.
      input.value = draftText
    } finally {
      sendBtn.disabled = false
      // Recalcul de la hauteur : sur succès (textarea vide) on revient à 1 ligne ;
      // sur erreur (brouillon restauré) on s'ajuste au contenu restauré.
      autoGrowInput(input)
      // Re-focus : l'utilisateur peut enchaîner sans reprendre la souris.
      // On ne le fait que si le panneau est toujours ouvert (pas fermé entre-temps).
      if (!panel.hidden) input.focus()
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

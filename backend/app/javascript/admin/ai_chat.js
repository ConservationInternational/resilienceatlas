// AI Chat panel for ActiveAdmin — communicates with Admin::AiChatController
// Injected by the ai_chat ActiveAdmin page partial.

(function () {
  'use strict';

  function initAiChat() {
    const meta = window.aiChatMeta;
    if (!meta) return; // Only active on the AI Chat page

    const messages = document.getElementById('ai-chat-messages');
    const input = document.getElementById('ai-chat-input');
    const sendBtn = document.getElementById('ai-chat-send');
    const resetBtn = document.getElementById('ai-chat-reset');

    if (!messages || !input || !sendBtn || !resetBtn) return;

    function appendBubble(text, role) {
      const bubble = document.createElement('div');
      bubble.className = 'ai-chat-bubble ' + role;
      bubble.textContent = text;
      messages.appendChild(bubble);
      messages.scrollTop = messages.scrollHeight;
      return bubble;
    }

    function setLoading(loading) {
      sendBtn.disabled = loading;
      input.disabled = loading;
    }

    async function sendMessage() {
      const text = input.value.trim();
      if (!text) return;

      appendBubble(text, 'user');
      input.value = '';
      setLoading(true);

      const thinkingBubble = appendBubble('Thinking…', 'agent');

      try {
        const res = await fetch(meta.messageUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': meta.csrfToken,
          },
          body: JSON.stringify({ message: text }),
        });
        const data = await res.json();
        thinkingBubble.remove();
        if (data.success) {
          appendBubble(data.message, 'agent');
        } else {
          appendBubble('Error: ' + data.message, 'error');
        }
      } catch (err) {
        thinkingBubble.remove();
        appendBubble('Network error. Please try again.', 'error');
      } finally {
        setLoading(false);
        input.focus();
      }
    }

    sendBtn.addEventListener('click', sendMessage);

    input.addEventListener('keydown', function (e) {
      // Ctrl+Enter or Cmd+Enter to send
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        sendMessage();
      }
    });

    resetBtn.addEventListener('click', async function () {
      try {
        await fetch(meta.resetUrl, {
          method: 'POST',
          headers: { 'X-CSRF-Token': meta.csrfToken },
        });
      } catch (_) {
        // ignore
      }
      messages.innerHTML = '';
      appendBubble('Conversation reset. How can I help you?', 'agent');
    });

    // Welcome message
    appendBubble('Hello! I can help you create and configure Resilience Atlas layers. Describe what you need and I\'ll set it up.', 'agent');
  }

  // Run after DOM is ready (works with Turbolinks / standard load)
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAiChat);
  } else {
    initAiChat();
  }
})();

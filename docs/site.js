'use strict';
const button = document.getElementById('copy-prompt');
const prompt = document.getElementById('install-prompt');
const status = document.getElementById('copy-status');
button.addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText(prompt.value);
    status.textContent = 'Copied. Paste it into ChatGPT/Codex on your Mac.';
    button.textContent = 'Prompt copied ✓';
  } catch {
    prompt.focus();
    prompt.select();
    status.textContent = 'Select the prompt above and press Command+C to copy.';
  }
});

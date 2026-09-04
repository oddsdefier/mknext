import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const hooksPath = process.argv[2];
if (!hooksPath) {
  console.error('Usage: node merge-codex-hooks.mjs <path-to-hooks.json>');
  process.exit(1);
}

let data = { hooks: {} };
if (existsSync(hooksPath)) {
  try {
    const raw = await readFile(hooksPath, 'utf8');
    data = JSON.parse(raw);
  } catch {
    data = { hooks: {} };
  }
}

data.hooks = data.hooks || {};

// SessionStart
data.hooks.SessionStart = Array.isArray(data.hooks.SessionStart) ? data.hooks.SessionStart : [];
const hasSessionStart = data.hooks.SessionStart.some((entry) =>
  (entry.hooks || []).some((h) => h.command?.includes('validate-production-env-guard.sh'))
);
if (!hasSessionStart) {
  data.hooks.SessionStart.push({
    hooks: [
      {
        type: 'command',
        command: './.codex/hooks/validate-production-env-guard.sh',
      },
    ],
  });
}

// PreToolUse
data.hooks.PreToolUse = Array.isArray(data.hooks.PreToolUse) ? data.hooks.PreToolUse : [];
const hasPreToolUse = data.hooks.PreToolUse.some((entry) =>
  (entry.hooks || []).some((h) => h.command?.includes('block-production-env-read.sh'))
);
if (!hasPreToolUse) {
  data.hooks.PreToolUse.push({
    matcher: 'Read|read_file|view_file|file_read|cat|shell_command|exec_command',
    hooks: [
      {
        type: 'command',
        command: './.codex/hooks/block-production-env-read.sh',
      },
    ],
  });
}

await writeFile(hooksPath, `${JSON.stringify(data, null, 2)}\n`);

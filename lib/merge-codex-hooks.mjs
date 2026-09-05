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
  } catch (error) {
    console.error(`Cannot parse ${hooksPath}: ${error.message}`);
    process.exit(1);
  }
}

data.hooks = data.hooks || {};

// SessionStart
data.hooks.SessionStart = Array.isArray(data.hooks.SessionStart) ? data.hooks.SessionStart : [];
const validateCommand = './.codex/hooks/validate-production-env-guard.sh';
const guardCommand = './.codex/hooks/block-production-env-read.sh';
const hasSessionStart = data.hooks.SessionStart.some((entry) =>
  (entry.hooks || []).some((h) => h.type === 'command' && h.command === validateCommand)
);
if (!hasSessionStart) {
  data.hooks.SessionStart.push({
    hooks: [
      {
        type: 'command',
        command: validateCommand,
      },
    ],
  });
}

// PreToolUse
const preToolMatcher = 'Read|read_file|view_file|file_read|cat|shell_command|exec_command';
data.hooks.PreToolUse = Array.isArray(data.hooks.PreToolUse) ? data.hooks.PreToolUse : [];
const hasPreToolUse = data.hooks.PreToolUse.some((entry) =>
  entry.matcher === preToolMatcher &&
  (entry.hooks || []).some((h) => h.type === 'command' && h.command === guardCommand)
);
if (!hasPreToolUse) {
  data.hooks.PreToolUse.push({
    matcher: preToolMatcher,
    hooks: [
      {
        type: 'command',
        command: guardCommand,
      },
    ],
  });
}

await writeFile(hooksPath, `${JSON.stringify(data, null, 2)}\n`);

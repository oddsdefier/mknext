import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const settingsPath = process.argv[2];
if (!settingsPath) {
  console.error('Usage: node merge-claude-settings.mjs <path-to-settings.local.json>');
  process.exit(1);
}

let settings = {};
if (existsSync(settingsPath)) {
  try {
    const raw = await readFile(settingsPath, 'utf8');
    settings = JSON.parse(raw);
  } catch {
    settings = {};
  }
}

if (!settings.$schema) {
  settings.$schema = 'https://json.schemastore.org/claude-code-settings.json';
}

// 0. Attribution settings
settings.attribution = settings.attribution || {};
settings.attribution.commit = '';
settings.attribution.pr = '';

// 1. Permissions deny
settings.permissions = settings.permissions || {};
const existingDeny = Array.isArray(settings.permissions.deny) ? settings.permissions.deny : [];
const denyRules = [
  'Read(**/.env.production.local)',
  'Read(**/.env.prod.local)',
  'Read(**/production.local.env)',
  'Read(**/prod.local.env)',
];
for (const rule of denyRules) {
  if (!existingDeny.includes(rule)) {
    existingDeny.push(rule);
  }
}
settings.permissions.deny = existingDeny;

// 2. Hooks
settings.hooks = settings.hooks || {};

// SessionStart hook
settings.hooks.SessionStart = Array.isArray(settings.hooks.SessionStart) ? settings.hooks.SessionStart : [];
const hasSessionStart = settings.hooks.SessionStart.some((entry) =>
  (entry.hooks || []).some((h) => h.command?.includes('validate-production-env-guard.sh'))
);
if (!hasSessionStart) {
  settings.hooks.SessionStart.push({
    hooks: [
      {
        type: 'command',
        command: '${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-production-env-guard.sh',
      },
    ],
  });
}

// ConfigChange hook
settings.hooks.ConfigChange = Array.isArray(settings.hooks.ConfigChange) ? settings.hooks.ConfigChange : [];
const hasConfigChange = settings.hooks.ConfigChange.some((entry) =>
  (entry.hooks || []).some((h) => h.command?.includes('validate-production-env-guard.sh'))
);
if (!hasConfigChange) {
  settings.hooks.ConfigChange.push({
    matcher: 'user_settings|project_settings|local_settings',
    hooks: [
      {
        type: 'command',
        command: '${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-production-env-guard.sh',
      },
    ],
  });
}

// PreToolUse hook
settings.hooks.PreToolUse = Array.isArray(settings.hooks.PreToolUse) ? settings.hooks.PreToolUse : [];
const hasPreToolUse = settings.hooks.PreToolUse.some((entry) =>
  (entry.hooks || []).some((h) => h.command?.includes('block-production-env-read.sh'))
);
if (!hasPreToolUse) {
  settings.hooks.PreToolUse.push({
    matcher: 'Read',
    hooks: [
      {
        type: 'command',
        command: '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-production-env-read.sh',
      },
    ],
  });
}

// 3. Sandbox filesystem denyRead
settings.sandbox = settings.sandbox || {};
if (settings.sandbox.enabled === undefined) settings.sandbox.enabled = true;
if (settings.sandbox.failIfUnavailable === undefined) settings.sandbox.failIfUnavailable = true;
if (settings.sandbox.allowUnsandboxedCommands === undefined) settings.sandbox.allowUnsandboxedCommands = false;
settings.sandbox.filesystem = settings.sandbox.filesystem || {};
const existingSandboxDeny = Array.isArray(settings.sandbox.filesystem.denyRead)
  ? settings.sandbox.filesystem.denyRead
  : [];
const sandboxDenyRules = [
  './**/.env.production.local',
  './**/.env.prod.local',
  './**/production.local.env',
  './**/prod.local.env',
];
for (const rule of sandboxDenyRules) {
  if (!existingSandboxDeny.includes(rule)) {
    existingSandboxDeny.push(rule);
  }
}
settings.sandbox.filesystem.denyRead = existingSandboxDeny;

await writeFile(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);

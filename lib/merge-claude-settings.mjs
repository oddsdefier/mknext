import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const settingsPath = process.argv[2];
if (!settingsPath) {
  console.error('Usage: node merge-claude-settings.mjs <path-to-settings.local.json>');
  process.exit(1);
}

const projectDir = resolve(dirname(settingsPath), '..');
const protectedNames = [
  '.env.production.local',
  '.env.prod.local',
  'production.local.env',
  'prod.local.env',
];
const absoluteProjectPath = projectDir.replace(/^\/+/, '');

let settings = {};
if (existsSync(settingsPath)) {
  try {
    const raw = await readFile(settingsPath, 'utf8');
    settings = JSON.parse(raw);
  } catch (error) {
    console.error(`Cannot parse ${settingsPath}: ${error.message}`);
    process.exit(1);
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
const legacyDenyRules = protectedNames.map((name) => `Read(**/${name})`);
const existingDeny = (Array.isArray(settings.permissions.deny) ? settings.permissions.deny : [])
  .filter((rule) => !legacyDenyRules.includes(rule));
const denyRules = protectedNames.map((name) => `Read(//${absoluteProjectPath}/${name})`);
for (const rule of denyRules) {
  if (!existingDeny.includes(rule)) {
    existingDeny.push(rule);
  }
}
settings.permissions.deny = existingDeny;

// 2. Hooks
settings.hooks = settings.hooks || {};
const validateCommand = '${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-production-env-guard.sh';
const guardCommand = '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-production-env-read.sh';
const attributionCommand = '${CLAUDE_PROJECT_DIR}/.claude/hooks/block-ai-pr-attribution.sh';

settings.hooks.SessionStart = Array.isArray(settings.hooks.SessionStart) ? settings.hooks.SessionStart : [];
if (!settings.hooks.SessionStart.some((entry) =>
  (entry.hooks || []).some((hook) => hook.type === 'command' && hook.command === validateCommand)
)) {
  settings.hooks.SessionStart.push({ hooks: [{ type: 'command', command: validateCommand }] });
}

settings.hooks.ConfigChange = Array.isArray(settings.hooks.ConfigChange) ? settings.hooks.ConfigChange : [];
if (!settings.hooks.ConfigChange.some((entry) =>
  entry.matcher === 'user_settings|project_settings|local_settings' &&
  (entry.hooks || []).some((hook) => hook.type === 'command' && hook.command === validateCommand)
)) {
  settings.hooks.ConfigChange.push({
    matcher: 'user_settings|project_settings|local_settings',
    hooks: [{ type: 'command', command: validateCommand }],
  });
}

settings.hooks.PreToolUse = Array.isArray(settings.hooks.PreToolUse) ? settings.hooks.PreToolUse : [];
if (!settings.hooks.PreToolUse.some((entry) =>
  entry.matcher === 'Read' &&
  (entry.hooks || []).some((hook) => hook.type === 'command' && hook.command === guardCommand)
)) {
  settings.hooks.PreToolUse.push({
    matcher: 'Read',
    hooks: [{ type: 'command', command: guardCommand }],
  });
}
if (!settings.hooks.PreToolUse.some((entry) =>
  entry.matcher === 'Bash' &&
  (entry.hooks || []).some((hook) => hook.type === 'command' && hook.command === attributionCommand)
)) {
  settings.hooks.PreToolUse.push({
    matcher: 'Bash',
    hooks: [{ type: 'command', command: attributionCommand }],
  });
}

// 3. Sandbox filesystem denyRead
settings.sandbox = settings.sandbox || {};
if (settings.sandbox.enabled === undefined) settings.sandbox.enabled = true;
if (settings.sandbox.failIfUnavailable === undefined) settings.sandbox.failIfUnavailable = true;
if (settings.sandbox.allowUnsandboxedCommands === undefined) settings.sandbox.allowUnsandboxedCommands = false;
settings.sandbox.filesystem = settings.sandbox.filesystem || {};
const legacySandboxDenyRules = protectedNames.map((name) => `./**/${name}`);
const existingSandboxDeny = (Array.isArray(settings.sandbox.filesystem.denyRead)
  ? settings.sandbox.filesystem.denyRead
  : [])
  .filter((rule) => !legacySandboxDenyRules.includes(rule));
const sandboxDenyRules = protectedNames.map((name) => `${projectDir}/${name}`);
for (const rule of sandboxDenyRules) {
  if (!existingSandboxDeny.includes(rule)) {
    existingSandboxDeny.push(rule);
  }
}
settings.sandbox.filesystem.denyRead = existingSandboxDeny;

await writeFile(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);

import { cp, lstat, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const [directory, rootDirectory, dryRun] = process.argv.slice(2);
const legacyConfig =
  /^(?:eslint\.config\.(?:[cm]?[jt]s)|\.eslintrc(?:\.(?:[cm]?js|json|ya?ml))?|prettier\.config\.(?:[cm]?[jt]s)|\.prettierrc(?:\.(?:[cm]?[jt]s|json5?|ya?ml|toml))?)$/;
const legacyDependency =
  /^(?:eslint(?:$|-)|typescript-eslint$|@(?:eslint|eslint-community|typescript-eslint|prettier)\/|@types\/eslint(?:$|-)|prettier(?:$|-)|@[^/]+\/(?:eslint(?:$|-)|prettier(?:$|-)))/;
const groups = ['dependencies', 'devDependencies', 'optionalDependencies'];
let packageManager = 'pnpm';

async function exists(file) {
  try {
    await lstat(path.join(directory, file));
    return true;
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    return false;
  }
}

async function assertLocal(file) {
  let current = directory;
  for (const segment of file.split('/')) {
    current = path.join(current, segment);
    try {
      if ((await lstat(current)).isSymbolicLink()) {
        throw new Error(`migration refuses symbolic link: ${file}`);
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
}

function run(...args) {
  const commandArgs =
    packageManager === 'npm'
      ? args[0] === 'install'
        ? ['install', '--include=dev']
        : ['exec', '--yes=false', '--', ...args.slice(1)]
      : args;
  const result = spawnSync(packageManager, commandArgs, { cwd: directory, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${packageManager} ${commandArgs.join(' ')} failed`);
}

function migrateCommand(command, staged = false) {
  return command
    .split(/(\s*(?:&&|\|\||;)\s*)/)
    .map((part) => {
      const match = part.match(
        /^(\s*)(?:(?:npx|pnpm exec|npm exec --|yarn exec)\s+)?(eslint|next lint|prettier)(?:\s|$)/,
      );
      if (!match) return part;
      const tool =
        match[2] === 'prettier'
          ? `oxfmt ${/(?:^|\s)(?:--check|-c)(?:\s|$)/.test(part) ? '--check' : '--write'}`
          : `oxlint${/(?:^|\s)--fix(?:\s|$)/.test(part) ? ' --fix' : ''}`;
      return `${match[1]}${tool}${staged ? '' : ' .'}`;
    })
    .join('');
}

async function migrate() {
  if (directory === rootDirectory || directory.startsWith(`${rootDirectory}${path.sep}`)) {
    throw new Error('cannot migrate the mknext installation');
  }
  await assertLocal('package.json');
  const original = JSON.parse(await readFile(path.join(directory, 'package.json'), 'utf8'));
  const names = await readdir(directory);
  if (original.packageManager) packageManager = original.packageManager.split('@')[0];
  else if (names.includes('pnpm-lock.yaml')) packageManager = 'pnpm';
  else if (names.some((name) => ['package-lock.json', 'npm-shrinkwrap.json'].includes(name)))
    packageManager = 'npm';
  else if (names.some((name) => ['yarn.lock', 'bun.lock', 'bun.lockb'].includes(name)))
    packageManager = 'unsupported';
  if (!['pnpm', 'npm'].includes(packageManager)) {
    throw new Error('migration supports npm and pnpm; keep other package managers unchanged');
  }
  const oldConfigs = names.filter((name) => legacyConfig.test(name));
  const hasOxlint = names.some((name) =>
    /^(?:\.oxlintrc\.jsonc?|oxlint\.config\.[cm]?[jt]s)$/.test(name),
  );
  const hasOxfmt = names.some((name) =>
    /^(?:\.oxfmtrc\.(?:jsonc?|[cm]?[jt]s)|oxfmt\.config\.[cm]?[jt]s)$/.test(name),
  );
  const hasPrettier =
    oldConfigs.some((name) => name.includes('prettier')) || original.prettier !== undefined;
  const hasComplexity =
    !hasOxlint ||
    (await exists('oxlint.config.ts')) ||
    (await exists('oxlint.complexity.config.ts'));
  const data = structuredClone(original);
  for (const group of groups) {
    for (const name of Object.keys(data[group] ?? {})) {
      if (legacyDependency.test(name) || ['oxlint', '@oxlint/plugins', 'oxfmt'].includes(name)) {
        delete data[group][name];
      }
    }
  }
  if (packageManager === 'pnpm' && !data.packageManager)
    data.packageManager = `pnpm@${process.env.PNPM_VERSION}`;
  data.devDependencies = {
    ...data.devDependencies,
    '@oxlint/plugins': process.env.OXlint_PLUGINS_VERSION,
    oxlint: process.env.OXlint_VERSION,
    oxfmt: process.env.OXFMT_VERSION,
  };
  data.scripts = Object.fromEntries(
    Object.entries(data.scripts ?? {}).map(([name, command]) => [name, migrateCommand(command)]),
  );
  Object.assign(data.scripts, {
    lint: 'oxlint .',
    format: 'oxfmt --check .',
    'format:write': 'oxfmt --write .',
  });
  if (hasComplexity) data.scripts['lint:complexity'] = 'oxlint -c oxlint.complexity.config.ts .';
  for (const [pattern, commands] of Object.entries(data['lint-staged'] ?? {})) {
    data['lint-staged'][pattern] = Array.isArray(commands)
      ? commands.map((command) => migrateCommand(command, true))
      : migrateCommand(commands, true);
  }
  delete data.eslintConfig;
  delete data.prettier;
  if (
    hasOxlint &&
    hasOxfmt &&
    oldConfigs.length === 0 &&
    JSON.stringify(data) === JSON.stringify(original)
  ) {
    console.log('Lint and format tools are already migrated.');
    return;
  }
  if (dryRun === '1') {
    console.log(
      'DRY RUN migrate: back up configs, replace ESLint/Prettier, install pinned Oxlint/Oxfmt',
    );
    return;
  }
  const otherLocks = [
    'package-lock.json',
    'npm-shrinkwrap.json',
    'yarn.lock',
    'bun.lock',
    'bun.lockb',
  ];
  const newFiles = [
    ...(!hasOxlint ? ['oxlint.config.ts', 'tools/oxlint/anti-slop'] : []),
    ...(hasComplexity ? ['oxlint.complexity.config.ts'] : []),
    ...(!hasOxfmt ? ['.oxfmtrc.json'] : []),
  ];
  const files = [
    ...new Set([
      'package.json',
      'pnpm-lock.yaml',
      '.gitignore',
      ...otherLocks,
      ...oldConfigs,
      ...newFiles,
    ]),
  ];
  for (const file of [...files, '.mknext-migrate-backups']) await assertLocal(file);
  const backupRoot = path.join(directory, '.mknext-migrate-backups');
  await mkdir(backupRoot, { recursive: true });
  const backup = await mkdtemp(path.join(backupRoot, 'migration-'));
  const previous = new Map();
  for (const file of files) {
    previous.set(file, await exists(file));
    if (previous.get(file)) {
      await mkdir(path.dirname(path.join(backup, file)), { recursive: true });
      await cp(path.join(directory, file), path.join(backup, file), { recursive: true });
    }
  }
  try {
    const gitignore = (await exists('.gitignore'))
      ? await readFile(path.join(directory, '.gitignore'), 'utf8')
      : '';
    const ignored = ['/.mknext-migrate-backups/', '/node_modules/'].filter(
      (pattern) => !gitignore.split('\n').includes(pattern),
    );
    if (ignored.length > 0) {
      await writeFile(
        path.join(directory, '.gitignore'),
        `${gitignore}${gitignore.endsWith('\n') || !gitignore ? '' : '\n'}${ignored.join('\n')}\n`,
      );
    }
    const tools = {
      ...original,
      packageManager: data.packageManager,
      devDependencies: {
        ...original.devDependencies,
        ...Object.fromEntries(
          ['oxlint', '@oxlint/plugins', 'oxfmt'].map((name) => [name, data.devDependencies[name]]),
        ),
      },
    };
    await writeFile(path.join(directory, 'package.json'), `${JSON.stringify(tools, null, 2)}\n`);
    run('install', '--no-frozen-lockfile', '--no-prod');
    if (!hasOxfmt) {
      if (hasPrettier) {
        run('exec', 'oxfmt', '--migrate=prettier');
        if (!(await exists('.oxfmtrc.json')))
          throw new Error('Oxfmt did not create its configuration');
      } else {
        const formatter = JSON.parse(
          await readFile(path.join(rootDirectory, 'templates/.oxfmtrc.json'), 'utf8'),
        );
        if (await exists('src/app/globals.css'))
          formatter.sortTailwindcss.stylesheet = './src/app/globals.css';
        else if (!(await exists('app/globals.css'))) delete formatter.sortTailwindcss;
        await writeFile(
          path.join(directory, '.oxfmtrc.json'),
          `${JSON.stringify(formatter, null, 2)}\n`,
        );
      }
    }
    if (!hasOxlint) {
      await cp(
        path.join(rootDirectory, 'templates/oxlint.config.ts'),
        path.join(directory, 'oxlint.config.ts'),
      );
      if (!(await exists('tools/oxlint/anti-slop'))) {
        await mkdir(path.join(directory, 'tools/oxlint'), { recursive: true });
        await cp(
          path.join(rootDirectory, 'templates/tools/oxlint/anti-slop'),
          path.join(directory, 'tools/oxlint/anti-slop'),
          { recursive: true },
        );
      }
    }
    if (hasComplexity && !(await exists('oxlint.complexity.config.ts'))) {
      await cp(
        path.join(rootDirectory, 'templates/oxlint.complexity.config.ts'),
        path.join(directory, 'oxlint.complexity.config.ts'),
      );
    }
    for (const file of oldConfigs) await rm(path.join(directory, file), { force: true });
    await writeFile(path.join(directory, 'package.json'), `${JSON.stringify(data, null, 2)}\n`);
    run('install', '--no-frozen-lockfile', '--no-prod');
    const createdConfigs = newFiles.filter((file) => !previous.get(file));
    run('exec', 'oxfmt', '--write', 'package.json', ...createdConfigs);
    console.log(`Migrated ESLint and Prettier to Oxlint and Oxfmt. Backup: ${backup}`);
    console.log('Review custom ESLint rules in the backup before removing it.');
  } catch (error) {
    for (const [file, existed] of previous) {
      await assertLocal(file);
      await rm(path.join(directory, file), { recursive: true, force: true });
      if (existed) {
        await mkdir(path.dirname(path.join(directory, file)), { recursive: true });
        await cp(path.join(backup, file), path.join(directory, file), { recursive: true });
      }
    }
    throw new Error(
      `${error.message}; restored project files from ${backup}. Reinstall original dependencies if needed.`,
    );
  }
}

try {
  await migrate();
} catch (error) {
  console.error(`mknext: ${error.message}`);
  process.exitCode = 1;
}

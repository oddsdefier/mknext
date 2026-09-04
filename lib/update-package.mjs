import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const appDirectory = process.argv[2];
const packageManagerOnly = process.argv[3] === '--package-manager-only';
const packageFile = path.join(appDirectory, 'package.json');
const packageData = JSON.parse(await readFile(packageFile, 'utf8'));

packageData.private = true;
packageData.type = 'module';
packageData.packageManager = `pnpm@${process.env.PNPM_VERSION}`;
for (const dependency of ['eslint', 'eslint-config-next', 'prettier', 'prettier-plugin-tailwindcss']) {
  delete packageData.dependencies?.[dependency];
  delete packageData.devDependencies?.[dependency];
}
if (!packageManagerOnly) {
  packageData.scripts = {
    dev: 'next dev',
    build: 'next build',
    start: 'next start',
    lint: 'oxlint .',
    'lint:complexity': 'oxlint -c oxlint.complexity.config.ts .',
    format: 'oxfmt --check .',
    'format:write': 'oxfmt --write .',
    typecheck: 'next typegen && tsc --noEmit',
    test: 'vitest',
    'test:run': 'vitest run',
    doctor: 'react-doctor --no-score --blocking error',
    knip: 'knip',
    audit: 'pnpm audit',
    secrets: 'gitleaks git --redact .',
    ci: 'mknext ci',
    prepare: 'husky',
  };
  packageData.dependencies = {
    ...(packageData.dependencies ?? {}),
    'class-variance-authority': process.env.CVA_VERSION,
    clsx: process.env.CLSX_VERSION,
    next: process.env.NEXT_VERSION,
    react: process.env.REACT_VERSION,
    'react-dom': process.env.REACT_DOM_VERSION,
    'tailwind-merge': process.env.TAILWIND_MERGE_VERSION,
  };
  packageData.devDependencies = {
    ...(packageData.devDependencies ?? {}),
    '@changesets/cli': process.env.CHANGESETS_VERSION,
    '@oxlint/plugins': process.env.OXlint_PLUGINS_VERSION,
    '@tailwindcss/postcss': process.env.TAILWIND_POSTCSS_VERSION,
    '@types/node': process.env.TYPES_NODE_VERSION,
    '@types/react': process.env.TYPES_REACT_VERSION,
    '@types/react-dom': process.env.TYPES_REACT_DOM_VERSION,
    '@vitejs/plugin-react': process.env.VITE_REACT_VERSION,
    'babel-plugin-react-compiler': process.env.REACT_COMPILER_VERSION,
    husky: process.env.HUSKY_VERSION,
    jsdom: process.env.JSDOM_VERSION,
    knip: process.env.KNIP_VERSION,
    'lint-staged': process.env.LINT_STAGED_VERSION,
    oxfmt: process.env.OXFMT_VERSION,
    oxlint: process.env.OXlint_VERSION,
    'react-doctor': process.env.REACT_DOCTOR_VERSION,
    tailwindcss: process.env.TAILWIND_VERSION,
    typescript: process.env.TYPESCRIPT_VERSION,
    vitest: process.env.VITEST_VERSION,
  };
  packageData['lint-staged'] = {
    '*.{js,jsx,ts,tsx,json,css,md}': 'oxfmt --write',
  };
}

await writeFile(packageFile, `${JSON.stringify(packageData, null, 2)}\n`);

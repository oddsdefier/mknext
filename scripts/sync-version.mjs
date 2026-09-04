import { readFile, writeFile } from 'node:fs/promises';

const packageData = JSON.parse(await readFile('package.json', 'utf8'));

if (typeof packageData.version !== 'string' || packageData.version.length === 0) {
  throw new Error('package.json has no version');
}

await writeFile('VERSION', `${packageData.version}\n`);

#!/usr/bin/env node

const { spawnSync } = require('child_process');
const path = require('path');

const scriptDir = __dirname;
const args = process.argv.slice(2);
const isWindows = process.platform === 'win32';
const script = path.join(scriptDir, isWindows ? 'notify.ps1' : 'notify.sh');
const commandArgs = isWindows
  ? ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, ...args]
  : [script, ...args];
const command = isWindows ? 'powershell' : 'sh';

const result = spawnSync(command, commandArgs, { stdio: 'inherit' });

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 0);

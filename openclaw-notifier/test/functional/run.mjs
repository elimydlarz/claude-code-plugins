import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { startServer } from './capture-server.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const NOTIFY_SH = resolve(__dirname, '../../scripts/notify.sh');

let passed = 0;
let failed = 0;

function assert(name, condition) {
  if (condition) {
    console.log(`  \u2713 ${name}`);
    passed++;
  } else {
    console.log(`  \u2717 ${name}`);
    failed++;
  }
}

function run(env, stdin = '{}') {
  return new Promise((resolve) => {
    const child = spawn('bash', [NOTIFY_SH], {
      env: { PATH: process.env.PATH, HOME: process.env.HOME, ...env },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.stdin.write(stdin);
    child.stdin.end();
    const timer = setTimeout(() => { child.kill(); resolve({ exitCode: 1, stdout, stderr: stderr + '\n(timeout)' }); }, 10000);
    child.on('close', (code) => { clearTimeout(timer); resolve({ exitCode: code, stdout, stderr }); });
  });
}

// -- Tests --

console.log('SubagentNotification');

console.log('  when OPENCLAW_URL is set and a subagent completes');
{
  const srv = await startServer();
  const payload = JSON.stringify({ session_id: 'abc-123', transcript_path: '/tmp/t.jsonl' });
  const result = await run({ OPENCLAW_URL: srv.url }, payload);

  assert('then POSTs the SubagentStop payload to /api/subagent-complete', srv.requests.length === 1 && srv.requests[0].url === '/api/subagent-complete');
  assert('and sends the payload as JSON body', srv.requests[0]?.body === payload);
  assert('and sends Content-Type application/json', srv.requests[0]?.headers['content-type'] === 'application/json');
  assert('and exits 0', result.exitCode === 0);
  await srv.close();
}

console.log('  when OPENCLAW_URL is not set');
{
  const srv = await startServer();
  const result = await run({});
  assert('then exits 0 without making any HTTP request', result.exitCode === 0 && srv.requests.length === 0);
  await srv.close();
}

console.log('  when OPENCLAW_TOKEN is set');
{
  const srv = await startServer();
  await run({ OPENCLAW_URL: srv.url, OPENCLAW_TOKEN: 'secret-token' });
  assert('then includes Authorization Bearer header', srv.requests[0]?.headers['authorization'] === 'Bearer secret-token');
  await srv.close();
}

console.log('  when OPENCLAW_TOKEN is not set');
{
  const srv = await startServer();
  await run({ OPENCLAW_URL: srv.url });
  assert('then sends the request without an Authorization header', srv.requests[0]?.headers['authorization'] === undefined);
  await srv.close();
}

console.log('  when the server returns a non-2xx status');
{
  const srv = await startServer({ statusCode: 503 });
  const result = await run({ OPENCLAW_URL: srv.url });
  assert('then logs the status code to stderr', result.stderr.includes('503'));
  assert('and exits 0', result.exitCode === 0);
  await srv.close();
}

console.log('  when the HTTP request fails (connection refused)');
{
  const result = await run({ OPENCLAW_URL: 'http://127.0.0.1:1' });
  assert('then exits 0', result.exitCode === 0);
}

// -- Summary --
console.log(`\n${passed + failed} tests, ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

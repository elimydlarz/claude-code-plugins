import { createServer } from 'node:http';

export function startServer({ statusCode = 200, port = 0 } = {}) {
  const requests = [];

  const server = createServer((req, res) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      requests.push({
        method: req.method,
        url: req.url,
        headers: req.headers,
        body,
      });
      res.writeHead(statusCode);
      res.end();
    });
  });

  return new Promise((resolve) => {
    server.listen(port, () => {
      const { port: assignedPort } = server.address();
      resolve({
        port: assignedPort,
        url: `http://127.0.0.1:${assignedPort}`,
        requests,
        close: () => new Promise((r) => server.close(r)),
      });
    });
  });
}

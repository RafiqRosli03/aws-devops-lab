"use strict";

// Unit tests using Node's built-in test runner (node --test) + supertest-free
// approach via the app's request handler through http.
const test = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const { createApp } = require("../src/app");

// Helper: start the app on an ephemeral port, run a request, return {status, body}.
function request(method, path, payload) {
  return new Promise((resolve, reject) => {
    const server = createApp().listen(0, () => {
      const { port } = server.address();
      const data = payload ? JSON.stringify(payload) : null;
      const req = http.request(
        {
          host: "127.0.0.1",
          port,
          method,
          path,
          headers: data
            ? { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data) }
            : {},
        },
        (res) => {
          let body = "";
          res.on("data", (c) => (body += c));
          res.on("end", () => {
            server.close();
            resolve({ status: res.statusCode, body: body ? JSON.parse(body) : null });
          });
        }
      );
      req.on("error", (e) => {
        server.close();
        reject(e);
      });
      if (data) req.write(data);
      req.end();
    });
  });
}

test("GET /health returns ok", async () => {
  const res = await request("GET", "/health");
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(res.body, { status: "ok" });
});

test("GET /orders returns a list", async () => {
  const res = await request("GET", "/orders");
  assert.strictEqual(res.status, 200);
  assert.ok(Array.isArray(res.body));
  assert.ok(res.body.length >= 1);
});

test("POST /orders creates an order", async () => {
  const res = await request("POST", "/orders", { item: "mouse", qty: 3 });
  assert.strictEqual(res.status, 201);
  assert.strictEqual(res.body.item, "mouse");
  assert.strictEqual(res.body.qty, 3);
  assert.ok(Number.isInteger(res.body.id));
});

test("POST /orders rejects invalid input", async () => {
  const res = await request("POST", "/orders", { item: "", qty: -1 });
  assert.strictEqual(res.status, 400);
  assert.ok(res.body.error);
});

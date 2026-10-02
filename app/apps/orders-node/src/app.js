"use strict";

// Express app factory. Kept separate from the server (index.js) so tests can
// import the app without opening a network port.
const express = require("express");

const path = require("path");

function createApp() {
  const app = express();
  app.use(express.json());

  // Serve the GUI (static landing page) from /public at the root.
  app.use(express.static(path.join(__dirname, "..", "public")));

  // In-memory data store (lab only - resets on restart).
  const orders = [
    { id: 1, item: "keyboard", qty: 2 },
    { id: 2, item: "monitor", qty: 1 },
  ];
  let nextId = 3;

  // Health check - used by Kubernetes liveness/readiness probes later.
  app.get("/health", (_req, res) => {
    res.status(200).json({ status: "ok" });
  });

  // List all orders.
  app.get("/orders", (_req, res) => {
    res.status(200).json(orders);
  });

  // Create an order.
  app.post("/orders", (req, res) => {
    const { item, qty } = req.body || {};
    if (typeof item !== "string" || !Number.isInteger(qty) || qty <= 0) {
      return res
        .status(400)
        .json({ error: "item (string) and qty (positive integer) are required" });
    }
    const order = { id: nextId++, item, qty };
    orders.push(order);
    res.status(201).json(order);
  });

  return app;
}

module.exports = { createApp };

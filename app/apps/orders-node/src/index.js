"use strict";

// Server entry point. Reads the port from an env var (12-factor config).
// Phase 3 CI/CD trigger: pipeline smoke test (v4 - path-filter proof, orders only).
const { createApp } = require("./app");

const port = parseInt(process.env.PORT, 10) || 3000;
const app = createApp();

app.listen(port, () => {
  // Log to stdout - containers capture stdout.
  console.log(`orders-node listening on port ${port}`);
});

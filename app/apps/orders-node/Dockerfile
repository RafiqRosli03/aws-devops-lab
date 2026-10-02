# ---- Stage 1: build + test ----
FROM node:20-slim AS build
WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm install --omit=dev && cp -R node_modules /prod_node_modules && npm install

# Copy source and run tests at build time (fail fast)
COPY . .
RUN npm test

# ---- Stage 2: runtime (small, non-root) ----
FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Copy only production deps and source from the build stage
COPY --from=build /prod_node_modules ./node_modules
COPY --from=build /app/src ./src
COPY --from=build /app/public ./public
COPY --from=build /app/package.json ./

# Run as the built-in non-root "node" user
USER node

EXPOSE 3000
CMD ["node", "src/index.js"]

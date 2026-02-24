#!/bin/bash

# Dokploy Deployment Script for GitHub Codespaces
# This script clones the Dokploy repository and sets it up

set -e

echo "========================================="
echo "Dokploy Deployment on GitHub Codespaces"
echo "========================================="
echo

# Check if running in GitHub Codespaces
if [ -z "$CODESPACES" ]; then
    echo "Error: This script is intended to run in GitHub Codespaces"
    exit 1
fi

# Clone Dokploy repository if not already present
if [ ! -d "dokploy" ]; then
    echo "Step 1: Cloning Dokploy repository..."
    git clone https://github.com/Dokploy/dokploy.git dokploy
    cd dokploy

    echo "Step 1.5: Applying GitHub Codespaces compatibility fixes..."

    # Fix PostgreSQL connection to use 127.0.0.1 instead of dokploy-postgres in GitHub Codespaces
    cat > packages/server/src/db/constants.ts << 'EOF'
import fs from "node:fs";

export const {
	DATABASE_URL,
	POSTGRES_PASSWORD_FILE,
	POSTGRES_USER = "dokploy",
	POSTGRES_DB = "dokploy",
	POSTGRES_HOST = "dokploy-postgres",
	POSTGRES_PORT = "5432",
} = process.env;

function readSecret(path: string): string {
	try {
		return fs.readFileSync(path, "utf8").trim();
	} catch {
		throw new Error(`Cannot read secret at ${path}`);
	}
}
export let dbUrl: string;
if (DATABASE_URL) {
	dbUrl = DATABASE_URL;
} else if (POSTGRES_PASSWORD_FILE) {
	const password = readSecret(POSTGRES_PASSWORD_FILE);
	dbUrl = `postgres://${POSTGRES_USER}:${encodeURIComponent(
		password,
	)}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}`;
} else {
	if (process.env.NODE_ENV !== "test") {
		console.warn(`
		⚠️  [DEPRECATED DATABASE CONFIG]
		You are using the legacy hardcoded database credentials.
		This mode WILL BE REMOVED in a future release.
		
		Please migrate to Docker Secrets using POSTGRES_PASSWORD_FILE.
		Please execute this command in your server: curl -sSL https://dokploy.com/security/0.26.6.sh | bash
		`);
	}

	// Use localhost for codespaces/local development if HOST is not explicitly set
	const dbHost = process.env.POSTGRES_HOST || (process.env.CODESPACES === "true" ? "127.0.0.1" : "localhost");

	if (process.env.NODE_ENV === "production") {
		dbUrl =
			"postgres://dokploy:amukds4wi9001583845717ad2@dokploy-postgres:5432/dokploy";
	} else {
		dbUrl =
			`postgres://dokploy:amukds4wi9001583845717ad2@${dbHost}:5432/dokploy`;
	}
}
EOF

    # Fix Redis connection to use 127.0.0.1 in GitHub Codespaces
    cat > apps/dokploy/server/queues/redis-connection.ts << 'EOF'
import type { ConnectionOptions } from "bullmq";

export const redisConfig: ConnectionOptions = {
	host: process.env.REDIS_HOST || "127.0.0.1",
};
EOF
else
    echo "Step 1: Dokploy repository already exists"
    cd dokploy

    echo "Step 1.5: Applying GitHub Codespaces compatibility fixes..."

    # Fix PostgreSQL connection to use 127.0.0.1 instead of dokploy-postgres in GitHub Codespaces
    cat > packages/server/src/db/constants.ts << 'EOF'
import fs from "node:fs";

export const {
	DATABASE_URL,
	POSTGRES_PASSWORD_FILE,
	POSTGRES_USER = "dokploy",
	POSTGRES_DB = "dokploy",
	POSTGRES_HOST = "dokploy-postgres",
	POSTGRES_PORT = "5432",
} = process.env;

function readSecret(path: string): string {
	try {
		return fs.readFileSync(path, "utf8").trim();
	} catch {
		throw new Error(`Cannot read secret at ${path}`);
	}
}
export let dbUrl: string;
if (DATABASE_URL) {
	dbUrl = DATABASE_URL;
} else if (POSTGRES_PASSWORD_FILE) {
	const password = readSecret(POSTGRES_PASSWORD_FILE);
	dbUrl = `postgres://${POSTGRES_USER}:${encodeURIComponent(
		password,
	)}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}`;
} else {
	if (process.env.NODE_ENV !== "test") {
		console.warn(`
		⚠️  [DEPRECATED DATABASE CONFIG]
		You are using the legacy hardcoded database credentials.
		This mode WILL BE REMOVED in a future release.
		
		Please migrate to Docker Secrets using POSTGRES_PASSWORD_FILE.
		Please execute this command in your server: curl -sSL https://dokploy.com/security/0.26.6.sh | bash
		`);
	}

	// Use localhost for codespaces/local development if HOST is not explicitly set
	const dbHost = process.env.POSTGRES_HOST || (process.env.CODESPACES === "true" ? "127.0.0.1" : "localhost");

	if (process.env.NODE_ENV === "production") {
		dbUrl =
			"postgres://dokploy:amukds4wi9001583845717ad2@dokploy-postgres:5432/dokploy";
	} else {
		dbUrl =
			`postgres://dokploy:amukds4wi9001583845717ad2@${dbHost}:5432/dokploy`;
	}
}
EOF

    # Fix Redis connection to use 127.0.0.1 in GitHub Codespaces
    cat > apps/dokploy/server/queues/redis-connection.ts << 'EOF'
import type { ConnectionOptions } from "bullmq";

export const redisConfig: ConnectionOptions = {
	host: process.env.REDIS_HOST || "127.0.0.1",
};
EOF
fi

echo "Step 2: Verifying requirements..."
if ! command -v pnpm &> /dev/null; then
    echo "Error: pnpm is not installed"
    exit 1
fi

echo "Step 3: Installing dependencies..."
pnpm install

echo "Step 4: Setting up application..."
pnpm dokploy:setup

echo "Step 5: Exposing Docker Swarm service ports..."
# Check if docker service command exists and services are running
if command -v docker &> /dev/null; then
    # Expose Postgres port if service exists
    if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "dokploy-postgres"; then
        echo "Exposing PostgreSQL service port..."
        docker service update --publish-add published=5432,target=5432 dokploy-postgres 2>/dev/null || true
    fi
    
    # Expose Redis port if service exists
    if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "dokploy-redis"; then
        echo "Exposing Redis service port..."
        docker service update --publish-add published=6379,target=6379 dokploy-redis 2>/dev/null || true
    fi
    
    # Wait for services to be ready
    echo "Waiting for database services to be ready..."
    sleep 10
fi

echo "Step 6: Clearing Next.js cache..."
rm -rf apps/dokploy/.next 2>/dev/null || true

echo "Step 7: Running database migrations..."
cd apps/dokploy
pnpm run migration:run
cd ../..

echo
echo "========================================="
echo "Deployment completed successfully!"
echo "========================================="
echo
echo "To start the development server:"
echo "  cd dokploy"
echo "  pnpm dokploy:dev"
echo
echo "The application will be available at:"
echo "  http://localhost:3000"
echo "or via the forwarded port in your codespace"
echo
echo "For more information, see README.md"

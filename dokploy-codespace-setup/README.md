# Dokploy Codespace Setup

This folder contains the complete setup scripts and configuration to run Dokploy in GitHub Codespaces.

## What's Included

- **deploy.sh** - Main deployment script that automatically:
  1. Clones the Dokploy repository
  2. Applies GitHub Codespaces compatibility fixes
  3. Installs dependencies
  4. Sets up the application (PostgreSQL, Redis, Traefik)
  5. Exposes Docker Swarm service ports
  6. Clears Next.js cache
  7. Runs database migrations
  8. Starts the development server

## Key Fixes Applied

### PostgreSQL Connection
The original code tries to connect to `dokploy-postgres` which only works within Docker Swarm networking. For codespaces, we use `127.0.0.1` instead.

### Redis Connection  
Similarly, Redis is configured to use `127.0.0.1` instead of `dokploy-redis`.

### Docker Swarm Ports
The Docker Swarm services (PostgreSQL and Redis) need their ports exposed to the host for the application to connect.

## Usage

### Option 1: Run manually
```bash
cd dokploy-codespace-setup
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Add to Codespace .devcontainer
Add this to your `.devcontainer/devcontainer.json`:

```json
{
  "postCreateCommand": "cd dokploy-codespace-setup && ./deploy.sh"
}
```

## After Setup

The application will be available at:
- **URL**: http://localhost:3000

## Troubleshooting

If you encounter issues:
1. Make sure Docker is running
2. Check that the ports are exposed: `docker service ls`
3. Verify database is accessible: `nc -zv 127.0.0.1 5432`

## Files Modified from Original

- `packages/server/src/db/constants.ts` - PostgreSQL connection fix
- `apps/dokploy/server/queues/redis-connection.ts` - Redis connection fix

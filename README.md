# Postiz Installer for n8n Servers

One-line installer for Postiz on servers already running n8n + Traefik.

I got tired of manually setting up Postiz alongside n8n on multiple VPS instances, so I wrote this script. It handles everything: PostgreSQL, Redis, SSL certs, the works.

## What it does

Adds Postiz to your existing n8n/Traefik setup without breaking anything. Creates backups before touching your config. Takes about 5 minutes.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/simplybychris/postiz-installer/main/install-postiz.sh -o install-postiz.sh
chmod +x install-postiz.sh
sudo bash install-postiz.sh
```

Or if you trust me (you probably shouldn't):

```bash
curl -fsSL https://raw.githubusercontent.com/simplybychris/postiz-installer/main/install-postiz.sh | sudo bash
```

## Requirements

- Ubuntu 24.04 (probably works on 22.04 too)
- Docker + Docker Compose
- Traefik running with SSL
- n8n installed (optional but that's the point)
- At least 2GB free RAM

## What gets installed

- **Postiz** (social media scheduler)
- **PostgreSQL 16** (database)
- **Redis 7** (cache)
- **SSL cert** via Let's Encrypt (automatic)

Everything runs in Docker. Your n8n setup stays untouched.

## Usage

The script asks 5 questions:

1. Subdomain for Postiz (default: `postiz`)
2. Database name (default: `postiz`)
3. Database user (default: `postiz`)
4. Database password (leave empty to auto-generate)
5. Confirm installation

Hit Enter to use defaults. It generates secure passwords automatically.

## What it creates

```
/root/
├── docker-compose.yml        # Updated
├── .env                       # Updated
├── backup_YYYYMMDD_HHMMSS/   # Your old config
└── POSTIZ_INFO.txt           # Installation details
```

New Docker volumes:
- `postgres_data` - Database
- `redis_data` - Cache
- `postiz_uploads` - File storage

## After installation

Open `https://postiz.yourdomain.com` and create an admin account. That's it.

## Useful commands

```bash
# View logs
docker compose logs -f postiz

# Restart services
docker compose restart postiz

# Backup database
docker exec root-postgres-1 pg_dump -U postiz postiz > backup.sql

# Rollback if something breaks
cd /root
cp backup_YYYYMMDD_HHMMSS/* ./
docker compose down postgres redis postiz
docker compose up -d
```

## Troubleshooting

**502 Bad Gateway**
Wait 2-3 minutes. Postiz takes time to initialize.

**No SSL certificate**
```bash
docker compose restart traefik
# Wait 2 minutes
```

**Postiz won't start**
```bash
docker logs root-postiz-1
docker compose restart postgres redis postiz
```

## Architecture

```
Internet → Traefik (SSL) → Postiz (port 5000)
                              ├─→ PostgreSQL
                              └─→ Redis
```

n8n runs alongside on its own subdomain. They share the Traefik proxy.

## Security

- Auto-generates 64-char secrets for JWT/auth
- Creates backup before any changes
- Validates all inputs
- Waits for database healthchecks
- Stores passwords in `/root/.env` (root-only)

## Files

- `install-postiz.sh` - Main installer
- `docs/` - Detailed documentation
- `.env.example` - Example environment config
- `docker-compose.example.yml` - Example compose file

## License

MIT. Do whatever you want with it.

## Contributing

Found a bug? Open an issue. Got a fix? Send a PR.

## Why this exists

I manage several VPS instances running n8n for workflow automation. Wanted to add Postiz (social media scheduling) without reinstalling everything or breaking my existing setup. This script automates what I was doing manually.

Works for me. Might work for you.

---

Made this after setting up my 3rd server manually. Life's too short for that.

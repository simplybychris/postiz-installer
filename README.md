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

The script asks 6 questions:

1. Subdomain for Postiz (default: `postiz`)
2. Database name (default: `postiz`)
3. Database user (default: `postiz`)
4. Database password (leave empty to auto-generate)
5. **Image choice**: Original or Custom with LinkedIn patch (default: Custom)
6. Confirm installation

Hit Enter to use defaults. It generates secure passwords automatically.

### Image Options

**Option 1: Original image** (ghcr.io/gitroomhq/postiz-app:latest)
- Always up-to-date
- May have issues with LinkedIn integration (bug #972)

**Option 2: Custom image with LinkedIn patch** ✅ RECOMMENDED
- Fixes LinkedIn integration bug #972
- Handles LinkedIn avatar upload errors gracefully
- Adds 2-3 minutes to build time
- Generated from `Dockerfile.postiz`

The LinkedIn bug (#972): LinkedIn CDN avatar URLs expire and return 403 Forbidden errors, causing the entire LinkedIn integration to fail. The custom image patches this by adding proper error handling.

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

1. Open `https://postiz.yourdomain.com`
2. Create your admin account
3. (Optional) Configure social media integrations

**Note:** Registration is automatically disabled after the first user signs up for security.

## Social Media Integration

To add LinkedIn, Twitter/X, Facebook, Instagram, etc., you need to create apps in their developer portals and add credentials to your `.env` file.

### LinkedIn Setup

1. Go to [LinkedIn Developer Portal](https://www.linkedin.com/developers/apps)
2. Create a new app
3. Add Products:
   - "Sign In with LinkedIn using OpenID Connect"
   - "Share on LinkedIn"
   - "Advertising API" (optional)
4. In **OAuth 2.0 settings**, add Redirect URL:
   ```
   https://postiz.yourdomain.com/integrations/social/linkedin
   ```
5. Copy your **Client ID** and **Client Secret**
6. Add to `/root/.env`:
   ```bash
   LINKEDIN_CLIENT_ID=your_client_id_here
   LINKEDIN_CLIENT_SECRET=your_client_secret_here
   ```
7. Restart Postiz:
   ```bash
   docker compose restart postiz
   ```

### Other Platforms

Similar process for Twitter/X, Facebook, Instagram, YouTube, Reddit, TikTok:

1. Create developer app in platform's portal
2. Get OAuth credentials (Client ID + Secret)
3. Add to `/root/.env`:
   ```bash
   TWITTER_CLIENT_ID=...
   TWITTER_CLIENT_SECRET=...
   FACEBOOK_CLIENT_ID=...
   FACEBOOK_CLIENT_SECRET=...
   # etc.
   ```
4. Restart: `docker compose restart postiz`

**Developer Portals:**
- Twitter/X: https://developer.twitter.com/
- Facebook: https://developers.facebook.com/
- Instagram: (uses Facebook app)
- YouTube: https://console.cloud.google.com/
- Reddit: https://www.reddit.com/prefs/apps
- TikTok: https://developers.tiktok.com/

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

### 502 Bad Gateway
Wait 2-3 minutes. Postiz takes time to initialize. Check logs:
```bash
docker logs postiz --tail 50
```

### No SSL certificate
Traefik needs a few minutes to generate Let's Encrypt certificates:
```bash
docker compose restart traefik
# Wait 2-3 minutes, then check: https://postiz.yourdomain.com
```

### Postiz won't start
Check logs for errors:
```bash
docker logs postiz --tail 100
docker compose ps  # Check if postgres and redis are healthy
docker compose restart postgres redis postiz
```

### LinkedIn integration fails (Error 500 or 403)

**If you used the custom image (Option 2):**
- The patch should handle this. If still failing, check credentials:
  ```bash
  docker exec postiz env | grep LINKEDIN
  ```
- Verify redirect URL in LinkedIn Developer Portal matches:
  ```
  https://postiz.yourdomain.com/integrations/social/linkedin
  ```

**If you used the original image (Option 1):**
- You're hitting bug #972. LinkedIn avatar URLs expire and cause 403 errors
- **Solution 1:** Re-run installer and choose Option 2 (custom image)
- **Solution 2:** Keep retrying - sometimes it works if avatar URL hasn't expired yet
- More info: https://github.com/gitroomhq/postiz-app/issues/972

### Media/File upload doesn't work

Check storage configuration:
```bash
docker exec postiz env | grep STORAGE
```

Should show:
```
STORAGE_PROVIDER=local
UPLOAD_DIRECTORY=/uploads
NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads
```

If missing, add to `/root/.env` and restart.

### Can't upload files / "Media" tab shows errors

This is usually due to missing storage configuration. The installer now adds these automatically, but if you upgraded from an old version:

```bash
# Add to /root/.env
echo "STORAGE_PROVIDER=local" >> /root/.env
echo "IS_GENERAL=true" >> /root/.env

# Restart
docker compose restart postiz
```

### Anyone can register (security issue)

Check if registration is disabled:
```bash
docker exec postiz env | grep DISABLE_REGISTRATION
```

Should be `DISABLE_REGISTRATION=true`. If not:
```bash
# Add to docker-compose.yml under postiz environment:
# - DISABLE_REGISTRATION=true

docker compose up -d postiz
```

### Database connection errors

```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Check PostgreSQL logs
docker logs postgres --tail 50

# Verify credentials match in .env and docker-compose.yml
grep POSTGRES /root/.env
```

### View all environment variables

```bash
docker exec postiz env | sort
```

### Complete reset (nuclear option)

```bash
cd /root
docker compose down postgres redis postiz
docker volume rm root_postgres_data root_redis_data root_postiz_uploads

# Restore from backup
cp backup_YYYYMMDD_HHMMSS/* ./

# Or re-run installer
sudo bash install-postiz.sh
```

## Architecture

```
Internet → Traefik (SSL) → Postiz (port 5000)
                              ├─→ PostgreSQL
                              └─→ Redis
```

n8n runs alongside on its own subdomain. They share the Traefik proxy.

## Security

The installer configures Postiz with security best practices:

- **Registration disabled** after first user signup (`DISABLE_REGISTRATION=true`)
- **64-character secrets** auto-generated for JWT and NextAuth
- **Local storage only** - uploads stay on your server (`STORAGE_PROVIDER=local`)
- **Automatic backups** before making any changes
- **Input validation** for all user inputs
- **Database healthchecks** before starting Postiz
- **Root-only access** to `/root/.env` containing secrets

### Environment Variables Set

The installer automatically configures these environment variables:

**Required:**
- `MAIN_URL` - Main Postiz URL
- `FRONTEND_URL` - Frontend URL
- `NEXT_PUBLIC_BACKEND_URL` - Backend API URL
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `JWT_SECRET` - JWT signing secret (auto-generated)
- `NEXTAUTH_SECRET` - NextAuth secret (auto-generated)
- `NEXTAUTH_URL` - NextAuth URL

**Storage:**
- `STORAGE_PROVIDER=local` - Use local filesystem storage
- `UPLOAD_DIRECTORY=/uploads` - Upload directory path
- `NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads` - Public upload path

**Security:**
- `DISABLE_REGISTRATION=true` - Disable open registration
- `IS_GENERAL=true` - Enable self-hosted mode

**Optional (add manually for social media):**
- `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET`
- `TWITTER_CLIENT_ID` / `TWITTER_CLIENT_SECRET`
- `FACEBOOK_CLIENT_ID` / `FACEBOOK_CLIENT_SECRET`
- And more...

## Files

- `install-postiz.sh` - Main installer script
- `Dockerfile.postiz` - Custom image with LinkedIn patch (optional)
- `README.md` - This file
- `push-to-github.sh` - Deployment script

The installer creates these files on your server:
- `/root/docker-compose.yml` - Updated compose configuration
- `/root/.env` - Environment variables and secrets
- `/root/Dockerfile.postiz` - Generated if you choose custom image
- `/root/POSTIZ_INFO.txt` - Installation details and commands
- `/root/backup_YYYYMMDD_HHMMSS/` - Backup of your previous config

## License

MIT. Do whatever you want with it.

## Contributing

Found a bug? Open an issue. Got a fix? Send a PR.

## Known Issues

### LinkedIn Integration Bug (#972)

**Issue:** LinkedIn avatar URLs from CDN expire and return 403 Forbidden errors, causing LinkedIn account addition to fail completely.

**Symptoms:**
- Error 500 when adding LinkedIn account
- Works randomly (when avatar URL hasn't expired yet)
- Logs show "403" errors related to image uploads

**Fix:** The installer offers a custom image with a patch that handles this gracefully. Choose **Option 2** (Custom image with LinkedIn patch) during installation.

**Technical details:** The patch adds `.catch()` error handling to `storage.uploadSimple()` in the integration service, allowing the integration to succeed even if avatar upload fails.

**More info:** https://github.com/gitroomhq/postiz-app/issues/972

### Other Issues

If you encounter issues not listed here, check the [Troubleshooting](#troubleshooting) section or open an issue on GitHub.

## Changelog

**v2.0** (2025-01-XX)
- Added custom Docker image option with LinkedIn bug #972 patch
- Added automatic security configuration (DISABLE_REGISTRATION=true)
- Added storage configuration (STORAGE_PROVIDER=local)
- Added IS_GENERAL=true for self-hosted mode
- Improved verification with detailed health checks
- Added comprehensive troubleshooting guide
- Added social media integration documentation

**v1.0** (2024-XX-XX)
- Initial release
- Basic Postiz installation
- PostgreSQL + Redis setup
- Traefik SSL integration

## Why this exists

I manage several VPS instances running n8n for workflow automation. Wanted to add Postiz (social media scheduling) without reinstalling everything or breaking my existing setup. This script automates what I was doing manually.

Works for me. Might work for you.

---

Made this after setting up my 3rd server manually. Life's too short for that.

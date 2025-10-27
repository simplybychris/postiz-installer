#!/bin/bash

###############################################################################
# Postiz Installation Script
#
# Automatycznie instaluje Postiz na serwerze z istniejącym n8n i Traefik
# Wymaga: Docker, Docker Compose, n8n, Traefik
#
# Użycie: bash install-postiz.sh
###############################################################################

set -e  # Exit on error

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funkcje pomocnicze
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Funkcja generująca silny sekret
generate_secret() {
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-64
}

###############################################################################
# KROK 1: Sprawdzenie wymagań
###############################################################################

print_header "KROK 1: Sprawdzanie wymagań systemowych"

# Sprawdź czy skrypt jest uruchamiany jako root
if [ "$EUID" -ne 0 ]; then
    print_error "Skrypt musi być uruchomiony jako root"
    echo "Użyj: sudo bash install-postiz.sh"
    exit 1
fi

print_success "Uruchomiono jako root"

# Sprawdź Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker nie jest zainstalowany"
    exit 1
fi
print_success "Docker: $(docker --version)"

# Sprawdź Docker Compose
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose nie jest zainstalowany"
    exit 1
fi
print_success "Docker Compose: $(docker compose version)"

# Sprawdź czy istnieje docker-compose.yml
if [ ! -f "/root/docker-compose.yml" ]; then
    print_error "Nie znaleziono /root/docker-compose.yml"
    print_info "Upewnij się, że n8n i Traefik są już zainstalowane"
    exit 1
fi
print_success "Znaleziono docker-compose.yml"

# Sprawdź czy istnieje .env
if [ ! -f "/root/.env" ]; then
    print_error "Nie znaleziono /root/.env"
    exit 1
fi
print_success "Znaleziono .env"

# Sprawdź czy Traefik działa
if ! docker ps | grep -q traefik; then
    print_error "Traefik nie jest uruchomiony"
    exit 1
fi
print_success "Traefik działa"

# Sprawdź czy n8n działa
if ! docker ps | grep -q n8n; then
    print_warning "n8n nie jest uruchomiony (ale to OK)"
else
    print_success "n8n działa"
fi

###############################################################################
# KROK 2: Zbieranie danych konfiguracyjnych
###############################################################################

print_header "KROK 2: Konfiguracja instalacji"

# Pobierz domenę z .env
DOMAIN_NAME=$(grep "^DOMAIN_NAME=" /root/.env | cut -d '=' -f2)
if [ -z "$DOMAIN_NAME" ]; then
    print_error "Nie znaleziono DOMAIN_NAME w .env"
    exit 1
fi
print_info "Wykryta domena: $DOMAIN_NAME"

# Pobierz subdomenę n8n (jeśli istnieje)
N8N_SUBDOMAIN=$(grep "^SUBDOMAIN=" /root/.env | cut -d '=' -f2 || echo "n8n")
if [ -z "$N8N_SUBDOMAIN" ]; then
    N8N_SUBDOMAIN=$(grep "^N8N_SUBDOMAIN=" /root/.env | cut -d '=' -f2 || echo "n8n")
fi
print_info "Subdomena n8n: $N8N_SUBDOMAIN"

# Zapytaj o subdomenę dla Postiz
echo ""
read -p "Subdomena dla Postiz (domyślnie: postiz): " POSTIZ_SUBDOMAIN
POSTIZ_SUBDOMAIN=${POSTIZ_SUBDOMAIN:-postiz}
print_success "Postiz będzie dostępny pod: https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}"

# Zapytaj o dane PostgreSQL
echo ""
print_info "Konfiguracja bazy danych PostgreSQL"
read -p "Nazwa bazy danych (domyślnie: postiz): " POSTGRES_DB
POSTGRES_DB=${POSTGRES_DB:-postiz}

read -p "Użytkownik PostgreSQL (domyślnie: postiz): " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-postiz}

read -s -p "Hasło PostgreSQL (zostaw puste dla auto-generacji): " POSTGRES_PASSWORD
echo ""
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(generate_secret)
    print_success "Wygenerowano silne hasło PostgreSQL"
else
    print_success "Użyto podanego hasła PostgreSQL"
fi

# Generuj sekrety
echo ""
print_info "Generowanie sekretów JWT..."
JWT_SECRET=$(generate_secret)
NEXTAUTH_SECRET=$(generate_secret)
print_success "Wygenerowano sekrety bezpieczeństwa"

# Zapytaj o wersję obrazu Postiz
echo ""
print_header "Wybór wersji Postiz"
print_warning "UWAGA: Postiz ma znany bug z integracją LinkedIn (GitHub Issue #972)"
print_info "Problem: LinkedIn może zwracać błąd 403 przy dodawaniu konta"
print_info "Więcej: https://github.com/gitroomhq/postiz-app/issues/972"
echo ""
echo "Dostępne opcje:"
echo "  1) Oryginalny obraz (najnowszy z GitHub)"
echo "     - Zawsze aktualna wersja"
echo "     - LinkedIn może działać niestabilnie"
echo ""
echo "  2) Custom obraz z patchem LinkedIn (ZALECANE)"
echo "     - Naprawia bug z LinkedIn integration"
echo "     - Wymaga zbudowania obrazu (~2-3 min dodatkowego czasu)"
echo ""
read -p "Wybierz opcję [1/2] (domyślnie: 2): " IMAGE_CHOICE
IMAGE_CHOICE=${IMAGE_CHOICE:-2}

if [ "$IMAGE_CHOICE" == "2" ]; then
    USE_CUSTOM_IMAGE=true
    print_success "Użyję custom obrazu z patchem LinkedIn"
else
    USE_CUSTOM_IMAGE=false
    print_info "Użyję oryginalnego obrazu z GitHub"
    print_warning "LinkedIn może działać niestabilnie - sprawdź dokumentację"
fi

# Podsumowanie konfiguracji
print_header "Podsumowanie konfiguracji"
echo "Domena:               $DOMAIN_NAME"
echo "Subdomena Postiz:     $POSTIZ_SUBDOMAIN"
echo "URL Postiz:           https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}"

# Wyświetl wersję obrazu (fix: unikaj && || w command substitution z set -e)
if [ "$USE_CUSTOM_IMAGE" == "true" ]; then
    echo "Wersja obrazu:        Custom z patchem LinkedIn"
else
    echo "Wersja obrazu:        Oryginalny z GitHub"
fi

echo "Baza danych:          $POSTGRES_DB"
echo "Użytkownik DB:        $POSTGRES_USER"
echo "Hasło DB:             [ukryte - zapisane w .env]"
echo "JWT Secret:           [wygenerowane]"
echo "NextAuth Secret:      [wygenerowane]"
echo ""

read -p "Czy kontynuować instalację? (tak/nie): " CONFIRM
if [ "$CONFIRM" != "tak" ] && [ "$CONFIRM" != "t" ] && [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    print_warning "Instalacja anulowana przez użytkownika"
    exit 0
fi

###############################################################################
# KROK 3: Backup obecnej konfiguracji
###############################################################################

print_header "KROK 3: Tworzenie kopii zapasowej"

BACKUP_DIR="/root/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

cp /root/docker-compose.yml "$BACKUP_DIR/docker-compose.yml"
cp /root/.env "$BACKUP_DIR/.env"

print_success "Backup zapisany w: $BACKUP_DIR"

###############################################################################
# KROK 4: Aktualizacja .env
###############################################################################

print_header "KROK 4: Aktualizacja pliku .env"

# Sprawdź czy .env już zawiera konfigurację Postiz
if grep -q "POSTIZ_SUBDOMAIN" /root/.env; then
    print_warning ".env już zawiera konfigurację Postiz - pomijam aktualizację"
else
    # Zmień SUBDOMAIN na N8N_SUBDOMAIN jeśli potrzeba
    if grep -q "^SUBDOMAIN=" /root/.env && ! grep -q "^N8N_SUBDOMAIN=" /root/.env; then
        sed -i "s/^SUBDOMAIN=/N8N_SUBDOMAIN=/" /root/.env
        print_success "Zmieniono SUBDOMAIN na N8N_SUBDOMAIN"
    fi

    # Dodaj konfigurację Postiz
    cat >> /root/.env << EOF

# Postiz Configuration (added by install-postiz.sh)
POSTIZ_SUBDOMAIN=${POSTIZ_SUBDOMAIN}

# PostgreSQL Configuration
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# JWT & Auth Secrets
JWT_SECRET=${JWT_SECRET}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
EOF

    print_success "Zaktualizowano .env"
fi

###############################################################################
# KROK 5: Aktualizacja docker-compose.yml
###############################################################################

print_header "KROK 5: Aktualizacja docker-compose.yml"

# Sprawdź czy Postiz już istnieje w docker-compose.yml
if grep -q "postiz:" /root/docker-compose.yml; then
    print_warning "docker-compose.yml już zawiera serwis Postiz"
    read -p "Czy zastąpić istniejącą konfigurację? (tak/nie): " REPLACE
    if [ "$REPLACE" != "tak" ] && [ "$REPLACE" != "t" ]; then
        print_info "Pomijam aktualizację docker-compose.yml"
        SKIP_COMPOSE_UPDATE=true
    fi
fi

if [ "$SKIP_COMPOSE_UPDATE" != "true" ]; then
    # Utwórz nowy docker-compose.yml
    cat > /root/docker-compose.yml.new << 'EOF'
version: "3.7"

services:
  traefik:
    image: "traefik"
    restart: always
    command:
      - "--api=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.mytlschallenge.acme.tlschallenge=true"
      - "--certificatesresolvers.mytlschallenge.acme.email=${SSL_EMAIL}"
      - "--certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - traefik_data:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "127.0.0.1:5678:5678"
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(`${N8N_SUBDOMAIN}.${DOMAIN_NAME}`)
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.entrypoints=web,websecure
      - traefik.http.routers.n8n.tls.certresolver=mytlschallenge
      - traefik.http.middlewares.n8n.headers.SSLRedirect=true
      - traefik.http.middlewares.n8n.headers.STSSeconds=315360000
      - traefik.http.middlewares.n8n.headers.browserXSSFilter=true
      - traefik.http.middlewares.n8n.headers.contentTypeNosniff=true
      - traefik.http.middlewares.n8n.headers.forceSTSHeader=true
      - traefik.http.middlewares.n8n.headers.SSLHost=${DOMAIN_NAME}
      - traefik.http.middlewares.n8n.headers.STSIncludeSubdomains=true
      - traefik.http.middlewares.n8n.headers.STSPreload=true
      - traefik.http.routers.n8n.middlewares=n8n@docker
    environment:
      - N8N_HOST=${N8N_SUBDOMAIN}.${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${N8N_SUBDOMAIN}.${DOMAIN_NAME}/
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
    volumes:
      - n8n_data:/home/node/.n8n
      - /local-files:/files

  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    restart: always
    environment:
      - MAIN_URL=https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}
      - FRONTEND_URL=https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}
      - NEXT_PUBLIC_BACKEND_URL=https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}/api
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - REDIS_URL=redis://redis:6379
      - BACKEND_INTERNAL_URL=http://127.0.0.1:3000
      - JWT_SECRET=${JWT_SECRET}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - NEXTAUTH_URL=https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}
      - UPLOAD_DIRECTORY=/uploads
      - NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads
      - STORAGE_PROVIDER=local
      - IS_GENERAL=true
      - DISABLE_REGISTRATION=true
    volumes:
      - postiz_uploads:/uploads
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "127.0.0.1:5000:5000"
    labels:
      - traefik.enable=true
      - traefik.http.routers.postiz.rule=Host(`${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}`)
      - traefik.http.routers.postiz.tls=true
      - traefik.http.routers.postiz.entrypoints=web,websecure
      - traefik.http.routers.postiz.tls.certresolver=mytlschallenge
      - traefik.http.services.postiz.loadbalancer.server.port=5000
      - traefik.http.middlewares.postiz.headers.SSLRedirect=true
      - traefik.http.middlewares.postiz.headers.STSSeconds=315360000
      - traefik.http.middlewares.postiz.headers.browserXSSFilter=true
      - traefik.http.middlewares.postiz.headers.contentTypeNosniff=true
      - traefik.http.middlewares.postiz.headers.forceSTSHeader=true
      - traefik.http.middlewares.postiz.headers.SSLHost=${DOMAIN_NAME}
      - traefik.http.middlewares.postiz.headers.STSIncludeSubdomains=true
      - traefik.http.middlewares.postiz.headers.STSPreload=true
      - traefik.http.routers.postiz.middlewares=postiz@docker

volumes:
  traefik_data:
    external: true
  n8n_data:
    external: true
  postgres_data:
  redis_data:
  postiz_uploads:
EOF

    # Jeśli użytkownik wybrał custom image, zamień konfigurację obrazu
    if [ "$USE_CUSTOM_IMAGE" == "true" ]; then
        # Zamień linię "image: ghcr.io/..." na konfigurację build
        sed -i '/postiz:/,/restart:/{s|    image: ghcr.io/gitroomhq/postiz-app:latest|    build:\
      context: /root\
      dockerfile: Dockerfile.postiz\
    image: postiz-custom:latest|}' /root/docker-compose.yml.new
        print_info "Skonfigurowano custom obraz Postiz z patchem LinkedIn"
    fi

    # Zamień stary plik na nowy
    mv /root/docker-compose.yml.new /root/docker-compose.yml
    print_success "Zaktualizowano docker-compose.yml"
fi

###############################################################################
# KROK 6: Tworzenie Dockerfile.postiz (jeśli wybrano custom image)
###############################################################################

if [ "$USE_CUSTOM_IMAGE" == "true" ]; then
    print_header "KROK 6a: Tworzenie Dockerfile z patchem LinkedIn"

    cat > /root/Dockerfile.postiz << 'DOCKERFILE_EOF'
FROM ghcr.io/gitroomhq/postiz-app:latest

USER root

# Fix dla LinkedIn integration bug (GitHub Issue #972)
# Problem: LinkedIn CDN URLs dla avatarów wygasają i zwracają 403
# Fix: Gracefully handle upload errors zamiast crashować całą integrację
RUN sed -i \
    's|: await this.storage.uploadSimple(picture)|: await this.storage.uploadSimple(picture).catch((err) => { console.error("Uploading the integrations image failed."); console.error(err); return undefined; })|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js

USER node
DOCKERFILE_EOF

    print_success "Utworzono Dockerfile.postiz z patchem"
fi

###############################################################################
# KROK 6: Pobieranie/Budowanie obrazów Docker
###############################################################################

print_header "KROK 6: Pobieranie i budowanie obrazów Docker"

cd /root
print_info "Pobieranie obrazów bazowych (może zająć kilka minut)..."
docker compose pull postgres redis

if [ "$USE_CUSTOM_IMAGE" == "true" ]; then
    print_info "Budowanie custom obrazu Postiz z patchem LinkedIn..."
    print_info "To może zająć 2-3 minuty..."
    docker compose build postiz
    print_success "Custom obraz Postiz został zbudowany"
else
    print_info "Pobieranie oryginalnego obrazu Postiz..."
    docker compose pull postiz
    print_success "Oryginalny obraz Postiz został pobrany"
fi

print_success "Wszystkie obrazy Docker są gotowe"

###############################################################################
# KROK 7: Uruchomienie serwisów
###############################################################################

print_header "KROK 7: Uruchamianie serwisów"

print_info "Uruchamianie kontenerów..."
docker compose up -d

# Poczekaj na healthcheck
print_info "Oczekiwanie na inicjalizację bazy danych (30 sekund)..."
sleep 30

print_success "Serwisy zostały uruchomione"

###############################################################################
# KROK 8: Weryfikacja instalacji
###############################################################################

print_header "KROK 8: Weryfikacja instalacji"

# Sprawdź status kontenerów
print_info "Status kontenerów:"
docker compose ps
echo ""

# Czekaj na uruchomienie kontenerów (max 90 sekund)
print_info "Oczekiwanie na uruchomienie kontenerów..."
TIMEOUT=90
ELAPSED=0
ALL_RUNNING=false

while [ $ELAPSED -lt $TIMEOUT ]; do
    POSTIZ_STATUS=$(docker ps --filter "name=postiz" --format "{{.Status}}" 2>/dev/null || echo "")
    POSTGRES_STATUS=$(docker ps --filter "name=postgres" --format "{{.Status}}" 2>/dev/null || echo "")
    REDIS_STATUS=$(docker ps --filter "name=redis" --format "{{.Status}}" 2>/dev/null || echo "")

    if [[ "$POSTIZ_STATUS" == *"Up"* ]] && [[ "$POSTGRES_STATUS" == *"Up"* ]] && [[ "$REDIS_STATUS" == *"Up"* ]]; then
        ALL_RUNNING=true
        break
    fi

    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
done
echo ""

if [ "$ALL_RUNNING" == "true" ]; then
    print_success "Wszystkie kontenery uruchomione (${ELAPSED}s)"
else
    print_warning "Niektóre kontenery mogą jeszcze się uruchamiać"
fi

# Sprawdź logi pod kątem krytycznych błędów
echo ""
print_info "Sprawdzanie logów Postiz pod kątem błędów..."
sleep 5

CRITICAL_ERRORS=$(docker logs postiz 2>&1 | grep -i "fatal\|critical" | wc -l | tr -d ' ')
ERROR_COUNT=$(docker logs postiz 2>&1 | grep -i "error" | grep -v "DeprecationWarning" | wc -l | tr -d ' ')

if [ "$CRITICAL_ERRORS" -gt 0 ]; then
    print_error "Znaleziono $CRITICAL_ERRORS krytycznych błędów!"
    print_info "Sprawdź logi: docker logs postiz"
elif [ "$ERROR_COUNT" -gt 10 ]; then
    print_warning "Znaleziono $ERROR_COUNT błędów w logach (może to być normalne podczas startu)"
else
    print_success "Brak krytycznych błędów w logach"
fi

# Test dostępności HTTP
echo ""
print_info "Sprawdzanie dostępności HTTP..."
sleep 3

# Sprawdź localhost:5000
LOCAL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5000" 2>/dev/null || echo "000")
if [[ "$LOCAL_HTTP" =~ ^(200|307|302|301)$ ]]; then
    print_success "Postiz odpowiada lokalnie (HTTP $LOCAL_HTTP)"
else
    print_warning "Postiz nie odpowiada lokalnie (HTTP $LOCAL_HTTP) - może się jeszcze inicjalizować"
fi

# Sprawdź publiczną domenę (przez Traefik)
PUBLIC_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}" 2>/dev/null || echo "000")
if [[ "$PUBLIC_HTTP" =~ ^(200|307|302|301)$ ]]; then
    print_success "Postiz dostępny publicznie: https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}"
else
    print_warning "Postiz jeszcze niedostępny publicznie (HTTP $PUBLIC_HTTP)"
    print_info "Traefik może potrzebować kilku minut na wygenerowanie certyfikatu SSL"
    print_info "Sprawdź za 2-3 minuty: https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}"
fi

###############################################################################
# KROK 9: Podsumowanie
###############################################################################

print_header "INSTALACJA ZAKOŃCZONA!"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  INSTALACJA ZAKOŃCZONA SUKCESEM                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Informacje o instalacji:${NC}"
echo ""
echo -e "  ${GREEN}Postiz URL:${NC}       https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}"
echo -e "  ${GREEN}n8n URL:${NC}          https://${N8N_SUBDOMAIN}.${DOMAIN_NAME}"
echo -e "  ${GREEN}Backup:${NC}           $BACKUP_DIR"
echo ""
echo -e "${BLUE}🔐 Dane dostępowe (zapisane w /root/.env):${NC}"
echo ""
echo -e "  ${GREEN}PostgreSQL DB:${NC}    $POSTGRES_DB"
echo -e "  ${GREEN}PostgreSQL User:${NC}  $POSTGRES_USER"
echo -e "  ${GREEN}PostgreSQL Pass:${NC}  [zobacz /root/.env]"
echo ""
echo -e "${BLUE}📦 Uruchomione kontenery:${NC}"
docker compose ps --format "  - {{.Service}}: {{.Status}}"
echo ""
echo -e "${BLUE}💾 Wykorzystanie zasobów:${NC}"
docker stats --no-stream --format "  - {{.Name}}: {{.MemUsage}}"
echo ""
echo -e "${YELLOW}⏭️  Następne kroki:${NC}"
echo ""
echo "  1. Otwórz: https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}"
echo "  2. Utwórz konto administratora"
echo "     (rejestracja jest wyłączona po utworzeniu pierwszego konta)"
echo ""
echo "  3. Konfiguracja integracji social media (opcjonalnie):"
echo ""
echo "     LINKEDIN:"
echo "     a) Utwórz aplikację: https://www.linkedin.com/developers/apps"
echo "     b) Dodaj Products: 'Sign In with LinkedIn', 'Share on LinkedIn'"
echo "     c) W OAuth 2.0 settings dodaj Redirect URL:"
echo "        https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}/integrations/social/linkedin"
echo "     d) Skopiuj Client ID i Client Secret"
echo "     e) Dodaj do /root/.env:"
echo "        LINKEDIN_CLIENT_ID=twoj_client_id"
echo "        LINKEDIN_CLIENT_SECRET=twoj_client_secret"
echo "     f) Restart Postiz: docker compose restart postiz"
echo ""
echo "     TWITTER/X, FACEBOOK, INSTAGRAM - podobnie jak LinkedIn"
echo "     Więcej informacji w dokumentacji Postiz"
echo ""
echo -e "${YELLOW}📚 Przydatne komendy:${NC}"
echo ""
echo "  # Logi Postiz"
echo "  docker compose logs -f postiz"
echo ""
echo "  # Restart serwisów"
echo "  docker compose restart postiz postgres redis"
echo ""
echo "  # Status wszystkich kontenerów"
echo "  docker compose ps"
echo ""
echo "  # Backup bazy danych"
echo "  docker exec root-postgres-1 pg_dump -U $POSTGRES_USER $POSTGRES_DB > postiz_backup.sql"
echo ""
echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
echo ""
echo "  # Jeśli Postiz nie startuje - sprawdź logi"
echo "  docker logs postiz --tail 100"
echo ""
echo "  # Jeśli LinkedIn nie działa mimo ustawienia credentials"
if [ "$USE_CUSTOM_IMAGE" == "true" ]; then
    echo "  - Masz zastosowany patch dla bug #972, powinno działać"
else
    echo "  - Możesz mieć problem z bug #972 (LinkedIn avatar 403)"
    echo "  - Spróbuj ponownie uruchomić instalator i wybrać opcję 2 (custom image)"
fi
echo ""
echo "  # Jeśli upload plików nie działa"
echo "  docker exec postiz env | grep STORAGE"
echo "  Powinno być: STORAGE_PROVIDER=local"
echo ""
echo -e "${GREEN}✨ Gotowe! Postiz został pomyślnie zainstalowany!${NC}"
echo ""

# Zapisz informacje o instalacji
cat > /root/POSTIZ_INFO.txt << EOF
Postiz Installation Info
========================
Installed: $(date)
Script: install-postiz.sh
Image: $([ "$USE_CUSTOM_IMAGE" == "true" ] && echo "Custom with LinkedIn patch" || echo "Original from GitHub")

URLs:
- Postiz: https://${POSTIZ_SUBDOMAIN}.${DOMAIN_NAME}
- n8n: https://${N8N_SUBDOMAIN}.${DOMAIN_NAME}

Database:
- Name: ${POSTGRES_DB}
- User: ${POSTGRES_USER}
- Password: [see /root/.env]

Backup:
- Location: ${BACKUP_DIR}

Configuration:
- docker-compose.yml: /root/docker-compose.yml
- .env: /root/.env
$([ "$USE_CUSTOM_IMAGE" == "true" ] && echo "- Dockerfile.postiz: /root/Dockerfile.postiz (LinkedIn patch)")

Volumes:
- postgres_data
- redis_data
- postiz_uploads

Security:
- Registration: DISABLED (tylko pierwszy user może się zarejestrować)
- Storage: LOCAL (uploads w /uploads volume)

Social Media Integration:
To add LinkedIn/Twitter/Facebook etc:
1. Create app in respective developer portal
2. Add credentials to /root/.env:
   LINKEDIN_CLIENT_ID=your_id
   LINKEDIN_CLIENT_SECRET=your_secret
3. Restart: docker compose restart postiz

Known Issues:
$([ "$USE_CUSTOM_IMAGE" == "true" ] && echo "- LinkedIn bug #972: PATCHED ✅" || echo "- LinkedIn bug #972: NOT PATCHED (may have issues)")
  More info: https://github.com/gitroomhq/postiz-app/issues/972

Useful commands:
- View logs: docker compose logs -f postiz
- Restart: docker compose restart postiz
- Status: docker compose ps
- Backup DB: docker exec root-postgres-1 pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > backup.sql
- Check env vars: docker exec postiz env | grep -E 'STORAGE|LINKEDIN|DISABLE'
EOF

print_success "Informacje o instalacji zapisane w /root/POSTIZ_INFO.txt"

exit 0

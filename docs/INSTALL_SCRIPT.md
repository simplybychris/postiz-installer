# Skrypt Automatycznej Instalacji Postiz

**Plik:** `install-postiz.sh`
**Wersja:** 1.0
**Data utworzenia:** 2025-10-23

---

## Spis Treści

1. [Opis Skryptu](#opis-skryptu)
2. [Wymagania](#wymagania)
3. [Co Robi Skrypt](#co-robi-skrypt)
4. [Instrukcja Użycia](#instrukcja-uzycia)
5. [Przykład Użycia](#przyklad-uzycia)
6. [Pytania Interaktywne](#pytania-interaktywne)
7. [Bezpieczeństwo](#bezpieczenstwo)
8. [Co Zostaje Utworzone](#co-zostaje-utworzone)
9. [Troubleshooting](#troubleshooting)

---

## Opis Skryptu

Skrypt `install-postiz.sh` automatyzuje proces instalacji platformy Postiz (social media management) na serwerze z już zainstalowanym **n8n** i **Traefik**.

### Główne Cechy:

✅ **Interaktywny** - pyta o niezbędne dane podczas instalacji
✅ **Bezpieczny** - tworzy backup przed zmianami
✅ **Automatyczny** - instaluje i konfiguruje wszystkie komponenty
✅ **Kolorowy output** - łatwy do śledzenia
✅ **Walidacja** - sprawdza wymagania przed instalacją
✅ **Generuje sekrety** - automatycznie tworzy silne klucze JWT

---

## Wymagania

### Wymagania Systemowe:

- **OS:** Ubuntu 24.04 (lub nowszy)
- **RAM:** Min. 2 GB wolne (zalecane 4 GB)
- **Dysk:** Min. 5 GB wolne
- **Docker:** Wersja 20.10+
- **Docker Compose:** Wersja 2.0+

### Wymagane Wcześniej Zainstalowane:

- ✅ **Traefik** - reverse proxy z certyfikatami SSL
- ✅ **n8n** - działający serwis (opcjonalnie)
- ✅ Plik `/root/docker-compose.yml`
- ✅ Plik `/root/.env` z konfiguracją domeny

### Minimalna Konfiguracja .env Przed Uruchomieniem:

```env
DOMAIN_NAME=twoja-domena.com
SSL_EMAIL=twoj@email.com
SUBDOMAIN=n8n  # lub N8N_SUBDOMAIN=n8n
GENERIC_TIMEZONE=Europe/Berlin
```

---

## Co Robi Skrypt

Skrypt wykonuje następujące kroki w kolejności:

### KROK 1: Sprawdzenie Wymagań (30 sekund)
- ✅ Weryfikuje uruchomienie jako root
- ✅ Sprawdza instalację Docker
- ✅ Sprawdza instalację Docker Compose
- ✅ Weryfikuje istnienie docker-compose.yml
- ✅ Weryfikuje istnienie .env
- ✅ Sprawdza czy Traefik działa
- ✅ Sprawdza czy n8n działa (opcjonalnie)

**Output:**
```
✓ Uruchomiono jako root
✓ Docker: Docker version 28.3.3
✓ Docker Compose: Docker Compose version v2.39.1
✓ Znaleziono docker-compose.yml
✓ Znaleziono .env
✓ Traefik działa
```

### KROK 2: Zbieranie Danych Konfiguracyjnych (2 minuty)
- 📝 Wykrywa domenę z .env
- 📝 Wykrywa subdomenę n8n
- ❓ Pyta o subdomenę dla Postiz (domyślnie: `postiz`)
- ❓ Pyta o nazwę bazy danych (domyślnie: `postiz`)
- ❓ Pyta o użytkownika PostgreSQL (domyślnie: `postiz`)
- ❓ Pyta o hasło PostgreSQL (lub generuje automatycznie)
- 🔐 Generuje JWT_SECRET (64 znaki)
- 🔐 Generuje NEXTAUTH_SECRET (64 znaki)
- 📋 Pokazuje podsumowanie i prosi o potwierdzenie

**Przykład Outputu:**
```
ℹ Wykryta domena: srv1009424.hstgr.cloud
ℹ Subdomena n8n: n8n

Subdomena dla Postiz (domyślnie: postiz): [ENTER]
✓ Postiz będzie dostępny pod: https://postiz.srv1009424.hstgr.cloud

Nazwa bazy danych (domyślnie: postiz): [ENTER]
Użytkownik PostgreSQL (domyślnie: postiz): [ENTER]
Hasło PostgreSQL (zostaw puste dla auto-generacji): [ENTER]
✓ Wygenerowano silne hasło PostgreSQL
✓ Wygenerowano sekrety bezpieczeństwa
```

### KROK 3: Tworzenie Kopii Zapasowej (<10 sekund)
- 📦 Tworzy katalog `/root/backup_YYYYMMDD_HHMMSS/`
- 💾 Kopiuje `docker-compose.yml` do backupu
- 💾 Kopiuje `.env` do backupu

**Output:**
```
✓ Backup zapisany w: /root/backup_20251023_083000
```

### KROK 4: Aktualizacja .env (5 sekund)
- 🔄 Zmienia `SUBDOMAIN=` na `N8N_SUBDOMAIN=` (jeśli potrzeba)
- ➕ Dodaje konfigurację Postiz:
  - `POSTIZ_SUBDOMAIN`
  - `POSTGRES_DB`
  - `POSTGRES_USER`
  - `POSTGRES_PASSWORD`
  - `JWT_SECRET`
  - `NEXTAUTH_SECRET`

**Dodane do .env:**
```env
# Postiz Configuration (added by install-postiz.sh)
POSTIZ_SUBDOMAIN=postiz

# PostgreSQL Configuration
POSTGRES_DB=postiz
POSTGRES_USER=postiz
POSTGRES_PASSWORD=A8x...wQ==

# JWT & Auth Secrets
JWT_SECRET=kL9m...xT2==
NEXTAUTH_SECRET=pR4n...yF7==
```

### KROK 5: Aktualizacja docker-compose.yml (10 sekund)
- 📝 Tworzy nowy `docker-compose.yml` z serwisami:
  - ✅ **traefik** - zachowany bez zmian
  - ✅ **n8n** - zaktualizowany (SUBDOMAIN → N8N_SUBDOMAIN)
  - ➕ **postgres** - PostgreSQL 16 Alpine
  - ➕ **redis** - Redis 7 Alpine
  - ➕ **postiz** - Postiz app z Traefik labels

**Dodane Serwisy:**

**postgres:**
- Image: `postgres:16-alpine`
- Volume: `postgres_data`
- Healthcheck: `pg_isready`
- Environment: DB, USER, PASSWORD z .env

**redis:**
- Image: `redis:7-alpine`
- Volume: `redis_data`
- Healthcheck: `redis-cli ping`

**postiz:**
- Image: `ghcr.io/gitroomhq/postiz-app:latest`
- Depends on: postgres (healthy), redis (healthy)
- Port: `127.0.0.1:5000:5000`
- Volume: `postiz_uploads`
- Traefik labels: SSL + security headers

### KROK 6: Pobieranie Obrazów Docker (2-5 minut)
- ⬇️ Pobiera `postgres:16-alpine` (~80 MB)
- ⬇️ Pobiera `redis:7-alpine` (~40 MB)
- ⬇️ Pobiera `ghcr.io/gitroomhq/postiz-app:latest` (~1.5 GB)

**Output:**
```
ℹ Pobieranie obrazów (może zająć kilka minut)...
postgres Pulling
redis Pulling
postiz Pulling
✓ Obrazy Docker zostały pobrane
```

### KROK 7: Uruchamianie Serwisów (30-60 sekund)
- 🚀 Uruchamia `docker compose up -d`
- 🔄 Docker Compose automatycznie:
  - Tworzy volumes (postgres_data, redis_data, postiz_uploads)
  - Tworzy sieć (root_default)
  - Recreate Traefik i n8n (nowa konfiguracja)
  - Uruchamia postgres z healthcheck
  - Uruchamia redis z healthcheck
  - Czeka na healthy status postgres + redis
  - Uruchamia postiz
- ⏱️ Czeka 30 sekund na inicjalizację bazy danych

**Output:**
```
ℹ Uruchamianie kontenerów...
Volume "root_postgres_data" Created
Volume "root_redis_data" Created
Volume "root_postiz_uploads" Created
Container root-postgres-1 Created
Container root-redis-1 Created
Container root-postiz-1 Created
✓ Serwisy zostały uruchomione
ℹ Oczekiwanie na inicjalizację bazy danych (30 sekund)...
```

### KROK 8: Weryfikacja Instalacji (10 sekund)
- ✅ Wyświetla status wszystkich kontenerów
- 🌐 Sprawdza dostępność Postiz na localhost:5000
- 📊 Pokazuje podstawowe statystyki

**Output:**
```
ℹ Status kontenerów:
NAME              STATUS
root-postiz-1     Up 10 seconds
root-postgres-1   Up 10 seconds (healthy)
root-redis-1      Up 10 seconds (healthy)
root-traefik-1    Up 10 seconds
root-n8n-1        Up 10 seconds

✓ Postiz odpowiada na localhost:5000
```

### KROK 9: Podsumowanie (final output)
- 📋 Wyświetla wszystkie ważne informacje:
  - URLs (Postiz, n8n)
  - Lokalizację backupu
  - Dane dostępowe do bazy
  - Status kontenerów
  - Wykorzystanie zasobów
  - Następne kroki
  - Przydatne komendy
- 💾 Tworzy plik `/root/POSTIZ_INFO.txt` z podsumowaniem

---

## Instrukcja Użycia

### Metoda 1: Bezpośrednie Uruchomienie na Serwerze

```bash
# 1. Zaloguj się na serwer jako root
ssh root@twoj-serwer.com

# 2. Pobierz skrypt (wybierz jedną metodę)

# Opcja A: Jeśli masz skrypt lokalnie
scp install-postiz.sh root@twoj-serwer.com:/root/

# Opcja B: Utwórz skrypt ręcznie
nano /root/install-postiz.sh
# [wklej zawartość skryptu]
# Ctrl+X, Y, Enter

# 3. Nadaj uprawnienia wykonania
chmod +x /root/install-postiz.sh

# 4. Uruchom skrypt
bash /root/install-postiz.sh

# 5. Odpowiedz na pytania interaktywne
# 6. Poczekaj na zakończenie (5-10 minut)
# 7. Otwórz URL w przeglądarce
```

### Metoda 2: Automatyczna Instalacja (z lokalnego komputera)

Jeśli chcesz uruchomić instalację zdalnie z lokalnego komputera:

```bash
# Wyślij skrypt i uruchom
scp install-postiz.sh root@twoj-serwer.com:/root/
ssh root@twoj-serwer.com "chmod +x /root/install-postiz.sh && /root/install-postiz.sh"
```

### Metoda 3: Non-Interactive (automatyczna)

Możesz przygotować odpowiedzi wcześniej:

```bash
# Utwórz plik z odpowiedziami
cat > /root/postiz-config.txt << EOF
postiz
postiz
postiz
moje_super_silne_haslo_123
tak
EOF

# Uruchom z automatycznymi odpowiedziami
bash /root/install-postiz.sh < /root/postiz-config.txt
```

---

## Przykład Użycia

### Pełny Przebieg Instalacji:

```bash
root@srv1009424:~# bash install-postiz.sh

═══════════════════════════════════════════════════════
  KROK 1: Sprawdzanie wymagań systemowych
═══════════════════════════════════════════════════════

✓ Uruchomiono jako root
✓ Docker: Docker version 28.3.3, build 980b856
✓ Docker Compose: Docker Compose version v2.39.1
✓ Znaleziono docker-compose.yml
✓ Znaleziono .env
✓ Traefik działa
✓ n8n działa

═══════════════════════════════════════════════════════
  KROK 2: Konfiguracja instalacji
═══════════════════════════════════════════════════════

ℹ Wykryta domena: srv1009424.hstgr.cloud
ℹ Subdomena n8n: n8n

Subdomena dla Postiz (domyślnie: postiz):
✓ Postiz będzie dostępny pod: https://postiz.srv1009424.hstgr.cloud

ℹ Konfiguracja bazy danych PostgreSQL
Nazwa bazy danych (domyślnie: postiz):
Użytkownik PostgreSQL (domyślnie: postiz):
Hasło PostgreSQL (zostaw puste dla auto-generacji):
✓ Wygenerowano silne hasło PostgreSQL

ℹ Generowanie sekretów JWT...
✓ Wygenerowano sekrety bezpieczeństwa

═══════════════════════════════════════════════════════
  Podsumowanie konfiguracji
═══════════════════════════════════════════════════════

Domena:               srv1009424.hstgr.cloud
Subdomena Postiz:     postiz
URL Postiz:           https://postiz.srv1009424.hstgr.cloud
Baza danych:          postiz
Użytkownik DB:        postiz
Hasło DB:             [ukryte - zapisane w .env]
JWT Secret:           [wygenerowane]
NextAuth Secret:      [wygenerowane]

Czy kontynuować instalację? (tak/nie): tak

═══════════════════════════════════════════════════════
  KROK 3: Tworzenie kopii zapasowej
═══════════════════════════════════════════════════════

✓ Backup zapisany w: /root/backup_20251023_083542

═══════════════════════════════════════════════════════
  KROK 4: Aktualizacja pliku .env
═══════════════════════════════════════════════════════

✓ Zmieniono SUBDOMAIN na N8N_SUBDOMAIN
✓ Zaktualizowano .env

═══════════════════════════════════════════════════════
  KROK 5: Aktualizacja docker-compose.yml
═══════════════════════════════════════════════════════

✓ Zaktualizowano docker-compose.yml

═══════════════════════════════════════════════════════
  KROK 6: Pobieranie obrazów Docker
═══════════════════════════════════════════════════════

ℹ Pobieranie obrazów (może zająć kilka minut)...
[... progress bars ...]
✓ Obrazy Docker zostały pobrane

═══════════════════════════════════════════════════════
  KROK 7: Uruchamianie serwisów
═══════════════════════════════════════════════════════

ℹ Uruchamianie kontenerów...
ℹ Oczekiwanie na inicjalizację bazy danych (30 sekund)...
✓ Serwisy zostały uruchomione

═══════════════════════════════════════════════════════
  KROK 8: Weryfikacja instalacji
═══════════════════════════════════════════════════════

ℹ Status kontenerów:
NAME              STATUS
root-postiz-1     Up
root-postgres-1   Up (healthy)
root-redis-1      Up (healthy)
root-traefik-1    Up
root-n8n-1        Up

✓ Postiz odpowiada na localhost:5000

═══════════════════════════════════════════════════════
  INSTALACJA ZAKOŃCZONA!
═══════════════════════════════════════════════════════

╔════════════════════════════════════════════════════════════════╗
║                  INSTALACJA ZAKOŃCZONA SUKCESEM                ║
╚════════════════════════════════════════════════════════════════╝

📋 Informacje o instalacji:

  Postiz URL:       https://postiz.srv1009424.hstgr.cloud
  n8n URL:          https://n8n.srv1009424.hstgr.cloud
  Backup:           /root/backup_20251023_083542

🔐 Dane dostępowe (zapisane w /root/.env):

  PostgreSQL DB:    postiz
  PostgreSQL User:  postiz
  PostgreSQL Pass:  [zobacz /root/.env]

📦 Uruchomione kontenery:
  - traefik: Up
  - n8n: Up
  - postgres: Up (healthy)
  - redis: Up (healthy)
  - postiz: Up

💾 Wykorzystanie zasobów:
  - root-postiz-1: 950MiB / 7.755GiB
  - root-postgres-1: 65MiB / 7.755GiB
  - root-redis-1: 15MiB / 7.755GiB
  - root-traefik-1: 108MiB / 7.755GiB
  - root-n8n-1: 240MiB / 7.755GiB

⏭️  Następne kroki:

  1. Otwórz: https://postiz.srv1009424.hstgr.cloud
  2. Utwórz konto administratora
  3. Skonfiguruj integracje social media (opcjonalnie)

📚 Przydatne komendy:

  # Logi Postiz
  docker compose logs -f postiz

  # Restart serwisów
  docker compose restart postiz postgres redis

  # Status wszystkich kontenerów
  docker compose ps

  # Backup bazy danych
  docker exec root-postgres-1 pg_dump -U postiz postiz > postiz_backup.sql

✨ Gotowe! Postiz został pomyślnie zainstalowany!

✓ Informacje o instalacji zapisane w /root/POSTIZ_INFO.txt
```

---

## Pytania Interaktywne

Podczas instalacji skrypt zadaje następujące pytania:

### 1. Subdomena dla Postiz
```
Subdomena dla Postiz (domyślnie: postiz):
```
- **Domyślna wartość:** `postiz`
- **Przykłady:** `postiz`, `social`, `sm`, `app`
- **Wynik:** Postiz będzie dostępny pod `https://[twoja-odpowiedź].domena.com`

### 2. Nazwa bazy danych
```
Nazwa bazy danych (domyślnie: postiz):
```
- **Domyślna wartość:** `postiz`
- **Przykłady:** `postiz`, `postiz_db`, `social_media`
- **Uwaga:** Używaj tylko liter, cyfr i underscore

### 3. Użytkownik PostgreSQL
```
Użytkownik PostgreSQL (domyślnie: postiz):
```
- **Domyślna wartość:** `postiz`
- **Przykłady:** `postiz`, `admin`, `dbuser`
- **Uwaga:** Używaj tylko liter, cyfr i underscore

### 4. Hasło PostgreSQL
```
Hasło PostgreSQL (zostaw puste dla auto-generacji):
```
- **Domyślnie:** Generuje silne 64-znakowe hasło
- **Opcjonalnie:** Możesz podać własne hasło (min. 12 znaków)
- **Uwaga:** Hasło nie będzie widoczne podczas wpisywania

### 5. Potwierdzenie instalacji
```
Czy kontynuować instalację? (tak/nie):
```
- **Wymagana odpowiedź:** `tak`, `t`, `yes`, `y`
- **Anulowanie:** `nie`, `n`, `no`

---

## Bezpieczeństwo

### Generowane Sekrety

Skrypt automatycznie generuje silne, losowe sekrety za pomocą `openssl`:

```bash
openssl rand -base64 48 | tr -d "=+/" | cut -c1-64
```

- **JWT_SECRET:** 64 znaki alfanumeryczne
- **NEXTAUTH_SECRET:** 64 znaki alfanumeryczne
- **POSTGRES_PASSWORD:** 64 znaki alfanumeryczne (jeśli auto-generowane)

### Backup Przed Zmianami

Skrypt **zawsze** tworzy backup przed wprowadzeniem zmian:

```
/root/backup_YYYYMMDD_HHMMSS/
├── docker-compose.yml
└── .env
```

### Rollback w Razie Problemów

```bash
# Przywróć backup
cd /root
cp backup_20251023_083542/docker-compose.yml ./
cp backup_20251023_083542/.env ./

# Restart serwisów
docker compose down
docker compose up -d
```

### Bezpieczne Hasła

Wszystkie hasła są zapisane w `/root/.env`, który:
- Jest dostępny tylko dla root (chmod 600)
- Nie jest commitowany do git (.gitignore)
- Jest backupowany przed zmianami

---

## Co Zostaje Utworzone

### Pliki:

```
/root/
├── docker-compose.yml          # Zaktualizowany (nowe serwisy)
├── .env                        # Zaktualizowany (nowe zmienne)
├── POSTIZ_INFO.txt            # Nowy plik z podsumowaniem
└── backup_YYYYMMDD_HHMMSS/    # Katalog backupu
    ├── docker-compose.yml
    └── .env
```

### Docker Volumes:

```
docker volume ls

root_postgres_data     # Baza danych PostgreSQL
root_redis_data        # Dane Redis
root_postiz_uploads    # Pliki uploadowane w Postiz
root_traefik_data      # Certyfikaty SSL (istniejący)
root_n8n_data          # Dane n8n (istniejący)
```

### Docker Kontenery:

```
docker ps

root-postiz-1      # Postiz app (port 5000)
root-postgres-1    # PostgreSQL 16 (port 5432)
root-redis-1       # Redis 7 (port 6379)
root-traefik-1     # Traefik (port 80, 443)
root-n8n-1         # n8n (port 5678)
```

### Sieć Docker:

```
root_default (172.18.0.0/16)
├── traefik    (172.18.0.2)
├── n8n        (172.18.0.3)
├── postgres   (172.18.0.4)
├── redis      (172.18.0.5)
└── postiz     (172.18.0.6)
```

---

## Troubleshooting

### Problem: "Permission denied"

```
bash: ./install-postiz.sh: Permission denied
```

**Rozwiązanie:**
```bash
chmod +x install-postiz.sh
bash install-postiz.sh
```

### Problem: "Script must be run as root"

```
✗ Skrypt musi być uruchomiony jako root
```

**Rozwiązanie:**
```bash
sudo bash install-postiz.sh
# lub zaloguj się jako root
su -
bash install-postiz.sh
```

### Problem: "Docker is not installed"

```
✗ Docker nie jest zainstalowany
```

**Rozwiązanie:**
```bash
# Zainstaluj Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### Problem: "docker-compose.yml not found"

```
✗ Nie znaleziono /root/docker-compose.yml
```

**Rozwiązanie:**
- Upewnij się, że n8n i Traefik są już zainstalowane
- Sprawdź czy plik istnieje: `ls -la /root/docker-compose.yml`
- Jeśli nie, najpierw zainstaluj n8n i Traefik

### Problem: "Postiz already exists in docker-compose.yml"

```
⚠ docker-compose.yml już zawiera serwis Postiz
Czy zastąpić istniejącą konfigurację? (tak/nie):
```

**Rozwiązanie:**
- Odpowiedz `tak` aby zaktualizować konfigurację
- Odpowiedz `nie` aby pominąć (skrypt użyje istniejącej konfiguracji)

### Problem: Postiz nie startuje

```bash
# Sprawdź logi
docker logs root-postiz-1

# Sprawdź czy postgres i redis są healthy
docker ps | grep -E "postgres|redis"

# Restart z opóźnieniem
docker compose restart postgres redis
sleep 20
docker compose restart postiz
```

### Problem: 502 Bad Gateway

**Przyczyny:**
1. Postiz jeszcze się inicjalizuje (poczekaj 2-3 minuty)
2. Błąd w bazie danych
3. Problem z Traefik

**Rozwiązanie:**
```bash
# Sprawdź logi Postiz
docker logs root-postiz-1 --tail 100

# Sprawdź czy Postiz nasłuchuje
docker exec root-postiz-1 netstat -tlnp | grep 5000

# Sprawdź logi Traefik
docker logs root-traefik-1 --tail 50
```

### Problem: Certyfikat SSL nie został wygenerowany

```bash
# Sprawdź logi Traefik
docker logs root-traefik-1 | grep -i acme

# Restart Traefik
docker compose restart traefik

# Poczekaj 2-3 minuty na wygenerowanie certyfikatu
```

### Problem: Skrypt zawieszony podczas pobierania obrazów

**Rozwiązanie:**
```bash
# Ctrl+C aby anulować
# Sprawdź połączenie internetowe
ping -c 4 8.8.8.8

# Uruchom ponownie
bash install-postiz.sh
```

### Przywracanie z Backupu

```bash
# Znajdź backup
ls -la /root/backup_*

# Przywróć pliki
cd /root
cp backup_20251023_083542/docker-compose.yml ./
cp backup_20251023_083542/.env ./

# Usuń kontenery Postiz
docker compose down postgres redis postiz

# Uruchom ponownie oryginalne serwisy
docker compose up -d
```

---

## Często Zadawane Pytania

### Czy mogę uruchomić skrypt wielokrotnie?

**Tak**, skrypt jest idempotentny. Jeśli Postiz już istnieje, skrypt zapyta czy chcesz zaktualizować konfigurację.

### Czy n8n przestanie działać podczas instalacji?

**Nie**, n8n będzie krotko restartowany (5-10 sekund) podczas aktualizacji docker-compose.yml, ale nie straci danych.

### Jak zmienić subdomenę Postiz po instalacji?

```bash
# 1. Edytuj .env
nano /root/.env
# Zmień POSTIZ_SUBDOMAIN=nowa-subdomena

# 2. Restart Postiz
docker compose up -d postiz

# 3. Poczekaj 2 minuty na nowy certyfikat SSL
```

### Czy mogę użyć tego skryptu na serwerze bez n8n?

**Nie**, skrypt wymaga istniejącego docker-compose.yml z Traefik. Możesz zmodyfikować skrypt usuwając sekcję n8n.

### Jak często robić backup bazy danych?

Zalecane:
```bash
# Utwórz cron job
crontab -e

# Dodaj (codziennie o 3:00)
0 3 * * * docker exec root-postgres-1 pg_dump -U postiz postiz > /root/backups/postiz_$(date +\%Y\%m\%d).sql
```

---

## Zaawansowane Użycie

### Zmienne Środowiskowe

Możesz ustawić zmienne przed uruchomieniem skryptu:

```bash
export POSTIZ_SUBDOMAIN="social"
export POSTGRES_DB="mydb"
export POSTGRES_USER="myuser"
export POSTGRES_PASSWORD="mypassword"

bash install-postiz.sh
```

### Silent Mode (bez interakcji)

```bash
# Przygotuj odpowiedzi
{
  echo ""           # Subdomena (domyślna)
  echo ""           # DB name (domyślna)
  echo ""           # DB user (domyślny)
  echo ""           # Password (auto-generate)
  echo "tak"        # Potwierdzenie
} | bash install-postiz.sh
```

### Customizacja Skryptu

Możesz edytować skrypt przed uruchomieniem:

```bash
nano install-postiz.sh

# Zmień domyślne wartości:
POSTIZ_SUBDOMAIN=${POSTIZ_SUBDOMAIN:-twoja-domena}
POSTGRES_DB=${POSTGRES_DB:-twoja-baza}
```

---

## Podsumowanie

✅ **Łatwy w użyciu** - interaktywny interfejs
✅ **Bezpieczny** - automatyczne backupy
✅ **Szybki** - instalacja 5-10 minut
✅ **Kompletny** - wszystko w jednym skrypcie
✅ **Dobrze udokumentowany** - szczegółowa instrukcja

**Czas instalacji:** 5-10 minut
**Poziom trudności:** Łatwy (podstawowa znajomość terminala)
**Wsparcie:** Ubuntu 24.04, Docker 20.10+, Docker Compose 2.0+

---

**Gotowe!** Możesz teraz używać tego skryptu na każdym serwerze z n8n i Traefik.


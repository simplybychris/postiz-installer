# Szybki Start - Instalacja Postiz

Prosty przewodnik instalacji Postiz na serwerze z n8n i Traefik (≤5 minut).

---

## Wymagania

✅ Serwer z Ubuntu 24.04
✅ Docker + Docker Compose zainstalowane
✅ Traefik działający (z SSL)
✅ n8n zainstalowany (opcjonalnie)

---

## Instalacja w 3 Krokach

### 1. Pobierz Skrypt

```bash
# Zaloguj się na serwer
ssh root@twoj-serwer.com

# Pobierz skrypt (wybierz metodę)

# Opcja A: Z lokalnego komputera
scp install-postiz.sh root@twoj-serwer.com:/root/

# Opcja B: Utwórz na serwerze
nano /root/install-postiz.sh
# [wklej zawartość, Ctrl+X, Y, Enter]
```

### 2. Uruchom Skrypt

```bash
# Nadaj uprawnienia
chmod +x /root/install-postiz.sh

# Uruchom
bash /root/install-postiz.sh
```

### 3. Odpowiedz na Pytania

```
Subdomena dla Postiz (domyślnie: postiz): [ENTER]
Nazwa bazy danych (domyślnie: postiz): [ENTER]
Użytkownik PostgreSQL (domyślnie: postiz): [ENTER]
Hasło PostgreSQL (zostaw puste dla auto-generacji): [ENTER]
Czy kontynuować instalację? (tak/nie): tak
```

**Poczekaj 5-10 minut** ☕

---

## Gotowe! 🎉

Otwórz w przeglądarce:
```
https://postiz.twoja-domena.com
```

Utwórz konto administratora i zacznij korzystać!

---

## Co Zostało Zainstalowane?

✅ **Postiz** - Social media management
✅ **PostgreSQL 16** - Baza danych
✅ **Redis 7** - Cache
✅ **SSL Certificate** - Automatycznie (Let's Encrypt)

---

## Przydatne Komendy

```bash
# Status kontenerów
docker ps

# Logi Postiz
docker compose logs -f postiz

# Restart Postiz
docker compose restart postiz

# Backup bazy
docker exec root-postgres-1 pg_dump -U postiz postiz > backup.sql
```

---

## Potrzebujesz Pomocy?

📖 **Szczegółowa dokumentacja:** [INSTALL_SCRIPT.md](INSTALL_SCRIPT.md)
📝 **Raport instalacji:** [POSTIZ_INSTALLATION.md](POSTIZ_INSTALLATION.md)
💾 **Backup konfiguracji:** `/root/backup_YYYYMMDD_HHMMSS/`
📋 **Info o instalacji:** `/root/POSTIZ_INFO.txt`

---

## Troubleshooting

### Problem: 502 Bad Gateway
**Rozwiązanie:** Poczekaj 2-3 minuty - Postiz się inicjalizuje

### Problem: Brak certyfikatu SSL
**Rozwiązanie:** `docker compose restart traefik` i poczekaj 2 min

### Problem: Postiz nie startuje
**Rozwiązanie:**
```bash
docker logs root-postiz-1
docker compose restart postgres redis postiz
```

---

**To wszystko!** Prosty skrypt, automatyczna konfiguracja, zero problemów 🚀

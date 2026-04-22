# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Sangemarmar VTS** — Vehicle Entry, Sales & Commission Management System for a hospitality/tourism business. Cross-platform app: Flutter mobile frontend + NestJS REST API backend + PostgreSQL database.

- **Backend**: Deployed on Railway.app
- **Frontend Web**: Deployed on GitHub Pages (static Flutter build)
- **Local dev**: Docker Compose (PostgreSQL + backend together)

---

## Commands

### Backend (`/backend`)

```bash
npm run start:dev   # Dev server with hot reload (port 3000)
npm run build       # Compile TypeScript → dist/
npm start           # Production (runs dist/main.js)
npm run lint        # ESLint with auto-fix
npm run test        # Jest test suite
npm run seed        # Seed database with default users
npm run typeorm     # TypeORM CLI (migrations)
```

### Mobile (`/mobile`)

```bash
flutter pub get                                           # Install dependencies
flutter run                                               # Run on connected device/emulator
flutter build web --release --base-href "/Sangemarmar-VTS/"  # Build for GitHub Pages
flutter analyze                                           # Dart lint
```

### Docker (local dev)

```bash
docker-compose up                                 # Start PostgreSQL + backend
docker-compose -f docker-compose.prod.yml up      # Production stack
```

### Database Setup

```bash
# After docker-compose up:
cd backend && npm run seed
# Creates 5 default users (admin, manager, gate, sales, cashier roles)
```

Default credentials after seeding:
| Role | Email | Password |
|---|---|---|
| ADMIN | admin@sangemarmar.com | Admin@1234 |
| MANAGER | manager@sangemarmar.com | Manager@1234 |
| GATE_OPERATOR | gate@sangemarmar.com | Gate@1234 |
| SALES_STAFF | sales@sangemarmar.com | Sales@1234 |
| CASHIER | cashier@sangemarmar.com | Cashier@1234 |

---

## Architecture

### Backend (NestJS + TypeORM + PostgreSQL)

- `backend/src/app.module.ts` — Root module: TypeORM connection (reads `.env`), imports all feature modules
- `backend/src/main.ts` — Bootstrap: global validation pipe, CORS enabled, API prefix `/api/v1`, port from `APP_PORT` env
- Feature modules: `auth/`, `users/`, `vehicles/`, `sales/`, `payments/`, `commissions/`, `reports/`, `logistics/`, `statements/`, `audit/`, `notifications/`
- TypeORM schema sync is `synchronize: true` — no manual migrations needed in dev; schema auto-updates on restart
- Role-based access via JWT guards and `@Roles()` decorators

### Mobile (Flutter + Provider + GoRouter)

- `mobile/lib/main.dart` — Entry point: calls `AuthProvider.tryAutoLogin()` before rendering (auto-login from stored token)
- `mobile/lib/app.dart` — `MaterialApp.router` with GoRouter and theme config
- `mobile/lib/core/services/api_service.dart` — Dio HTTP client with Bearer token injection and SharedPreferences token persistence
- `mobile/lib/core/providers/auth_provider.dart` — `ChangeNotifier` for login/logout state; listened to by GoRouter for redirect
- `mobile/lib/core/router/` — GoRouter routes; redirects unauthenticated users to login
- `mobile/lib/core/constants/api_constants.dart` — **Hardcoded production URL** (`https://backend-production-63d2.up.railway.app/api/v1`); change here for local dev
- Feature screens in `mobile/lib/features/<feature>/`; each feature has its own screens, providers, and may have local widgets

### Data Flow

```
Flutter screen → Feature Provider → ApiService (Dio) → NestJS Controller → Service → TypeORM Entity → PostgreSQL
```

Auth flow: Login → JWT stored in SharedPreferences → Dio interceptor attaches `Authorization: Bearer <token>` to every request

---

## Key Conventions

### Backend
- All API routes prefixed with `/api/v1`
- DTOs use `class-validator` decorators for request validation
- Controllers are thin; business logic lives in Services
- Commission rates are configurable via `.env` (`COMMISSION_RATE_*`) but can also be overridden per-entry

### Mobile
- Screens use `Consumer<Provider>` or `context.read/watch` for state
- API calls go through `ApiService` singleton (never raw Dio elsewhere)
- Platform-specific code (e.g., file download) uses conditional imports — see `reports/` feature for pattern

### CI/CD
- Push to `main` with changes in `backend/` → GitHub Actions deploys to Railway
- Push to `main` with changes in `mobile/` → GitHub Actions builds Flutter web and deploys to GitHub Pages
- Railway project ID: `02535877-8eca-4590-b0cd-1b8e87933708` (in workflow env)

---

## Environment Variables

Backend reads from `.env` at project root (copy `.env.example` → `.env`):

| Variable | Purpose |
|---|---|
| `DB_HOST/PORT/USERNAME/PASSWORD/NAME` | PostgreSQL connection |
| `JWT_SECRET` | Must be ≥32 chars random string |
| `JWT_EXPIRES_IN` | Token lifetime (e.g. `24h`) |
| `APP_PORT` | Backend listen port (default 3000) |
| `COMMISSION_RATE_DRIVER/GUIDE/LOCAL_AGENT/COMPANY` | Default commission % per role |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` | Optional notification alerts |
| `TWILIO_*` | Optional WhatsApp notifications |

Production secrets live in Railway (backend) and GitHub Secrets (CI).

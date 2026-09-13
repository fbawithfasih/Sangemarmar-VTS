# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Sangemarmar VTS** — operations app for a marble-handicraft showroom (S.K. Cottage Industries / The Sangemarmar, Agra). Flutter frontend (web + mobile) + NestJS REST API + PostgreSQL. After login, admins land on the admin dashboard, managers pick a module (`module_select`: VTS or Billing), and other roles go straight to the VTS dashboard.

Two product areas share one backend and database:

1. **Vehicle Tracking System (VTS)** — tour vehicles enter at the gate → a sale is recorded → commissions (driver, guide, local agent, company) → payments. Plus statements, reports, logistics timeline, notifications.
2. **Billing** (ADMIN/MANAGER only) — export **Orders** (order receipt voucher + invoice PDFs), **Hand Delivery** GST invoices (bulk upload, Excel report), a **product catalog** (`billing-products`), and **Shipping** labels/tracking via FedEx, DHL and UPS.

- **Backend**: Railway at `https://api.thesangemarmar.com` (Postgres 18 also on Railway)
- **Frontend web**: GitHub Pages at `https://vts.thesangemarmar.com` (static Flutter build)
- **DNS**: GoDaddy. `vts` and `api` are CNAMEs to GitHub Pages and Railway; the root domain and `www` are the Shopify store, so don't touch them
- **Local dev**: Docker Compose

---

## Commands

### Backend (`/backend`)

```bash
npm run start:dev             # Dev server with hot reload
npm run build                 # Compile TypeScript → dist/
npm start                     # Production (node dist/main)
npx tsc --noEmit -p tsconfig.json   # Type-check — the only working static check
npm run seed                  # Create the 5 default users (skips existing)
npm run seed:billing-products # Upsert the product catalog from src/scripts/billing-products.fixture.json
npm run migration:generate -- src/migrations/<Name>  # Diff entities vs DB → new migration
npm run migration:run         # Apply pending migrations (the app also runs them on startup)
npm run migration:revert      # Revert the last migration
```

`npm run lint` and `npm run test` are **broken**: ESLint and Jest are not installed and there are no tests. Verify changes with the type-check, `npm run build`, and by exercising the app.

### Mobile (`/mobile`)

```bash
flutter pub get
flutter run
flutter analyze
flutter test                  # PDF render + widget tests in mobile/test/
flutter build web --release --base-href "/"   # GitHub Pages build (custom domain, served from /)
```

### Local database

```bash
docker-compose up postgres    # Postgres on localhost:5433 (credentials from root .env)
cd backend && npm run seed
```

`npm run start:dev` and the migration CLI read **`backend/.env`** (current directory), so point `DB_PORT=5433` there. The compose `backend` service reads the **root** `.env`. The app runs pending migrations on startup, so an empty database gets the full schema on first boot.

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

### Backend (NestJS 10 + TypeORM 0.3 + PostgreSQL)

- `main.ts` — global `ValidationPipe` (`whitelist`, `forbidNonWhitelisted`, `transform`), CORS `*`, prefix `/api/v1`, `GET /api/v1/health` (Railway healthcheck), port from `PORT` then `APP_PORT`
- `app.module.ts` — imports all feature modules; TypeORM options come from `database/typeorm-options.ts`
- Feature modules: `auth`, `users`, `vehicles`, `sales`, `payments`, `commissions`, `reports`, `logistics`, `statements`, `audit`, `notifications`, `billing`, `hand-delivery`, `billing-products`, `shipping`
- Controllers are thin; business logic lives in services. Most writes also call `AuditService.log()` and, for non-admin actors, `NotificationsService.create()` (stored + optional Telegram/WhatsApp)

**Database & migrations**
- `synchronize` is **off everywhere**. Schema changes go through migrations in `src/migrations/`: change the entity, run `migration:generate` against a local DB, review the SQL, commit it. Pending migrations run on startup (`migrationsRun: true`), including on Railway
- `database/typeorm-options.ts` is shared by the app and the CLI (`database/data-source.ts`); **new entities must be added to `ENTITIES`** there. Uses `DATABASE_URL` if set (Railway), otherwise `DB_*`
- `InitialSchema` is the baseline of the pre-migration schema: it no-ops when tables exist, and its `down()` refuses to run unless `ALLOW_BASELINE_REVERT=true`
- Multi-step writes that must stay consistent use `repo.manager.transaction(...)` (see billing/hand-delivery `create`, `payments.service.ts`)

**Auth & roles**
- JWT (`passport-jwt`); `JwtStrategy` caches the user for 60s. Guard with `@UseGuards(JwtAuthGuard, RolesGuard)` + `@Roles(...)`; a method-level `@Roles` overrides the class-level one
- Rough access map: users/admin dashboard → ADMIN; billing, hand-delivery, products, shipping, notifications, statements, commissions → ADMIN/MANAGER (deletes ADMIN only); sales create/edit → SALES_STAFF/MANAGER/ADMIN; payments create → CASHIER/MANAGER/ADMIN; reports → ADMIN/MANAGER/SALES_STAFF (sales staff scoped to their own name)
- Row-level rules live in services: SALES_STAFF/CASHIER may only set a vehicle to `NO_SALE` before a sale exists (`VehiclesService.changeStatus`); SALES_STAFF see commissions only on their own sales (`CommissionsService.findBySaleForUser`)

**VTS workflow** (`WorkflowStatus` in `common/enums`)
- Vehicle entry → `ENTERED`; creating a sale → `SALES_COMPLETE` and creates 4 commission rows
- Payments are capped at the sale's `grossSale` (row-locked). A part payment → `PAYMENT_PENDING`; full payment → `COMPLETED` (or `PAYMENT_COMPLETE` if no commissions). Managers can also set `COMPLETED` manually. Editing `grossSale` can't go below the paid total and re-evaluates the status (`SalesService.syncPaymentStatus`), but never reopens a vehicle a manager completed while part-paid
- Commissions are created at **rate 0 / ₹0** and set by a manager via override. Default rates live in the `commission_configs` table (seeded on boot, edited via `PUT /commissions/config`) — they are not applied automatically, and there are no `COMMISSION_RATE_*` env vars

**Billing**
- Invoice numbers come from `common/invoice-number.ts`: `SKC/NNN/YY-YY` (orders) and `SKC-HD/NNN/YY-YY` (hand delivery), next = highest existing + 1 for the Indian financial year computed in IST, under an advisory lock. Must be called inside the transaction that inserts the order
- Hand Delivery amounts are GST-inclusive; taxable value and GST are back-calculated per item (`gstRate` per product, default 5%). `invoiceType` decides IGST vs CGST+SGST
- PDFs are built with PDFKit in the services (company details are hardcoded in `billing.service.ts`); the Flutter app also renders its own PDFs (`features/billing/*_pdf.dart`)
- Shipping uses one adapter per carrier (`shipping/adapters/`, `ICarrierAdapter`); each defaults to its sandbox API unless `<CARRIER>_SANDBOX=false`

### Mobile (Flutter + Provider + GoRouter)

- `main.dart` calls `AuthProvider.tryAutoLogin()` before `runApp`; `app.dart` sets up `MaterialApp.router`
- `core/router/app_router.dart` — all routes; redirects unauthenticated users to `/login`, and after login ADMIN → `/admin-dashboard`, MANAGER → `/module-select`, others → `/dashboard`
- `core/services/api_service.dart` — Dio singleton; attaches `Authorization: Bearer <token>` from SharedPreferences. A 401 on any request except login calls `ApiService.onUnauthorized` (wired in `main.dart`): `AuthProvider.expireSession()` clears the token and the app navigates to `/login` with a "session expired" message
- `core/constants/api_constants.dart` — **hardcoded production API URL**; change it for local dev
- `core/models/user.dart` — role getters (`isManager` includes ADMIN; `canViewCommissionsOn(...)` etc.). Keep these in sync with backend role rules so the UI never offers an action the API rejects
- Screens live in `features/<feature>/` and call `ApiService` directly with local `setState` — there are no per-feature providers. Only `AuthProvider` is global
- File downloads use conditional imports: `core/utils/platform_file_saver.dart` / `platform_file_saver_web.dart` via `download_helper.dart`

### Data flow

```
Flutter screen → ApiService (Dio) → NestJS controller → service → TypeORM repository → PostgreSQL
```

---

## CI/CD

- **Backend**: Railway's GitHub integration builds the multi-stage backend Dockerfile (the image ships only `dist/`, so migrations must live under `src/`) and deploys on push to `main`; healthcheck `GET /api/v1/health` (`railway.json`). Railway project ID `02535877-8eca-4590-b0cd-1b8e87933708`. There is no GitHub Actions workflow for the backend
- **Web**: `.github/workflows/deploy-web.yml` builds Flutter web and deploys to GitHub Pages on push to `main` touching `mobile/**`. `mobile/web/CNAME` keeps the `vts.thesangemarmar.com` custom domain on every deploy
- The repo root also contains an old, gitignored Flutter web build (`main.dart.js`, `canvaskit/`, …) — not used by CI

---

## Environment Variables (backend)

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Postgres URL (Railway); SSL enabled. If unset, `DB_HOST/PORT/USERNAME/PASSWORD/NAME` are used |
| `JWT_SECRET` | ≥32 random chars |
| `JWT_EXPIRES_IN` | Token lifetime (default `24h`) |
| `PORT` / `APP_PORT` | Listen port (`PORT` wins; Railway sets it) |
| `NODE_ENV` | `development` enables TypeORM query logging |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | Optional Telegram alerts for notifications |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_WHATSAPP_FROM`, `TWILIO_WHATSAPP_TO` | Optional WhatsApp alerts |
| `FEDEX_CLIENT_ID`, `FEDEX_CLIENT_SECRET`, `FEDEX_ACCOUNT_NUMBER`, `FEDEX_SANDBOX` | FedEx API |
| `DHL_API_KEY`, `DHL_API_SECRET`, `DHL_ACCOUNT_NUMBER`, `DHL_SANDBOX` | DHL API |
| `UPS_CLIENT_ID`, `UPS_CLIENT_SECRET`, `UPS_ACCOUNT_NUMBER`, `UPS_SANDBOX` | UPS API |
| `SHIPPER_NAME/ADDRESS/CITY/STATE/ZIP/COUNTRY/PHONE` | Shipper details on labels (defaults to The Sangemarmar, Agra) |
| `ALLOW_BASELINE_REVERT` | Only for deliberately reverting `InitialSchema` on a throwaway DB |

Production values live in Railway variables; GitHub Pages needs no secrets.

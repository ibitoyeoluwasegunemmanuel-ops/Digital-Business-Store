# Digital Business SaaS

Production-oriented foundation for a multi-tenant digital storefront and QR ordering SaaS.

## Stack
- Next.js + React + TypeScript
- Supabase Auth + Postgres + RLS + Storage
- Vercel deployment target
- GitHub source control
- Paystack planned behind a payment abstraction

## Account model
There are only two public signup paths:
1. Business owner
2. Customer

Platform admin has **no public signup**. Admin access is intended to be granted through protected `app_metadata.platform_admin` configuration and checked server-side.

## Current implemented foundation
- Marketing landing page
- Business/customer signup
- Sign in + forgot password + reset password
- Authenticated dashboard routing
- Server-side business creation with membership creation
- Multi-tenant RLS foundation
- Vendor dashboard with live business/product/order reads
- Product creation API and dashboard modal
- Public published storefront with active catalogue
- Draft/unavailable storefront state
- Admin authentication gate
- Legal pages

## Not production-ready yet
Core checkout, Paystack initialization/webhooks, QR/location flows, media upload API, subscription foundation, notification inbox, staff invitations, analytics, and protected admin business controls are implemented. Production provider configuration, email/WhatsApp delivery, full end-to-end QA, deployment, and legal review remain.

## Security rules
- Never trust client-supplied totals, payment status, role or business ownership.
- Do not store raw card details.
- Public checkout must create orders through a server-side/RPC flow that recalculates product prices from the database.
- Payment webhooks are authoritative for payment state.
- RLS must remain enabled and tenant isolation must be tested before launch.
- Legal documents require professional Nigerian legal review before commercial launch.

## Local setup
Copy `.env.example` to `.env.local` and provide Supabase project credentials.

Then:
```bash
npm install
npm run dev
```

Apply `supabase/schema.sql` to a Supabase project before using the dashboard.

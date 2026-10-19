# LeadFlow AI — Rebuild v2

LeadFlow AI is a lead-management and automation MVP for real-estate teams. This branch rebuilds the product against the original 504-line master specification.

## Current phase
Phase 1–3 are in progress: responsive UI, Base44-compatible lead model, CRUD-style local workflow, dashboard metrics, search/filter, duplicate warnings, CSV export, follow-up queues, settings and 10 fictional Lagos demo leads.

## Run
```bash
npm install
npm run dev
npm run build
```

## Architecture
The current branch deliberately retains browser persistence while the shared backend/auth layer is being added. Local storage is demo-only and is not represented as a secure multi-user database.

Target connected-mode architecture:
- React/TypeScript frontend
- authenticated shared relational database with per-user access controls
- server-side Gemini processing via `GEMINI_API_KEY`
- server-side n8n webhook proxy via `N8N_WEBHOOK_URL`
- public intake only after shared persistence exists
- human approval before any outbound reply

## Safety
No external AI or webhook success is fabricated. The current AI helper is a clearly labelled deterministic demo fallback. No reply is auto-sent.

## Remaining acceptance work
- shared database + authentication/access controls
- date/category/priority/status dashboard filters and lead sorting
- stricter email validation and duplicate-review UX
- public intake form backed by shared storage
- real server-side Gemini endpoint and structured response validation
- real n8n proxy, timeout, idempotency and connection-result tracking
- demo-only clearing without deleting real records
- documentation for AI, n8n, deployment and acceptance testing
- run and record the full 20-item acceptance checklist

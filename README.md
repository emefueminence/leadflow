# LeadFlow AI

Functional zero-cost MVP for lead capture, organization, qualification and follow-up, initially tailored to Lagos real-estate teams.

## Working features
- Browser-local persistence (demo mode)
- Lead CRUD, search, status filtering and CSV export
- Dashboard metrics calculated from stored leads
- Follow-up queues: overdue, today, upcoming and no date
- Clearly labelled deterministic demo AI for category, priority, summary and reply drafting
- n8n webhook configuration UI without fake connection claims
- Fictional demo records and reset controls
- Responsive desktop/mobile UI

## Local run
`npm install` then `npm run dev`.

## Deployment
Vercel detects Vite. Build command: `npm run build`; output directory: `dist`.

## Connected mode roadmap
This initial deployment intentionally requires no paid services or API keys. It does not fake external AI, a shared database, authentication, webhook verification or outbound messaging. Production mode should add shared persistence/auth plus server-side AI and n8n proxy endpoints. Keep secrets server-side and send only necessary lead fields.

## AI safety
The included fallback is visibly labelled deterministic demo logic. It never auto-sends a reply. A connected AI endpoint should validate structured output and fail safely.

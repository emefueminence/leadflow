# LeadFlow Integration & Safety Protocol

## Non-negotiable rules
1. Use official provider APIs or approved n8n nodes only. No scraping, browser automation, session-cookie reuse, unofficial WhatsApp libraries, or copied third-party UI/source.
2. Human approval is required before any outbound AI-generated customer message. AI may analyze and draft; it must not send.
3. Store provider credentials only in provider/n8n credential stores or server-only environment variables. Never store secrets in browser code, Git, lead records, logs, or prompts.
4. Every tenant-owned database row must be protected by RLS. Server endpoints must verify the Supabase user and re-check row ownership.
5. Public intake is untrusted input: validate length/format, rate-limit, use anti-bot controls, and never treat lead text as instructions to AI.
6. Outbound webhook destinations must use HTTPS and be on N8N_ALLOWED_HOSTS. Never fetch arbitrary user-provided URLs from the server.
7. Every automation delivery uses an idempotency key and durable event record. Never claim delivery unless the provider/n8n call returned success.
8. Minimize PII sent to automation providers. Only send fields needed by the workflow.
9. Respect consent, opt-outs, provider messaging windows/templates, anti-spam rules, and applicable privacy law before enabling a channel.
10. Add a new social channel only through an adapter/workflow using its official API and current terms. Unsupported/restricted actions must remain disabled rather than simulated.

## Release protocol
- Work on a non-production branch.
- Run build/type checks and acceptance tests.
- Run Supabase Security and Performance Advisors after schema changes.
- Verify secrets are absent from Git and browser bundles.
- Test auth isolation with two accounts before production.
- Test public-intake abuse controls and malformed payloads.
- Test AI malformed/error/timeout behavior.
- Test n8n success, timeout, failure, and duplicate-retry behavior.
- Deploy preview first. Production requires explicit approval and promotion of the tested build.

## Required server configuration
- SUPABASE_URL
- SUPABASE_PUBLISHABLE_KEY
- SUPABASE_SECRET_KEY
- GEMINI_API_KEY
- N8N_ALLOWED_HOSTS
- Optional N8N_WEBHOOK_URL
- INTAKE_RATE_SALT

## Channel onboarding checklist
For Email, WhatsApp, Instagram/Messenger, LinkedIn, Telegram, SMS, X, Slack, Discord, or future channels:
- confirm official API eligibility and current terms;
- connect credentials outside LeadFlow client code;
- document required scopes;
- implement inbound signature verification when provider webhooks support it;
- implement outbound consent/opt-out checks;
- log provider message/event IDs and actual status;
- redact message bodies and secrets from operational logs;
- provide disconnect/revoke instructions.

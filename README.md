# LeadFlow AI — organization-first rebuild

LeadFlow AI is being developed as a configurable, multi-tenant business relationship, lead-management and workflow automation platform. It is designed to support solo operators, small businesses, mid-sized companies and enterprise organizations across different industries and business models.

## Product foundation
- Universal lead, contact, opportunity, task and follow-up workflows.
- Configurable pipelines, stages and industry-specific templates.
- Organization, division, department, business unit, branch, team and individual scopes.
- Role-based permissions combined with record-level access scopes.
- AI assistance and automation that respect tenant boundaries.
- Human approval before any AI-generated outbound message is sent.

## Development status
The current rebuild-v2 branch contains the existing LeadFlow app and server-side AI/automation work. The UI still contains legacy real-estate-specific fields and is being generalized. The additive organization-first database migration is under supabase/migrations; it must be applied and verified in a non-production database before the app is switched to organization-aware queries.

## Run
```
npm install
npm run dev
npm run build
```

## Architecture
- React + TypeScript frontend.
- Supabase Auth and PostgreSQL with RLS.
- Organization-scoped memberships, teams, organizational units and settings.
- Server-side Gemini processing.
- Server-side n8n workflow proxy with allowlisting, timeout and idempotency.
- Configurable workflows and custom fields.
- Human review before outbound communication.

## Security and rollout
See docs/ORGANIZATION_ARCHITECTURE.md and docs/SECURITY_AND_INTEGRATION_PROTOCOL.md.

Production remains on main. Do not merge or deploy organization schema changes to production without explicit approval and successful preview acceptance tests.

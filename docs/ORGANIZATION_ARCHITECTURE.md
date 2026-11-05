# LeadFlow AI — organization-first architecture

## Product definition
LeadFlow is a configurable, multi-tenant business relationship, lead and workflow platform. It is not tied to real estate or any single sales motion. The common product core is contacts, leads, opportunities, tasks, follow-ups, communication history, pipelines, automation, AI assistance and analytics. Industry-specific fields and workflow templates are configuration, not assumptions in the core schema.

## Supported operating models
- Solo: one person and one workspace; teams and departments remain optional.
- Small business: owner, employees and optional teams.
- Mid-sized company: departments, branches, business units and multiple teams.
- Enterprise: divisions, subsidiaries, locations and nested organizational units.

organizations.company_size is descriptive and must not be used as an authorization boundary. Actual plan limits and entitlements are enforced separately from company size.

## Tenant and organization model
- organizations: tenant boundary and workspace profile.
- org_memberships: user-to-organization relationship, role, status and access scope.
- org_units: hierarchical divisions, departments, business units, branches or locations.
- teams: working groups within an organization unit.
- team_memberships: many-to-many team membership.
- organization_settings: organization-wide locale, currency, preferences and integration configuration.
- pipelines / pipeline_stages: configurable business workflows.
- custom_field_definitions: tenant-defined fields for supported business objects.
- leads: tenant-owned records with optional owner, team, organizational unit, pipeline, stage and custom fields.
- automation_events: tenant-scoped event history.

Existing user_id, settings, and lead-specific columns are intentionally retained as a compatibility layer during migration. Do not remove them until the application and server APIs use organization context end-to-end and regression tests pass.

## Access scopes
- organization: all records in the organization.
- unit: records assigned to the selected unit and its descendants.
- team: records assigned to a team the user belongs to.
- personal: records owned by the user.

Default roles are owner, org_admin, manager, team_lead, employee and viewer. Roles describe capabilities; access_scope describes which records those capabilities apply to. Do not infer authorization from company size, email domain, user-editable metadata, UI visibility or a client-supplied organization ID.

## Security invariants
1. Every tenant-owned record has an organization_id.
2. Every foreign key connecting tenant-owned records must include organization_id, preventing cross-tenant references.
3. RLS is enabled on all exposed tenant tables.
4. Authorization derives from auth.uid() and active org_memberships; never from raw_user_meta_data.
5. The browser may select an active organization, but the server and RLS must independently verify membership and scope.
6. Organization administrators can manage membership and structure. Regular members cannot promote themselves or grant broader scope.
7. AI context and automation payloads are restricted to records the requesting user is allowed to access.
8. Outbound AI-generated messages remain drafts until a human explicitly approves them.
9. Provider credentials remain server-side or in the provider's credential vault.
10. Company size and subscription tier are separate concepts.

## Industry-neutral data model
Do not require property type, preferred location, buying/renting/selling category, or budget for every lead. Preserve legacy columns for existing records, but introduce generic fields such as record type, source, need/interest, estimated value, currency, target date, pipeline and custom_fields. Industry templates may add optional labels and fields without changing the tenant model.

## Workflow examples
- Real estate: Enquiry → Viewing → Negotiation → Won/Lost.
- E-commerce: Enquiry → Order → Payment → Fulfilment.
- Agency: Prospect → Discovery → Proposal → Contract.
- Education: Enquiry → Application → Admission → Enrolment.
- Consulting: Lead → Consultation → Proposal → Engagement.

These are configurable templates, not hard-coded global stages.

## Migration and rollout sequence
1. Apply and verify the additive organization foundation migration in a non-production database.
2. Backfill and reconcile every existing lead, settings row and automation event to one legacy workspace per user.
3. Verify RLS isolation with at least two organizations and users, including organization, unit, team and personal scope tests.
4. Add organization selection and workspace onboarding to the UI; existing accounts should land in their backfilled workspace.
5. Update CRUD, AI, public intake and automation APIs to require and verify organization context.
6. Replace real-estate-only labels with configurable fields and pipeline templates.
7. Add invitation, membership, role and organizational-structure management.
8. Add audit history, plan entitlements, usage metering and enterprise administration.
9. Remove legacy compatibility only after all acceptance tests pass.

## Release guardrails
- Work only on rebuild-v2 until explicit production approval.
- Never claim a migration, build, integration or test passed without observing the successful result.
- Do not apply the migration to production while the preview database is unavailable or schema assumptions remain unverified.
- Do not expose Supabase secret keys, Gemini keys, n8n credentials or access tokens to the browser.

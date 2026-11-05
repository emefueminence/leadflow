# LeadFlow AI — Organization Architecture Implementation Status

## Branch and release boundary
- Working branch: `rebuild-v2`
- Production branch: `main`
- Do not merge to `main` or promote a preview to production without explicit user approval.
- Supabase project is shared by the connected LeadFlow deployment. Schema changes are additive; do not drop existing user/lead data.

## Database foundation
The organization migration is recorded in Supabase migration history as `20261105233148_multi_tenant_organization_foundation`.

Core tables:
- `organizations`
- `org_memberships`
- `org_units`
- `teams`
- `team_memberships`
- `organization_settings`
- `pipelines`
- `pipeline_stages`
- `custom_field_definitions`
- `accounts`
- `contacts`
- `opportunities`
- `tasks`
- `activities`

Legacy `leads`, `settings`, and `automation_events` remain in place and now carry `organization_id`. Lead records also carry owner, team, unit, pipeline, stage, and custom field data.

## Organization model
- Company-size profiles: solo, small, medium, large, enterprise.
- Industry and business model are organization-configurable.
- Organization units support divisions, departments, branches, subsidiaries, locations, and business units.
- Teams can be attached to organization units.
- Users have organization memberships and can have scoped access: organization, unit, team, or personal.
- Roles: owner, org_admin, manager, team_lead, employee, viewer.
- A user can belong to multiple workspaces.
- New signups automatically receive a personal workspace, owner membership, default lead pipeline/stages, and organization settings.

## Application features implemented on rebuild-v2
- Organization profile and company-size configuration.
- Create another workspace.
- Create nested organizational units and teams.
- Invite new users with role and personal/team/unit/organization scope.
- Configure pipelines, add stages, and choose the default pipeline.
- Define custom fields for leads, contacts, opportunities, accounts, tasks, and activities.
- Create leads with workspace pipeline/stage and custom fields.
- Accounts, contacts, opportunities, tasks, and activity screens with organization ownership and scoped access.
- Custom-field definitions and inputs for leads and the other business record types.
- Workspace switcher for users belonging to multiple organizations.
- Industry-neutral AI lead analysis.
- Organization-aware AI and n8n endpoints.
- Public intake attaches new leads to the correct organization.

## Authorization and security
- RLS is enabled on organization-owned tables.
- Tenant-owned rows use organization ownership.
- Lead visibility is enforced by organization membership and personal/team/unit scope.
- Server endpoints using the service-role client verify organization membership and record access independently.
- Tenant reassignment is blocked by database triggers.
- Team membership requires an active organization membership.
- Organization-unit hierarchy cycles are rejected.
- AI replies remain drafts; human approval is required before outbound sending.
- n8n webhook destinations remain HTTPS-only and host-allowlisted.
- No provider integration is reported as connected unless verified.

## Verification completed
- Signup bootstrap trigger tested inside a transaction; it created the expected organization, owner membership, default pipeline, six stages, and settings, then the test rows were rolled back.
- Two-tenant RLS test confirmed a second tenant could not read the first tenant's organization or lead.
- Scope test confirmed team access saw only team records, unit access saw records in its department and child units, and personal access saw only personally assigned records.
- Supabase performance advisor reported no unindexed foreign keys; remaining notices are unused-index INFO findings on empty tables.
- Supabase security advisor returned no security findings after the organization foundation.
- Existing preview build at commit `62c338243ebce74df1299f7599da8abed6dd3d3b` reached READY.
- Vercel preview build for commit `93f33b07992ad7c6cabe2f96dc882a5877bf0243` reached READY.
- The deployed `/api/status` check returned Supabase configured, Supabase Auth reachable (HTTP 200), Gemini configured, the intake-rate salt present, and the n8n host allowlist present. The n8n webhook URL is not configured in server environment variables; per-workspace settings may still provide one.

## Not yet verified / next work
- Complete browser signup/login and first-workspace onboarding with the user; the previous browser reported `Failed to fetch`. Server-side Auth is reachable (HTTP 200), so the remaining login check must be performed in the browser against the current preview to distinguish browser/network/CORS issues from client configuration.
- End-to-end create/read/update tests for each business-record module.
- Invite email delivery and acceptance; depends on Supabase Auth email configuration.
- Existing-account invitation/adding, member role changes, removal, and bulk team assignment.
- Full audit history and organization-level analytics.
- Automation templates, scheduled task workflows, provider integrations, billing/plan entitlements, and enterprise SSO.
- Update the checked-in migration source to match the exact applied schema before using a clean local reset workflow.

## Current data state
A read-only count check returned zero auth users, organizations, leads, accounts, contacts, opportunities, tasks, and activities. The temporary test users and records used for trigger and RLS tests were rolled back. No customer records were created or altered.

## Important
The database and application foundation is implemented, but this is not yet a production release. Keep all work on `rebuild-v2` until end-to-end acceptance tests pass and the user explicitly approves production promotion.

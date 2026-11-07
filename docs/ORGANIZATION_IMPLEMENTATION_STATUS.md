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


## Enterprise onboarding and supervisor update (2026-11-05)
- Signup now captures organization name, industry, business model, company size, currency, branch count, and department count.
- Signup explicitly sets `emailRedirectTo` to the current website origin.
- The signup bootstrap trigger saves organization metadata, applies the chosen currency, and creates the requested number of initial branch and department units.
- Password visibility toggle added to authentication form.
- Invitation role label `Supervisor (read-only)` maps to the `viewer` role.
- Database write policies now prevent viewer-role users from inserting, updating, or deleting business records; AI and automation endpoints also reject viewer-role requests.
- Dashboard includes department-level lead conversion metrics (Won / visible leads), based on actual RLS-visible records.
- Transactional database test exercised signup metadata initialization and confirmed a viewer could read an assigned organization record but could not update or insert; all temporary test users/records were rolled back.
- Latest preview deployment for commit `f763966a5d3c6465cc0a109223d065310ae181bf` reached READY. Public app HTML returned HTTP 200 and `/api/status` confirmed Supabase Auth HTTP 200, Gemini configured, and intake rate-limit salt configured.
- Manual Supabase Auth URL Configuration remains necessary: set the Site URL to the stable preview URL for this testing phase and add the preview and production domains to Redirect URLs. Change Site URL to the production domain only when production is approved.
- Supabase security advisor currently reports leaked-password protection disabled; enable this in Auth password security settings before production.


## Existing-account linking and workspace currency (2026-11-06)
- Organization invitations now look up an existing Supabase Auth account by email. Existing users can be added to a workspace without creating a second login; new users still receive an email invitation.
- Existing active memberships are detected and rejected with a clear conflict rather than duplicated.
- Team-scoped invitations also create the corresponding team-membership row.
- The Members tab now distinguishes an existing-account addition from an email invitation in its success message.
- Additional workspace creation now accepts a primary currency and persists it to both organization settings and the legacy workspace settings row.
- Opportunity creation and value display now use the active workspace currency rather than hard-coded NGN.
- Vercel preview build for commit `a419023b8b0878e5f59c47642855918d2b6442fe` reached READY. Build output confirms Vite transformed 2,122 modules and completed successfully.
- The remaining high-priority work is end-to-end acceptance testing with real signup, existing-account invitation, role/scope isolation, and CRUD across accounts, contacts, opportunities, tasks and activities. No production deployment or merge was performed.


## Organization audit history (2026-11-07)
- Added `public.audit_logs` with organization-scoped RLS. Read access is restricted to active owners, organization admins and managers; direct client insert/update/delete is denied.
- Added a SECURITY DEFINER trigger function that records INSERT, UPDATE and DELETE events for leads, accounts, contacts, opportunities, tasks, activities, memberships, organizational units, teams, pipelines, pipeline stages, custom-field definitions, organizations and organization settings.
- Audit events capture actor ID, action, entity/table, record ID, optional unit/team scope, timestamp and changed field names. They intentionally do not store old/new values, customer names, email addresses, phone numbers or message content.
- Added Organization → Audit history with action filters and search. UI is available to owners, admins and managers; database RLS remains the enforcement boundary.
- Database transaction test created, updated and deleted a temporary account, verified exactly three ordered audit events and confirmed the record label did not expose its business name; test rolled back all test data.
- Preview deployment `dpl_DqGc7eGK6s7735EvJuGivmgjqoWJ` reached READY for commit `db990867a2b2637cec874f39c4a9705cbc2b0f8f`. Preview root and `/api/status` returned HTTP 200; status reports Supabase and Auth reachable, Gemini configured, and intake rate-limit salt configured.
- Security advisor currently reports only the previously known warning that leaked-password protection is disabled. Production remains untouched.


## Enterprise analytics upgrade (2026-11-07)
- Rebuilt the Analytics workspace page with six-month trend charts for lead creation, won opportunities and completed tasks.
- Added KPIs for accessible leads and conversion, opportunities, won opportunity value, open pipeline value, task completion and recorded activities.
- Added branch/department comparison table with lead conversion and task completion rates plus won opportunity value; added team performance and individual workload/output views.
- Added period, organizational unit and team filters plus CSV export.
- Restricted unit/team comparison options in the UI to the membership's organization, unit subtree or assigned team. Underlying data remains fetched through the authenticated Supabase client and filtered by database RLS; UI filters never grant access.
- Analytics queries now paginate in 1,000-row pages up to 10,000 rows per record category rather than silently relying on a single PostgREST response page. A cap warning is displayed when a category reaches the limit.
- Opportunity monetary totals only aggregate values in the active workspace currency. Other currencies are excluded and disclosed; no exchange rate is fabricated.
- Profit is explicitly not calculated because no cost/expense ledger exists yet. Won opportunity value is labelled as opportunity value, not accounting revenue.
- Vercel preview deployment `dpl_2DeAECZz3JMGfmn9KWo871o6bxwZ` reached READY for commit `37b8e6b2a3d9684bbc927e6e0947d4bb07d07ae9`; preview root and `/api/status` returned HTTP 200. The compiled application bundle contains the new analytics sections.
- No database schema changes, production deployment, or merge to `main` were performed.

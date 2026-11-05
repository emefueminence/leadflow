# LeadFlow AI acceptance checklist

Do not mark an item passed unless it was actually verified in the target preview deployment and database.

## Existing application
- [ ] App opens without runtime error
- [ ] Main navigation works
- [ ] Sign-up, email confirmation and sign-in work
- [ ] Lead creation, edit and delete work
- [ ] Search, filters and CSV export are correct
- [ ] Dashboard metrics update from saved records
- [ ] Required-field validation is understandable
- [ ] Duplicate contacts trigger a warning
- [ ] Overdue follow-ups are grouped correctly
- [ ] AI failure cannot destroy or duplicate records
- [ ] AI content is marked as generated and remains a draft
- [ ] n8n reports real delivery results only
- [ ] Demo controls cannot delete non-demo records
- [ ] Mobile layout remains usable
- [ ] No private key is exposed in frontend code

## Organization onboarding and tenant boundaries
- [ ] Existing user receives exactly one backfilled organization
- [ ] New signup receives a default organization and owner membership
- [ ] User can belong to more than one organization
- [ ] Organization switcher changes the active workspace
- [ ] Solo workspace works without requiring departments or teams
- [ ] Small business can create teams and invite employees
- [ ] Medium organization can create divisions, departments and branches
- [ ] Enterprise organization can nest units and assign multiple teams
- [ ] Company size is informational and does not grant permissions
- [ ] One tenant cannot read, update, delete or reference another tenant's rows
- [ ] Cross-tenant foreign-key references are rejected
- [ ] Suspended memberships lose access
- [ ] Removing a membership does not expose its records
- [ ] Last active organization owner cannot be removed or demoted

## Role and scope authorization
- [ ] Owner can administer the entire organization
- [ ] Organization admin can manage regular members but cannot grant owner/admin roles
- [ ] Manager can access only their assigned unit and descendants
- [ ] Team lead can access only assigned team records
- [ ] Employee with personal scope can access only owned records
- [ ] Viewer cannot create, update or delete records
- [ ] Client-side organization IDs cannot bypass server authorization
- [ ] AI endpoint respects the same record scope as the UI
- [ ] Automation endpoint respects the same record scope as the UI
- [ ] Public intake cannot choose or overwrite organization ownership

## Industry and workflow flexibility
- [ ] No real-estate-specific field is mandatory for a generic business
- [ ] A business can configure its own lead labels and custom fields
- [ ] A business can create multiple pipelines
- [ ] Pipeline stages can be renamed, reordered and assigned open/won/lost outcomes
- [ ] E-commerce, agency, education and service workflows can be configured without code changes
- [ ] Existing real-estate records remain readable after migration

## Integrations and release
- [ ] AI failure, timeout and malformed output are handled safely
- [ ] n8n success, failure, timeout and duplicate event cases are tested
- [ ] Human approval is required before outbound AI messages
- [ ] Integration secrets remain server-side
- [ ] Supabase security advisor is clean after migration
- [ ] Two-organization RLS isolation tests pass
- [ ] Build and type checks pass
- [ ] Preview deployment is verified before any production release

## Current verification status
The organization schema and rollout documents have been committed to rebuild-v2. The Supabase database connection timed out during inspection, so the migration has **not** been applied or verified. All organization-specific checklist items remain unverified until the database is reachable and tests are executed.

# Supabase migrations

The connected Supabase project currently records the organization foundation as migration version `20261105233148` (`multi_tenant_organization_foundation`).

The earlier draft is archived at `docs/archive/ORGANIZATION_FOUNDATION_MIGRATION_DRAFT.md` and is **not executable**.

Before using Supabase CLI reset/push workflows, reconstruct the exact live schema and policies with `supabase db pull`, review the generated migration, and commit it here. Do not run the archived draft. The live schema has received additive follow-up changes (scoped authorization, accounts/contacts/opportunities/tasks/activities, custom fields, and related constraints/indexes) after the recorded foundation migration.

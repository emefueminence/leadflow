-- Scoped read-only supervisor access and permission hardening.
-- This migration is safe to reapply after direct SQL verification: policy names
-- are dropped before recreation, grants are idempotent, and functions use OR REPLACE.

-- Allow the "Supervisor (read-only)" viewer role to preview HR records in
-- its assigned organization/unit/team. Existing HR mutation policies remain
-- admin/self-only, so this function grants no write permission.
create or replace function private.can_manage_hr_record(
  p_org uuid,
  p_unit uuid,
  p_team uuid,
  p_user uuid
)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.org_memberships m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and (
        m.role in ('owner', 'org_admin')
        or (
          m.role in ('manager', 'team_lead', 'viewer')
          and (
            m.access_scope = 'organization'
            or (m.access_scope = 'unit' and p_unit = m.org_unit_id)
            or (m.access_scope = 'team' and p_team = m.team_id)
            or p_user = m.user_id
          )
        )
      )
  );
$function$;

revoke all on function private.can_manage_hr_record(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function private.can_manage_hr_record(uuid, uuid, uuid, uuid) to authenticated;

-- Grant authenticated access to the module tables. RLS continues to restrict
-- rows and operations. The intake rate-limit table remains service-only.
grant select, insert, update, delete on public.attendance_records,
  public.employee_profiles, public.leave_requests, public.performance_reviews,
  public.finance_budgets, public.finance_transactions,
  public.project_milestones, public.projects to authenticated;
grant select on public.audit_logs to authenticated;

-- Managers can read audit events only within their assigned data scope.
drop policy if exists audit_logs_read_management on public.audit_logs;
create policy audit_logs_read_management on public.audit_logs
for select to authenticated
using (
  private.is_org_admin(organization_id)
  or (
    actor_user_id is not null
    and exists (
      select 1 from public.org_memberships m
      where m.organization_id = audit_logs.organization_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
        and m.role = 'manager'
    )
    and private.can_access_lead(
      organization_id, actor_user_id, org_unit_id, team_id
    )
  )
);

-- Replace broad ALL policies: USING(member) also allowed DELETE. Members
-- keep read access, while only owners/admins can mutate workspace structure.

drop policy if exists custom_fields_access on public.custom_field_definitions;
drop policy if exists custom_fields_select_member on public.custom_field_definitions;
drop policy if exists custom_fields_insert_admin on public.custom_field_definitions;
drop policy if exists custom_fields_update_admin on public.custom_field_definitions;
drop policy if exists custom_fields_delete_admin on public.custom_field_definitions;
create policy custom_fields_select_member on public.custom_field_definitions
for select to authenticated using (private.is_org_member(organization_id));
create policy custom_fields_insert_admin on public.custom_field_definitions
for insert to authenticated with check (private.is_org_admin(organization_id));
create policy custom_fields_update_admin on public.custom_field_definitions
for update to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));
create policy custom_fields_delete_admin on public.custom_field_definitions
for delete to authenticated using (private.is_org_admin(organization_id));

drop policy if exists org_units_access on public.org_units;
drop policy if exists org_units_select_member on public.org_units;
drop policy if exists org_units_insert_admin on public.org_units;
drop policy if exists org_units_update_admin on public.org_units;
drop policy if exists org_units_delete_admin on public.org_units;
create policy org_units_select_member on public.org_units
for select to authenticated using (private.is_org_member(organization_id));
create policy org_units_insert_admin on public.org_units
for insert to authenticated with check (private.is_org_admin(organization_id));
create policy org_units_update_admin on public.org_units
for update to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));
create policy org_units_delete_admin on public.org_units
for delete to authenticated using (private.is_org_admin(organization_id));

drop policy if exists stages_access on public.pipeline_stages;
drop policy if exists stages_select_member on public.pipeline_stages;
drop policy if exists stages_insert_admin on public.pipeline_stages;
drop policy if exists stages_update_admin on public.pipeline_stages;
drop policy if exists stages_delete_admin on public.pipeline_stages;
create policy stages_select_member on public.pipeline_stages
for select to authenticated using (private.is_org_member(organization_id));
create policy stages_insert_admin on public.pipeline_stages
for insert to authenticated with check (private.is_org_admin(organization_id));
create policy stages_update_admin on public.pipeline_stages
for update to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));
create policy stages_delete_admin on public.pipeline_stages
for delete to authenticated using (private.is_org_admin(organization_id));

drop policy if exists pipelines_access on public.pipelines;
drop policy if exists pipelines_select_member on public.pipelines;
drop policy if exists pipelines_insert_admin on public.pipelines;
drop policy if exists pipelines_update_admin on public.pipelines;
drop policy if exists pipelines_delete_admin on public.pipelines;
create policy pipelines_select_member on public.pipelines
for select to authenticated using (private.is_org_member(organization_id));
create policy pipelines_insert_admin on public.pipelines
for insert to authenticated with check (private.is_org_admin(organization_id));
create policy pipelines_update_admin on public.pipelines
for update to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));
create policy pipelines_delete_admin on public.pipelines
for delete to authenticated using (private.is_org_admin(organization_id));

drop policy if exists team_memberships_access on public.team_memberships;
drop policy if exists team_memberships_select_member on public.team_memberships;
drop policy if exists team_memberships_insert_admin on public.team_memberships;
drop policy if exists team_memberships_update_admin on public.team_memberships;
drop policy if exists team_memberships_delete_admin on public.team_memberships;
create policy team_memberships_select_member on public.team_memberships
for select to authenticated using (private.is_org_member(organization_id));
create policy team_memberships_insert_admin on public.team_memberships
for insert to authenticated with check (private.is_org_admin(organization_id));
create policy team_memberships_update_admin on public.team_memberships
for update to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));
create policy team_memberships_delete_admin on public.team_memberships
for delete to authenticated using (private.is_org_admin(organization_id));

drop policy if exists teams_access on public.teams;
drop policy if exists teams_select_member on public.teams;
drop policy if exists teams_insert_admin on public.teams;
drop policy if exists teams_update_admin on public.teams;
drop policy if exists teams_delete_admin on public.teams;
create policy teams_select_member on public.teams
for select to authenticated using (private.is_org_member(organization_id));
create policy teams_insert_admin on public.teams
for insert to authenticated with check (private.is_org_admin(organization_id));
create policy teams_update_admin on public.teams
for update to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));
create policy teams_delete_admin on public.teams
for delete to authenticated using (private.is_org_admin(organization_id));

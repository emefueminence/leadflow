-- Allow read-only supervisor (viewer) memberships to preview HR records
-- inside their assigned organization, unit, or team scope.
-- This does not grant write privileges: HR mutation policies remain admin/self-only.

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

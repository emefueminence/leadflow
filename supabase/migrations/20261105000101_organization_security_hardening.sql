-- Follow-up hardening for the organization foundation.

-- Composite tenant keys must not null the organization_id when a stage is deleted.
alter table public.leads drop constraint if exists leads_stage_fk;
alter table public.leads
  add constraint leads_stage_fk
  foreign key (organization_id,stage_id)
  references public.pipeline_stages(organization_id,id) on delete restrict;

-- Organization settings include integration configuration and are admin-only.
drop policy if exists organization_settings_member_select on public.organization_settings;
drop policy if exists organization_settings_admin_select on public.organization_settings;
create policy organization_settings_admin_select on public.organization_settings
for select to authenticated using (private.is_org_admin(organization_id));

-- Automation event details may contain customer information. Only users who can
-- read the associated lead may read its event; organization admins can audit all.
drop policy if exists automation_events_org_select on public.automation_events;
create policy automation_events_scoped_select on public.automation_events
for select to authenticated
using (
  private.is_org_admin(organization_id)
  or (
    lead_id is not null
    and exists (select 1 from public.leads l where l.id=automation_events.lead_id)
  )
);

alter table public.org_memberships
  add constraint org_memberships_unit_scope_check
    check (access_scope <> 'unit' or org_unit_id is not null),
  add constraint org_memberships_team_scope_check
    check (access_scope <> 'team' or team_id is not null);

alter table public.org_units
  add constraint org_units_no_self_parent_check
    check (parent_id is null or parent_id <> id);

-- Prevent hierarchy cycles, including accidental cycles created by an administrator.
create or replace function private.prevent_org_unit_cycle()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  _cycle boolean;
begin
  if new.parent_id is null then return new; end if;
  if new.parent_id=new.id then
    raise exception 'An organizational unit cannot be its own parent';
  end if;

  with recursive ancestors(id,parent_id,path) as (
    select u.id,u.parent_id,array[u.id]::uuid[]
    from public.org_units u
    where u.organization_id=new.organization_id and u.id=new.parent_id
    union all
    select p.id,p.parent_id,a.path || p.id
    from public.org_units p
    join ancestors a on p.id=a.parent_id
    where p.organization_id=new.organization_id
      and not p.id=any(a.path)
  )
  select exists(select 1 from ancestors where id=new.id) into _cycle;

  if _cycle then
    raise exception 'Organizational unit hierarchy cannot contain a cycle';
  end if;
  return new;
end;
$$;
revoke all on function private.prevent_org_unit_cycle() from public;
drop trigger if exists org_units_prevent_cycle on public.org_units;
create trigger org_units_prevent_cycle
before insert or update of parent_id,organization_id on public.org_units
for each row execute function private.prevent_org_unit_cycle();

-- An organization admin cannot promote themselves or others to owner/admin.
-- Only an existing owner can grant or revoke owner-level roles.
create or replace function private.guard_org_membership_changes()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  _actor_role text;
begin
  select m.role into _actor_role
  from public.org_memberships m
  where m.organization_id=coalesce(new.organization_id,old.organization_id)
    and m.user_id=(select auth.uid())
    and m.status='active';

  if _actor_role is null then
    raise exception 'Active organization membership required';
  end if;

  if tg_op='DELETE' then
    if old.role in ('owner','org_admin') and _actor_role <> 'owner' then
      raise exception 'Only an owner can remove an owner or organization administrator';
    end if;
    return old;
  end if;

  if _actor_role <> 'owner' and new.role in ('owner','org_admin') then
    raise exception 'Only an owner can grant owner or organization administrator roles';
  end if;

  if tg_op='UPDATE' and old.role in ('owner','org_admin')
     and new.role not in ('owner','org_admin') and _actor_role <> 'owner' then
    raise exception 'Only an owner can change an owner or organization administrator role';
  end if;

  return new;
end;
$$;
revoke all on function private.guard_org_membership_changes() from public;
drop trigger if exists org_memberships_guard_changes on public.org_memberships;
create trigger org_memberships_guard_changes
before insert or update or delete on public.org_memberships
for each row execute function private.guard_org_membership_changes();

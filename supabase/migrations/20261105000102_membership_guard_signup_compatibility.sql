-- Trusted server-side migrations, Auth signup triggers and service-role jobs
-- run without a user JWT. They must not be blocked by end-user membership guards.
create or replace function private.guard_org_membership_changes()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  _actor_role text;
  _org_id uuid;
  _remaining_owners integer;
begin
  if (select auth.uid()) is null then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;

  _org_id := case when tg_op='DELETE' then old.organization_id else new.organization_id end;
  select m.role into _actor_role
  from public.org_memberships m
  where m.organization_id=_org_id
    and m.user_id=(select auth.uid())
    and m.status='active';

  if _actor_role is null then
    raise exception 'Active organization membership required';
  end if;

  if tg_op='DELETE' then
    if old.role in ('owner','org_admin') and _actor_role <> 'owner' then
      raise exception 'Only an owner can remove an owner or organization administrator';
    end if;
    if old.role='owner' then
      select count(*) into _remaining_owners
      from public.org_memberships m
      where m.organization_id=old.organization_id
        and m.role='owner' and m.status='active' and m.id<>old.id;
      if _remaining_owners=0 then
        raise exception 'An organization must retain at least one active owner';
      end if;
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

  if tg_op='UPDATE' and old.role='owner' and new.role<>'owner' then
    select count(*) into _remaining_owners
    from public.org_memberships m
    where m.organization_id=old.organization_id
      and m.role='owner' and m.status='active' and m.id<>old.id;
    if _remaining_owners=0 then
      raise exception 'An organization must retain at least one active owner';
    end if;
  end if;

  return new;
end;
$$;
revoke all on function private.guard_org_membership_changes() from public;

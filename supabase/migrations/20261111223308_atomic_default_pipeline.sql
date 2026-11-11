-- Switch the default pipeline atomically so a failed second write cannot leave none selected.
create or replace function public.set_default_pipeline(
  p_organization_id uuid,
  p_pipeline_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not private.is_org_admin(p_organization_id) then
    raise exception 'Only organization administrators can change the default pipeline';
  end if;

  if not exists (
    select 1 from public.pipelines p
     where p.id = p_pipeline_id
       and p.organization_id = p_organization_id
       and p.is_active = true
  ) then
    raise exception 'Selected pipeline is not active in this workspace';
  end if;

  update public.pipelines
     set is_default = false
   where organization_id = p_organization_id
     and is_default = true;

  update public.pipelines
     set is_default = true
   where id = p_pipeline_id
     and organization_id = p_organization_id;
end;
$function$;

revoke all on function public.set_default_pipeline(uuid,uuid) from public, anon;
grant execute on function public.set_default_pipeline(uuid,uuid) to authenticated;

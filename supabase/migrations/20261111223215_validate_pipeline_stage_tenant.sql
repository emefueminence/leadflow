drop trigger if exists pipeline_stages_validate_record_org_scope on public.pipeline_stages;
create trigger pipeline_stages_validate_record_org_scope
before insert or update on public.pipeline_stages
for each row execute function private.validate_record_org_scope();
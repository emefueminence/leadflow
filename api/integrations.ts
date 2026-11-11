import { admin, body, json, user, clean } from './_shared.js';
import { getActiveMembership } from './_org.js';

function allowedWebhook(raw:string) {
  try {
    const u = new URL(raw);
    if (u.protocol !== 'https:') return false;
    const allow = (process.env.N8N_ALLOWED_HOSTS || '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
    return allow.length > 0 && allow.includes(u.hostname.toLowerCase());
  } catch { return false; }
}

export default async function handler(req:any,res:any) {
  if (req.method !== 'POST') return json(res,405,{error:'Method not allowed'});
  try {
    const actor = await user(req), input = await body(req);
    const organizationId = String(input.organizationId || '');
    const action = String(input.action || 'read');
    if (!/^[0-9a-f-]{36}$/i.test(organizationId)) return json(res,400,{error:'A valid workspace is required'});
    const db = admin();
    const membership = await getActiveMembership(db,actor.id,organizationId);
    if (!membership || !['owner','org_admin'].includes(membership.role))
      return json(res,403,{error:'Only organization owners and admins can access integration settings'});

    if (action === 'read') {
      const {data,error} = await db.from('integration_secrets')
        .select('n8n_webhook_url,last_n8n_status,last_n8n_detail,last_n8n_at')
        .eq('organization_id',organizationId).maybeSingle();
      if (error) throw error;
      return json(res,200,{ok:true,n8n_webhook_url:data?.n8n_webhook_url || '',
        last_n8n_status:data?.last_n8n_status || null,
        last_n8n_detail:data?.last_n8n_detail || null,
        last_n8n_at:data?.last_n8n_at || null});
    }

    if (action !== 'save') return json(res,400,{error:'Unsupported integration action'});
    const webhookUrl = clean(input.webhookUrl,2048);
    if (webhookUrl && !allowedWebhook(webhookUrl))
      return json(res,400,{error:'Webhook must use HTTPS and a hostname on the server allowlist'});
    if (!webhookUrl) {
      const {error} = await db.from('integration_secrets').delete().eq('organization_id',organizationId);
      if (error) throw error;
      return json(res,200,{ok:true,configured:false});
    }
    const {error} = await db.from('integration_secrets').upsert({
      organization_id:organizationId,n8n_webhook_url:webhookUrl,
      last_n8n_status:null,last_n8n_detail:null,last_n8n_at:null,
      updated_at:new Date().toISOString()
    },{onConflict:'organization_id'});
    if (error) throw error;
    return json(res,200,{ok:true,configured:true});
  } catch(error:any) {
    console.error('integration settings error',error?.message);
    return json(res,error.message==='Unauthorized'?401:500,{error:error.message||'Integration settings could not be saved'});
  }
}
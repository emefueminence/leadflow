import { admin, body, json, user, clean } from './_shared.js';
import { getActiveMembership } from './_org.js';

function webhookValidation(raw:string):string|null {
  let u:URL;
  try { u = new URL(raw); } catch { return 'Enter the complete n8n production webhook URL, starting with https://'; }
  if (u.protocol !== 'https:') return 'The webhook URL must use HTTPS.';
  if (u.username || u.password || u.hash) return 'Remove any embedded username, password, or URL fragment.';
  const allow = (process.env.N8N_ALLOWED_HOSTS || '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
  if (!allow.length) return 'The server has no n8n hostname allowlist configured. Contact the workspace administrator.';
  if (!allow.includes(u.hostname.toLowerCase())) return 'This n8n hostname is not allowed for this LeadFlow deployment.';
  if (!u.pathname.startsWith('/webhook/') || u.pathname.toLowerCase().startsWith('/webhook-test/'))
    return 'Use the active Production URL from the n8n Webhook node. It must contain /webhook/, not /webhook-test/.';
  return null;
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
    if (webhookUrl) {
      const validationError = webhookValidation(webhookUrl);
      if (validationError) return json(res,400,{error:validationError});
    }
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
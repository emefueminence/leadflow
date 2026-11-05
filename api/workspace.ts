import { admin, body, json, user, clean } from './_shared.js';
const sizes=new Set(['solo','small','medium','large','enterprise']);
export default async function handler(req:any,res:any) {
  if(req.method!=='POST') return json(res,405,{error:'Method not allowed'});
  let createdOrganizationId:string|null=null;
  try {
    const actor=await user(req), input=await body(req);
    const name=clean(input.name,160), industry=clean(input.industry,100), businessModel=clean(input.businessModel,100);
    const companySize=String(input.companySize||'solo');
    if(!name) return json(res,400,{error:'Workspace name is required'});
    if(!sizes.has(companySize)) return json(res,400,{error:'Invalid company size'});
    const db=admin();
    const {count}=await db.from('org_memberships').select('id',{count:'exact',head:true}).eq('user_id',actor.id).eq('status','active');
    if((count||0)>=10) return json(res,403,{error:'This account has reached the current workspace limit'});
    const slug='workspace-'+crypto.randomUUID().replace(/-/g,'');
    const {data:org,error:orgError}=await db.from('organizations').insert({
      name,slug,industry:industry||null,business_model:businessModel||null,company_size:companySize,created_by:actor.id
    }).select('id').single();
    if(orgError||!org) throw orgError||new Error('Could not create workspace');
    createdOrganizationId=org.id;
    const {error:memberError}=await db.from('org_memberships').insert({
      organization_id:org.id,user_id:actor.id,role:'owner',access_scope:'organization',status:'active'
    });
    if(memberError) throw memberError;
    const {data:pipeline,error:pipelineError}=await db.from('pipelines').insert({
      organization_id:org.id,name:'Default pipeline',entity_type:'lead',is_default:true
    }).select('id').single();
    if(pipelineError||!pipeline) throw pipelineError||new Error('Could not create default pipeline');
    const stageNames=['New','In Progress','Qualified','Proposal','Won','Lost'];
    const {error:stageError}=await db.from('pipeline_stages').insert(stageNames.map((stage,index)=>({
      organization_id:org.id,pipeline_id:pipeline.id,name:stage,position:index+1,is_won:stage==='Won',is_lost:stage==='Lost'
    })));
    if(stageError) throw stageError;
    const [{error:orgSettingsError},{error:legacySettingsError}]=await Promise.all([
      db.from('organization_settings').insert({organization_id:org.id}),
      db.from('settings').insert({organization_id:org.id,user_id:actor.id,business_name:name,currency:'NGN',timezone:'Africa/Lagos'})
    ]);
    if(orgSettingsError||legacySettingsError) throw orgSettingsError||legacySettingsError;
    return json(res,201,{ok:true,organizationId:org.id});
  } catch(error:any) {
    if(createdOrganizationId) {
      try { await admin().from('organizations').delete().eq('id',createdOrganizationId); } catch {}
    }
    console.error('workspace create error',error?.message);
    return json(res,error.message==='Unauthorized'?401:500,{error:error.message||'Could not create workspace'});
  }
}

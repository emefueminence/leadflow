import{json}from'./_shared.js';
export default async function handler(req:any,res:any){
 if(req.method!=='GET')return json(res,405,{error:'Method not allowed'});
 let authReachable=false,authStatus:number|null=null,authError:string|null=null;
 const base=process.env.SUPABASE_URL,key=process.env.SUPABASE_PUBLISHABLE_KEY;
 if(base){const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),4000);try{
  const root=base.endsWith('/')?base.slice(0,-1):base;
  const response=await fetch(root+'/auth/v1/health',{headers:key?{apikey:key}:{},signal:controller.signal});
  authStatus=response.status;authReachable=response.ok;
 }catch(error:any){authError=String(error?.name||'Error')+': '+String(error?.message||'request failed').slice(0,160);}finally{clearTimeout(timer);}}
 let supabaseHost:string|null=null;try{supabaseHost=base?new URL(base).hostname:null;}catch{}
 return json(res,200,{
  supabase:Boolean(process.env.SUPABASE_SECRET_KEY),
  supabaseHost,
  authReachable,authStatus,authError,
  gemini:Boolean(process.env.GEMINI_API_KEY),
  n8n:{configured:Boolean(process.env.N8N_WEBHOOK_URL),allowlist:Boolean(process.env.N8N_ALLOWED_HOSTS)},
  intakeRateSalt:Boolean(process.env.INTAKE_RATE_SALT)
 });
}
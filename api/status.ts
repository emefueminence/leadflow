import{json}from'./_shared.js';
export default async function handler(req:any,res:any){
 if(req.method!=='GET')return json(res,405,{error:'Method not allowed'});
 let authReachable=false;
 const base=process.env.SUPABASE_URL;
 if(base){const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),4000);try{const response=await fetch(base.replace(/\\/$/,'')+'/auth/v1/health',{signal:controller.signal});authReachable=response.ok;}catch{}finally{clearTimeout(timer);}}
 return json(res,200,{
  supabase:Boolean(process.env.SUPABASE_SECRET_KEY),
  authReachable,
  gemini:Boolean(process.env.GEMINI_API_KEY),
  n8n:{configured:Boolean(process.env.N8N_WEBHOOK_URL),allowlist:Boolean(process.env.N8N_ALLOWED_HOSTS)},
  intakeRateSalt:Boolean(process.env.INTAKE_RATE_SALT)
 });
}
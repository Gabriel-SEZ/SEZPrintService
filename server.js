'use strict';
const http=require('http'), os=require('os'), crypto=require('crypto'), {execFile}=require('child_process');
const PORT=32177, HOST='127.0.0.1';
const token=crypto.randomBytes(24).toString('hex');
const version='0.1.0';
const ALLOWED_ORIGINS=new Set(['https://smartez.com.br','https://www.smartez.com.br','http://localhost','http://127.0.0.1']);
function send(req,res,status,data){const origin=req.headers.origin||'';const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Vary':'Origin'};if(ALLOWED_ORIGINS.has(origin)){headers['Access-Control-Allow-Origin']=origin;headers['Access-Control-Allow-Headers']='Content-Type, X-SEZ-Print-Token';headers['Access-Control-Allow-Methods']='GET, POST, OPTIONS';}const b=Buffer.from(JSON.stringify(data));headers['Content-Length']=b.length;res.writeHead(status,headers);res.end(b);}
function ps(script){return new Promise((resolve,reject)=>execFile('powershell.exe',['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-Command',script],{windowsHide:true,timeout:15000,maxBuffer:2*1024*1024},(e,stdout,stderr)=>e?reject(new Error((stderr||e.message).trim())):resolve(stdout.trim())));}
async function printers(){const raw=await ps("Get-Printer | Select-Object Name,Default | ConvertTo-Json -Compress");if(!raw)return [];let x=JSON.parse(raw);if(!Array.isArray(x))x=[x];return x.map(p=>({name:p.Name,isDefault:!!p.Default}));}
const server=http.createServer(async(req,res)=>{
 if(req.method==='OPTIONS')return send(req,res,204,{ok:true});
 const origin=req.headers.origin||'';if(origin&&!ALLOWED_ORIGINS.has(origin))return send(req,res,403,{ok:false,error:'Origem não autorizada.'});
 const url=new URL(req.url,'http://localhost');
 try{
  if(url.pathname==='/api/status'&&req.method==='GET')return send(req,res,200,{ok:true,service:'SEZ Print Service',version,pairingToken:token,host:os.hostname()});
  if(req.headers['x-sez-print-token']!==token)return send(req,res,401,{ok:false,error:'Token local inválido. Reconecte pelo ERP.'});
  if(url.pathname==='/api/printers'&&req.method==='GET')return send(req,res,200,{ok:true,printers:await printers()});
  if(url.pathname==='/api/test'&&req.method==='POST'){
   let body='';for await(const c of req)body+=c;const d=JSON.parse(body||'{}');
   const names=(await printers()).map(p=>p.name);if(!names.includes(d.printer))return send(req,res,400,{ok:false,error:'Impressora não encontrada no Windows.'});
   const text=d.format==='a4'?'SEZ PRINT SERVICE\\nTeste de impressão A4\\n'+new Date().toLocaleString('pt-BR')+'\\n\\n':'SEZ PRINT\\nTeste 80mm\\n'+new Date().toLocaleString('pt-BR')+'\\n\\n';
   const b64=Buffer.from(text,'utf8').toString('base64');
   const printer=d.printer.replace(/'/g,"''");
   await ps("$t=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"+b64+"')); $t | Out-Printer -Name '"+printer+"'");
   return send(req,res,200,{ok:true,message:'Teste enviado'});
  }
  return send(req,res,404,{ok:false,error:'Rota não encontrada'});
 }catch(e){return send(req,res,500,{ok:false,error:e.message});}
});
server.on('error',e=>{if(e.code==='EADDRINUSE'){console.error('SEZ Print Service já está em execução.');process.exit(0);}console.error(e);process.exit(1);});
server.listen(PORT,HOST,()=>console.log(`SEZ Print Service ${version} em http://${HOST}:${PORT}`));
process.on('SIGINT',()=>server.close(()=>process.exit(0)));
process.on('SIGTERM',()=>server.close(()=>process.exit(0)));

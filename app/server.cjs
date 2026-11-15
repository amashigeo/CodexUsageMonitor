const fs=require('node:fs'),fsp=fs.promises,path=require('node:path'),os=require('node:os'),http=require('node:http');
const {windowView}=require('./metrics.cjs');
const {readQuota}=require('./quota-client.cjs');
const {nextIdleRefresh}=require('./refresh-policy.cjs');
const {estimateCost}=require('./cost.cjs');
const {mergeResetCredits}=require('./reset-cache.cjs');
const {Analytics,starts}=require('./analytics.cjs');const analytics=new Analytics();
const resetCacheFile=path.join(__dirname,'reset-credits-cache.json');let resetCache={};
try{resetCache=JSON.parse(fs.readFileSync(resetCacheFile,'utf8').replace(/^\uFEFF/,''));}catch{}
const root=path.join(process.env.CODEX_HOME||path.join(os.homedir(),'.codex'),'sessions');
const port=Number(process.env.CODEX_USAGE_PORT||47831),host='127.0.0.1';
const files=new Map(), samples=new Map(), events=[];let scanning=false,lastScan=null,scanError=null;
let titles=new Map(),indexMtime=0;
function historyCutoff(){return Math.min(starts(Date.now()).year,Date.now()-8*86400000);}
async function readTitles(){try{const file=path.join(path.dirname(root),'session_index.jsonl'),stat=await fsp.stat(file);if(stat.mtimeMs===indexMtime)return;const map=new Map();for(const line of (await fsp.readFile(file,'utf8')).split('\n')){try{const r=JSON.parse(line);if(r.id&&r.thread_name)map.set(r.id,r.thread_name);}catch{}}titles=map;indexMtime=stat.mtimeMs;}catch{}}
const startedAt=Date.now();let lastActivityAt=0;
const configuredMinutes=Number(process.env.CODEX_USAGE_REFRESH_MINUTES||10);
const refresh={intervalMinutes:Number.isFinite(configuredMinutes)?Math.max(1,configuredMinutes):10,inFlight:false,lastAttempt:null,lastSuccess:null,error:null,nextAt:startedAt};
function updateRefreshSchedule(){refresh.nextAt=nextIdleRefresh({startedAt,lastAttempt:refresh.lastAttempt,lastActivityAt,intervalMinutes:refresh.intervalMinutes});}
async function refreshQuota(){
 if(refresh.inFlight||process.env.CODEX_USAGE_DISABLE_REMOTE==='1')return;
 refresh.inFlight=true;refresh.lastAttempt=Date.now();refresh.nextAt=refresh.lastAttempt+refresh.intervalMinutes*60000;
 try{const buckets=await readQuota();const at=Date.now();for(const b of buckets){if(b.limits.reset_credits){b.limits.reset_credits=mergeResetCredits(b.limits.reset_credits,resetCache[b.id]);resetCache[b.id]=b.limits.reset_credits;}if(!samples.has(b.id))samples.set(b.id,[]);const list=samples.get(b.id);list.push({at,limits:b.limits});list.sort((a,b)=>a.at-b.at);}try{await fsp.writeFile(resetCacheFile,JSON.stringify(resetCache));}catch{}refresh.lastSuccess=at;refresh.error=null;}
 catch(e){refresh.error=e.message;}finally{refresh.inFlight=false;}
}
const NUM=['input_tokens','cached_input_tokens','cache_write_input_tokens','output_tokens','reasoning_output_tokens','total_tokens'];
const empty=()=>Object.fromEntries(NUM.map(k=>[k,0]));
async function walk(dir){const out=[];for(const e of await fsp.readdir(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())out.push(...await walk(p));else if(e.name.endsWith('.jsonl'))out.push(p);}return out;}
function consume(line,state){let row;try{row=JSON.parse(line)}catch{return}const p=row.payload;if(!p)return;
 if(row.type==='session_meta'){state.id=p.id||state.id;state.project=p.cwd?path.basename(p.cwd):null;return;}
 if(row.type==='turn_context'){state.model=p.model||state.model;return;}
 if(row.type!=='event_msg')return;
 const stamp=Date.parse(row.timestamp);
 if(['task_started','task_complete','turn_aborted'].includes(p.type)){if(Number.isFinite(stamp)){state.activityAt=stamp;state.running=p.type==='task_started';}return;}
 if(p.type!=='token_count')return;
 const at=Date.parse(row.timestamp);if(!Number.isFinite(at))return;
 lastActivityAt=Math.max(lastActivityAt,Math.min(at,Date.now()));updateRefreshSchedule();
 if(p.rate_limits){const id=p.rate_limits.limit_id||'codex';if(!samples.has(id))samples.set(id,[]);samples.get(id).push({at,limits:p.rate_limits});}
 const usage=p.info?.total_token_usage;if(!usage)return;
 state.activityAt=at;const last=p.info?.last_token_usage;state.contextTokens=Number.isFinite(last?.total_tokens)?last.total_tokens:null;state.contextPercent=state.contextTokens!=null&&p.info.model_context_window?Math.min(100,100*state.contextTokens/p.info.model_context_window):null;
 const delta=empty();for(const k of NUM){const n=Math.max(0,Number(usage[k])||0),prev=state.total[k];delta[k]=n>=prev?n-prev:n;state.total[k]=n;}
 if(delta.total_tokens>0){const cost=estimateCost(delta,state.model);state.estimatedUsd=(state.estimatedUsd||0)+cost.usd;const event={at,...delta,estimated_usd:cost.usd,fallback_tokens:cost.fallback?delta.total_tokens:0};if(at>=historyCutoff()&&at<=Date.now())analytics.add(event,state.id);if(at>=Date.now()-8*86400000)events.push(event);}state.at=at;
}
async function scan(){if(scanning)return;scanning=true;try{
 await readTitles();const paths=(await walk(root)).sort().reverse(); const cutoff=historyCutoff();
 for(const file of paths){const stat=await fsp.stat(file);if(stat.mtimeMs<cutoff&&!files.has(file))continue;
 let s=files.get(file);if(!s){s={id:path.basename(file,'.jsonl'),offset:0,pending:'',total:empty(),at:0};files.set(file,s);}
 if(stat.size<s.offset){s.offset=0;s.pending='';s.total=empty();}
 if(stat.size===s.offset)continue;
 const stream=fs.createReadStream(file,{start:s.offset,end:stat.size-1,encoding:'utf8'});let pending=s.pending;
 for await(const chunk of stream){pending+=chunk;let i;while((i=pending.indexOf('\n'))>=0){consume(pending.slice(0,i),s);pending=pending.slice(i+1);}}
 s.pending=pending;s.offset=stat.size;
 }
 for(const [id,list]of samples){list.sort((a,b)=>a.at-b.at);const newest=list.at(-1);samples.set(id,list.filter(s=>s.at>=Date.now()-3600000||s===newest));}
 for(let i=events.length-1;i>=0;i--)if(events[i].at<cutoff)events.splice(i,1);
 lastScan=Date.now();scanError=null;
 }catch(e){scanError=e.code==='ENOENT'?'找不到 Codex 会话目录，请先在 Codex 中完成一次对话。':`读取本地日志失败（${e.code||'未知错误'}）`;}finally{scanning=false;}}
function snapshot(){const now=Date.now(),day=new Date();day.setHours(0,0,0,0);const sum=(since)=>{const a={...empty(),estimated_usd:0,fallback_tokens:0};for(const e of events)if(e.at>=since&&e.at<=now)for(const k of [...NUM,'estimated_usd','fallback_tokens'])a[k]+=e[k]||0;return a;};
 const recent=sum(now-60000);const buckets=[...samples].map(([id,list])=>({id,updatedAt:list.at(-1)?.at,primary:windowView(list,'primary',now),secondary:windowView(list,'secondary',now),credits:list.at(-1)?.limits?.credits,plan:list.at(-1)?.limits?.plan_type||[...list].reverse().find(s=>s.limits.plan_type)?.limits.plan_type||null,resetCredits:[...list].reverse().find(s=>s.limits.reset_credits)?.limits.reset_credits||null}));
 const active=[...files.values()].sort((a,b)=>b.at-a.at)[0];
 const month=new Date(day);month.setDate(1);
 const {sessions:monthSessions,...monthTotals}=analytics.snapshot(now).periods.month;
 const sessions=[...files.values()].filter(s=>s.at>0).map(s=>({id:s.id,title:titles.get(s.id)||s.project||'未命名会话',model:s.model||'模型未知',tokens:s.total.total_tokens,estimatedUsd:s.estimatedUsd||0,updatedAt:s.activityAt||s.at,running:!!s.running&&now-(s.activityAt||s.at)<600000,contextTokens:s.contextTokens??null,contextPercent:s.contextPercent??null})).sort((a,b)=>b.updatedAt-a.updatedAt);
 return {now,lastScan,error:scanError,scanning,refresh:{...refresh},buckets,today:sum(day.getTime()),month:monthTotals,week:sum(now-7*86400000),sessions:sessions.slice(0,8),runningCount:sessions.filter(s=>s.running).length,session:active?.total||null,sessionUpdatedAt:active?.at||null,speed:{output:recent.output_tokens/60,total:recent.total_tokens/60},fileCount:files.size};
}
const staticFiles={'/':['index.html','text/html; charset=utf-8'],'/app.js':['app.js','text/javascript; charset=utf-8'],'/style.css':['style.css','text/css; charset=utf-8'],'/stats':['stats.html','text/html; charset=utf-8'],'/stats.js':['stats.js','text/javascript; charset=utf-8'],'/stats.css':['stats.css','text/css; charset=utf-8'],'/mascot-title.png':['mascot-title.png','image/png']};
const server=http.createServer(async(req,res)=>{
 if(req.headers.host!==`${host}:${port}`&&req.headers.host!==`localhost:${port}`){res.writeHead(403);return res.end('Forbidden');}
 if(req.method!=='GET'){res.writeHead(405);return res.end();}
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Content-Security-Policy',"default-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'");
 if(req.url==='/api/status'){res.setHeader('Content-Type','application/json; charset=utf-8');return res.end(JSON.stringify(snapshot()));}
 if(req.url==='/api/analytics'){const metadata=new Map([...files.values()].map(s=>[s.id,{title:titles.get(s.id)||s.project||'未命名会话',model:s.model}]));res.setHeader('Content-Type','application/json; charset=utf-8');return res.end(JSON.stringify({now:Date.now(),scanning,lastScan,error:scanError,...analytics.snapshot(Date.now(),metadata)}));}
 const file=staticFiles[req.url];if(!file){res.writeHead(404);return res.end();}try{res.setHeader('Content-Type',file[1]);res.end(await fsp.readFile(path.join(__dirname,file[0])));}catch{res.writeHead(500);res.end('File unavailable');}
});
server.on('error',e=>{console.error(e.code==='EADDRINUSE'?'面板已启动，或端口被占用。':e.message);process.exit(1)});
server.listen(port,host,()=>{console.log(`Codex 用量面板：http://${host}:${port}`);refreshQuota();});scan();setInterval(async()=>{await scan();updateRefreshSchedule();if(Date.now()>=refresh.nextAt)refreshQuota();},5000);

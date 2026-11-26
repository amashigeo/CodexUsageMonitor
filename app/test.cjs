const {test}=require('node:test'),assert=require('node:assert/strict');const {windowView}=require('./metrics.cjs');
const now=1800000000000,reset=now/1000+7200;
const sample=(ago,used,r=reset)=>({at:now-ago,limits:{primary:{used_percent:used,resets_at:r,window_minutes:300}}});
test('linear quota rate uses percentage points and ignores reset jitter',()=>{const w=windowView([sample(1800000,10,reset+2),sample(0,20)],'primary',now);assert.equal(w.rate,20);assert.equal(w.etaHours,4)});
test('missing or flat quota is not fabricated',()=>{assert.equal(windowView([],'primary',now),null);assert.equal(windowView([sample(120000,20),sample(0,20)],'primary',now).rate,null)});
test('new window and percentage rollback restart sampling',()=>{assert.equal(windowView([sample(1800000,70,reset-18000),sample(0,5)],'primary',now).rate,null);assert.equal(windowView([sample(1800000,70),sample(120000,5),sample(0,6)],'primary',now).rate,30)});
test('expired quota never predicts future availability',()=>{const w=windowView([sample(1800000,10,reset-9000),sample(0,20,reset-9000)],'primary',now);assert.equal(w.expired,true);assert.equal(w.rate,null)});
test('partial log writes, duplicate cumulative totals and per-session sums',async()=>{
 const fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path');const {spawn}=require('node:child_process');const home=await fs.mkdtemp(path.join(os.tmpdir(),'codex-monitor-test-'));await fs.mkdir(path.join(home,'sessions'));const stamp=new Date().toISOString();
 const event=(n)=>JSON.stringify({timestamp:stamp,type:'event_msg',payload:{type:'token_count',info:{total_token_usage:{input_tokens:n,output_tokens:n/10,total_tokens:n*1.1},last_token_usage:{total_tokens:n+20},model_context_window:1000},rate_limits:{limit_id:'codex',primary:{used_percent:4,window_minutes:300,resets_at:Date.now()/1000+3600}}}});
 const prefix=[{type:'session_meta',payload:{id:'test-thread',cwd:'test-project'}},{type:'turn_context',payload:{model:'test-model'}},{timestamp:stamp,type:'event_msg',payload:{type:'task_started'}}].map(JSON.stringify).join('\n')+'\n';
 await fs.writeFile(path.join(home,'session_index.jsonl'),JSON.stringify({id:'test-thread',thread_name:'Test session'})+'\n');
 const file=path.join(home,'sessions','a.jsonl');await fs.writeFile(file,prefix+event(100)+'\n'+event(100)+'\n'+event(200).slice(0,50));
 const startServer=()=>spawn(process.execPath,[path.join(__dirname,'server.cjs')],{env:{...process.env,CODEX_HOME:home,CODEX_USAGE_ARCHIVE:path.join(home,'usage-history.json'),CODEX_USAGE_PORT:'47839',CODEX_USAGE_DISABLE_REMOTE:'1'},windowsHide:true,stdio:'ignore'});
 let child=startServer();
 const stopServer=async()=>{if(child.exitCode!==null)return;const exited=new Promise(resolve=>child.once('exit',resolve));child.kill();await exited;};
 async function read(){return (await fetch('http://127.0.0.1:47839/api/status')).json()}
 try{let s;for(let i=0;i<40;i++){await new Promise(r=>setTimeout(r,100));try{s=await read();if(s.lastScan)break}catch{}}assert.equal(s.today.total_tokens,110.00000000000001);await fs.appendFile(file,event(200).slice(50)+'\n');for(let i=0;i<70;i++){await new Promise(r=>setTimeout(r,100));s=await read();if(s.today.input_tokens===200)break}assert.equal(s.today.input_tokens,200);assert.equal(s.today.output_tokens,20);assert.equal(s.buckets[0].primary.used,4);
 assert.equal(s.sessions[0].title,'Test session');assert.equal(s.sessions[0].model,'test-model');assert.equal(s.sessions[0].tokens,220.00000000000003);assert.equal(s.runningCount,1);assert.equal(s.month.input_tokens,200);assert.ok(s.sessions[0].estimatedUsd>0);assert.equal(s.sessions[0].estimatedUsd,s.month.estimated_usd);assert.equal(s.sessions[0].contextTokens,220);assert.equal(s.sessions[0].contextPercent,22);
 const details=await (await fetch('http://127.0.0.1:47839/api/analytics')).json();assert.equal(details.periods.month.input_tokens,200);assert.equal(details.periods.month.sessions[0].title,'Test session');assert.equal(details.periods.month.estimated_usd,s.month.estimated_usd);assert.equal(details.daily.reduce((n,d)=>n+d.input_tokens,0),200);
 await fs.appendFile(file,JSON.stringify({timestamp:stamp,type:'event_msg',payload:{type:'task_complete'}})+'\n');
 for(let i=0;i<70;i++){await new Promise(r=>setTimeout(r,100));s=await read();if(s.runningCount===0)break;}assert.equal(s.runningCount,0);
 const denied=await new Promise((resolve,reject)=>{const req=require('node:http').get('http://127.0.0.1:47839/api/status',{headers:{host:'evil.example'}},res=>{res.resume();resolve(res.statusCode)});req.on('error',reject)});assert.equal(denied,403);
 const saved=JSON.parse(await fs.readFile(path.join(home,'usage-history.json'),'utf8'));
 assert.equal(saved.days[0][1][0][1].input_tokens,200);
 await stopServer();
 child=startServer();
 for(let i=0;i<40;i++){await new Promise(r=>setTimeout(r,100));try{s=await read();if(s.lastScan&&!s.scanning)break;}catch{}}
 assert.equal(s.today.input_tokens,200);
 assert.equal(s.fileCount,1);
 await stopServer();
 await fs.unlink(file);
 await fs.unlink(path.join(home,'session_index.jsonl'));
 child=startServer();
 for(let i=0;i<40;i++){await new Promise(r=>setTimeout(r,100));try{s=await read();if(s.lastScan&&!s.scanning)break;}catch{}}
 assert.equal(s.fileCount,0);
 assert.equal(s.today.input_tokens,200);
 const archived=await(await fetch('http://127.0.0.1:47839/api/analytics')).json();
 assert.equal(archived.periods.month.sessions[0].title,'Test session');
 assert.equal(archived.periods.month.estimated_usd,details.periods.month.estimated_usd);
 }finally{await stopServer();await fs.unlink(path.join(home,'usage-history.json')).catch(()=>{});await fs.unlink(path.join(home,'session_index.jsonl')).catch(()=>{});await fs.unlink(file).catch(()=>{});await fs.rmdir(path.join(home,'sessions'));await fs.rmdir(home);}
});

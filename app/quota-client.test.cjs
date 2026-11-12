const {test}=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events'),{PassThrough,Writable}=require('node:stream');
const {normalizeLimits,readQuota}=require('./quota-client.cjs');
const {nextIdleRefresh}=require('./refresh-policy.cjs');
test('idle quota queries run every ten minutes and activity postpones them',()=>{
 const t=1800000000000;
 assert.equal(nextIdleRefresh({startedAt:t}),t+600000);
 assert.equal(nextIdleRefresh({startedAt:t,lastAttempt:t+600000}),t+1200000);
 assert.equal(nextIdleRefresh({startedAt:t,lastAttempt:t,lastActivityAt:t+300000}),t+900000);
 assert.equal(nextIdleRefresh({startedAt:t,lastActivityAt:t-86400000}),t+600000);
});
const result={rateLimitsByLimitId:{codex:{primary:{usedPercent:12,windowDurationMins:300,resetsAt:1900000000},secondary:{usedPercent:30,windowDurationMins:10080,resetsAt:1900100000}}}};
function mockSpawn(handler){return ()=>{const p=new EventEmitter();p.stdout=new PassThrough();p.stderr=new PassThrough();p.stdin=new Writable({write(data,encoding,done){handler(JSON.parse(data),p);done();}});p.kill=()=>{p.killed=true};return p;};}
test('quota normalization preserves unavailable fields',()=>{const b=normalizeLimits(result)[0];assert.equal(b.limits.primary.used_percent,12);assert.equal(b.limits.secondary.window_minutes,10080);assert.equal(normalizeLimits({rateLimits:{primary:{usedPercent:null}}})[0].limits.primary,null);});
test('plan and reset credits reflect official data, with earliest available expiry',()=>{
 const r=JSON.parse(JSON.stringify(result));r.rateLimitsByLimitId.codex.planType='plus';r.rateLimitResetCredits={availableCount:2,credits:[{status:'expired',expiresAt:100},{status:'available',expiresAt:500},{status:'available',expiresAt:300}]};
 const limits=normalizeLimits(r)[0].limits;assert.equal(limits.plan_type,'plus');assert.deepEqual(limits.reset_credits,{count:2,detailsKnown:true,expiresAt:300});assert.equal(normalizeLimits(result)[0].limits.reset_credits,null);
});
test('count-only refresh keeps a known unexpired reset date but does not reuse it after count changes',()=>{
 const {mergeResetCredits}=require('./reset-cache.cjs'),previous={count:2,expiresAt:1000};
 assert.equal(mergeResetCredits({count:2,expiresAt:null,detailsKnown:false},previous,500).expiresAt,1000);
 assert.equal(mergeResetCredits({count:1,expiresAt:null,detailsKnown:false},previous,500).expiresAt,null);
 assert.equal(mergeResetCredits({count:2,expiresAt:null,detailsKnown:false},previous,1100).expiresAt,null);
 assert.equal(mergeResetCredits({count:2,expiresAt:null,detailsKnown:true},previous,500).expiresAt,null);
});
test('read-only handshake handles fragmented replies and terminates process',async()=>{
 const requests=[];let child;
 const spawnFn=mockSpawn((m,p)=>{child=p;requests.push(m.method);if(m.id===1)queueMicrotask(()=>p.stdout.write('{"id":1,"result":{}}\n'));if(m.id===2)queueMicrotask(()=>{const line=JSON.stringify({id:2,result})+'\n';p.stdout.write(line.slice(0,10));p.stdout.write(line.slice(10));});});
 const buckets=await readQuota({spawnFn});assert.equal(buckets[0].limits.primary.used_percent,12);assert.deepEqual(requests,['initialize','initialized','account/rateLimits/read']);assert.equal(child.killed,true);
});
test('timeout terminates query and reports failure without replacing cache',async()=>{let child;const spawnFn=mockSpawn((m,p)=>{child=p;});await assert.rejects(readQuota({spawnFn,timeoutMs:15}),/超时/);assert.equal(child.killed,true);});
test('upstream auth/network errors are reported without exposing raw details',async()=>{
 const spawnFn=mockSpawn((m,p)=>{if(m.id===1)queueMicrotask(()=>p.stdout.write('{"id":1,"result":{}}\n'));if(m.id===2)queueMicrotask(()=>p.stdout.write('{"id":2,"error":{"message":"private diagnostics"}}\n'));});await assert.rejects(readQuota({spawnFn}),e=>e.message.includes('登录或网络')&&!e.message.includes('private'));
});

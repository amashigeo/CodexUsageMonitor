const {spawn}=require('node:child_process');

function normalizeLimits(result) {
 const source=result.rateLimitsByLimitId || (result.rateLimits ? {[result.rateLimits.limitId||'codex']:result.rateLimits} : {});
 const window=w=>w&&Number.isFinite(w.usedPercent)&&Number.isFinite(w.resetsAt)&&Number.isFinite(w.windowDurationMins)
  ? {used_percent:w.usedPercent,window_minutes:w.windowDurationMins,resets_at:w.resetsAt}:null;
 const reset=result.rateLimitResetCredits;
 const resetInfo=reset?{count:reset.availableCount??null,detailsKnown:Array.isArray(reset.credits),expiresAt:reset.credits?.filter(c=>c.status==='available'&&c.expiresAt).map(c=>c.expiresAt).sort((a,b)=>a-b)[0]??null}:null;
 return Object.entries(source).map(([id,b])=>({id,limits:{limit_id:id,primary:window(b.primary),secondary:window(b.secondary),credits:b.credits||null,plan_type:b.planType||null,reset_credits:resetInfo}}));
}

// Reuse Codex-managed login via its documented read-only app-server method.
// Do not open credentials or create model turns. Each polling process is short-lived.
function readQuota({command=process.env.CODEX_USAGE_CLI||'codex',timeoutMs=45000,spawnFn=spawn}={}) {
 return new Promise((resolve,reject)=>{
  let child,buffer='',settled=false,timer;
  function finish(error,result){if(settled)return;settled=true;clearTimeout(timer);if(child){child.stdin?.end();child.kill();}error?reject(error):resolve(result);}
  try { child=spawnFn(command,['app-server'],{windowsHide:true,stdio:['pipe','pipe','pipe']}); }
  catch {finish(Error('无法启动 Codex 查询服务'));return;}
  const send=x=>{try{child.stdin.write(JSON.stringify(x)+'\n');}catch{finish(Error('Codex 查询连接已关闭'));}};
  timer=setTimeout(()=>finish(Error('额度查询超时')),timeoutMs);
  child.on('error',()=>finish(Error('无法启动 Codex 查询服务')));
  child.on('exit',()=>finish(Error('Codex 查询服务提前退出')));
  child.stdin.on('error',()=>finish(Error('Codex 查询连接已关闭')));
  // Drain diagnostics without collecting or disclosing account/environment details.
  child.stderr.on('data',()=>{});
  child.stdout.setEncoding('utf8');
  child.stdout.on('data',chunk=>{
   buffer+=chunk;if(buffer.length>4*1024*1024){finish(Error('Codex 查询响应异常'));return;}
   let index;while((index=buffer.indexOf('\n'))>=0){
    const line=buffer.slice(0,index);buffer=buffer.slice(index+1);let msg;try{msg=JSON.parse(line);}catch{continue;}
    if(msg.id===1){if(msg.error){finish(Error('Codex 查询初始化失败'));return;}send({method:'initialized',params:{}});send({id:2,method:'account/rateLimits/read'});}
    if(msg.id===2){if(msg.error){finish(Error('账户额度查询失败，请检查 Codex 登录或网络'));return;}
     const buckets=normalizeLimits(msg.result||{});
     if(!buckets.some(b=>b.limits.primary||b.limits.secondary)){finish(Error('账户未返回可用额度'));return;}
     finish(null,buckets);return;
    }
   }
  });
  send({id:1,method:'initialize',params:{clientInfo:{name:'codex_usage_monitor',version:'1.1.0'}}});
 });
}
module.exports={readQuota,normalizeLimits};

const fields=['input_tokens','cached_input_tokens','cache_write_input_tokens','output_tokens','reasoning_output_tokens','total_tokens','estimated_usd','fallback_tokens'];
const zero=()=>Object.fromEntries(fields.map(k=>[k,0]));
const key=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
function starts(now){const day=new Date(now);day.setHours(0,0,0,0);const week=new Date(day);week.setDate(week.getDate()-(week.getDay()+6)%7);const month=new Date(day);month.setDate(1);const year=new Date(month);year.setMonth(0);return {day:day.getTime(),week:week.getTime(),month:month.getTime(),year:year.getTime()};}
class Analytics {
 constructor(){this.days=new Map();this.recoveredDays=new Map();}
 add(event,sessionId){const at=new Date(event.at);if(!Number.isFinite(at.getTime()))return;const date=key(at);if(!this.days.has(date))this.days.set(date,new Map());const sessions=this.days.get(date);if(!sessions.has(sessionId))sessions.set(sessionId,zero());const row=sessions.get(sessionId);for(const k of fields)row[k]+=event[k]||0;}
 snapshot(now=Date.now(),metadata=new Map(),year=new Date(now).getFullYear()){
  const limits=starts(now),periods=Object.fromEntries(Object.keys(limits).map(k=>[k,{...zero(),sessions:[]}])) ,byPeriod=Object.fromEntries(Object.keys(limits).map(k=>[k,new Map()]));const daily=[];
  const years=new Set([new Date(now).getFullYear()]);
  const dates=new Set([...this.days.keys(),...this.recoveredDays.keys()]);
  for(const date of dates){
   const sessions=new Map(this.days.get(date));
   const saved=this.recoveredDays.get(date);
   if(saved){
    const difference=zero();
    for(const f of fields){
     const recorded=[...sessions.values()].reduce((sum,row)=>sum+(row[f]||0),0);
     difference[f]=Math.max(0,(saved[f]||0)-recorded);
    }
    if(difference.total_tokens>0)sessions.set('legacy-unattributed-history',difference);
   }
   const [y,m,d]=date.split('-').map(Number),at=new Date(y,m-1,d).getTime();
   if(at>now)continue;
   years.add(y);
   const matching=Object.keys(limits).filter(period=>period==='year'?y===year:at>=limits[period]);
   if(!matching.length)continue;
   const totals=zero();
   for(const [id,values] of sessions){
    for(const f of fields)totals[f]+=values[f];
    for(const period of matching){
     const map=byPeriod[period];
     if(!map.has(id))map.set(id,{id,title:metadata.get(id)?.title||(id==='legacy-unattributed-history'?'旧版历史（会话未知）':'未命名会话'),model:metadata.get(id)?.model||'模型未知',...zero()});
     for(const f of fields){periods[period][f]+=values[f];map.get(id)[f]+=values[f];}
    }
   }
   if(y===year)daily.push({date,...totals,sessionCount:sessions.size-Number(sessions.has('legacy-unattributed-history'))});
  }
  for(const p of Object.keys(periods))periods[p].sessions=[...byPeriod[p].values()].sort((a,b)=>b.estimated_usd-a.estimated_usd||b.total_tokens-a.total_tokens);
  return {year,years:[...years].sort((a,b)=>b-a),periods,daily:daily.sort((a,b)=>a.date.localeCompare(b.date))};
 }
}
module.exports={Analytics,starts};

const {test}=require('node:test'),assert=require('node:assert/strict'),{Analytics,starts}=require('./analytics.cjs');
test('calendar boundaries, per-session costs and daily aggregation',()=>{const a=new Analytics(),now=new Date(2026,10,15,18).getTime(),event=(m,d,n)=>({at:new Date(2026,m-1,d,10).getTime(),total_tokens:n,input_tokens:n,estimated_usd:n/100});
 a.add(event(11,15,100),'a');a.add(event(11,15,200),'b');a.add(event(11,9,50),'a');a.add(event(11,8,70),'a');a.add(event(10,31,80),'a');a.add({...event(11,15,90),at:new Date(2025,11,31).getTime()},'a');a.add(event(11,16,1000),'a');
 const s=a.snapshot(now,new Map([['a',{title:'Alpha',model:'test'}],['b',{title:'Beta'}]]));assert.equal(s.periods.day.total_tokens,300);assert.equal(s.periods.week.total_tokens,350);assert.equal(s.periods.month.total_tokens,420);assert.equal(s.periods.year.total_tokens,500);assert.equal(s.periods.day.estimated_usd,3);assert.equal(s.periods.day.sessions[0].title,'Beta');assert.equal(s.daily.find(d=>d.date==='2026-11-15').sessionCount,2);assert.equal(new Date(starts(now).week).getDate(),9);
});
test('empty history has zero totals and no invented days or sessions',()=>{const s=new Analytics().snapshot();assert.deepEqual(s.daily,[]);assert.equal(s.periods.year.total_tokens,0);assert.deepEqual(s.periods.day.sessions,[]);});
test('week spanning New Year includes previous December, annual chart does not',()=>{const a=new Analytics();a.add({at:new Date(2025,11,31,12).getTime(),total_tokens:50},'a');a.add({at:new Date(2026,0,1,12).getTime(),total_tokens:30},'a');const s=a.snapshot(new Date(2026,0,1,20).getTime());assert.equal(s.periods.week.total_tokens,80);assert.equal(s.periods.year.total_tokens,30);assert.equal(s.daily.length,1);});
test('previous years remain selectable with their own calendar and session totals',()=>{
 const a=new Analytics(),now=new Date(2026,10,15,18).getTime();
 a.add({at:new Date(2025,5,22,10).getTime(),total_tokens:45,estimated_usd:0.25},'old');
 const s=a.snapshot(now,new Map([['old',{title:'Old session'}]]),2025);
 assert.deepEqual(s.years,[2026,2025]);
 assert.equal(s.periods.year.sessions[0].title,'Old session');
 assert.equal(s.periods.year.total_tokens,45);
 assert.equal(s.periods.year.estimated_usd,0.25);
 assert.equal(s.daily[0].date,'2025-06-22');
});
test('recovered daily totals fill the gap until original logs become available',()=>{
 const a=new Analytics(),now=new Date(2026,10,15,18).getTime();
 a.recoveredDays.set('2026-11-15',{total_tokens:100,estimated_usd:1});
 a.add({at:now,total_tokens:30,estimated_usd:0.3},'a');
 assert.equal(a.snapshot(now).periods.day.total_tokens,100);
 assert.equal(a.snapshot(now).periods.day.sessions[0].title,'旧版历史（会话未知）');
 a.add({at:now,total_tokens:80,estimated_usd:0.8},'b');
 assert.equal(a.snapshot(now).periods.day.total_tokens,110);
 assert.equal(a.snapshot(now).periods.day.sessions.length,2);
});

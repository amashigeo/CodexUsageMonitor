function windowView(samples,key,now=Date.now()) {
  const last=samples.at(-1); const w=last?.limits?.[key];
  if(!w || !Number.isFinite(w.used_percent)) return null;
  const reset=w.resets_at*1000, expired=reset<=now;
  const valid=samples.filter(s=>s.at>=now-3600000 && s.at<=now && Math.abs((s.limits?.[key]?.resets_at||0)*1000-reset)<60000);
  // Only a contiguous nondecreasing sequence belongs to the same quota cycle.
  let start=valid.length-1;
  while(start>0 && valid[start-1].limits[key].used_percent<=valid[start].limits[key].used_percent) start--;
  const first=valid[start]; const elapsed=first ? last.at-first.at : 0;
  const delta=first ? w.used_percent-first.limits[key].used_percent : 0;
  const rate=!expired && elapsed>=60000 && delta>0 ? delta/(elapsed/3600000) : null;
  const used=Math.max(0,Math.min(100,w.used_percent));
  return {used,remaining:100-used,reset,expired,rate,etaHours:used>=100?0:rate?(100-used)/rate:null,minutes:w.window_minutes};
}
module.exports={windowView};

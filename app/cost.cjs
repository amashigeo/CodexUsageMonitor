const pricing=require('./pricing.json');
function estimateCost(usage,model){
 const match=Object.keys(pricing.rates).sort((a,b)=>b.length-a.length).find(k=>model===k||model?.startsWith(k+'-'));
 const [inputRate,cacheRate,outputRate,writeRate]=pricing.rates[match||pricing.fallback];
 const input=Math.max(0,usage.input_tokens||0),cached=Math.min(input,Math.max(0,usage.cached_input_tokens||0));
 const writes=Math.min(input-cached,Math.max(0,usage.cache_write_input_tokens||0)),output=Math.max(0,usage.output_tokens||0);
 const long=!!match&&input>272000;
 return {usd:((input-cached-writes)*inputRate*(long?2:1)+cached*cacheRate*(long?2:1)+writes*writeRate*(long?2:1)+output*outputRate*(long?1.5:1))/1e6,fallback:!match};
}
module.exports={estimateCost};

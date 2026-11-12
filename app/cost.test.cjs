const {test}=require('node:test'),assert=require('node:assert/strict'),{estimateCost}=require('./cost.cjs');
test('cached tokens discounted and reasoning not charged twice',()=>{
 const c=estimateCost({input_tokens:100000,cached_input_tokens:80000,output_tokens:1000,reasoning_output_tokens:500},'gpt-6.1-sol');assert.ok(Math.abs(c.usd-0.058)<1e-10);assert.equal(c.fallback,false);
});
test('mixed models, cache writes, and missing model fallback',()=>{
 assert.equal(estimateCost({input_tokens:100000},'gpt-6-astra').usd,1);
 assert.equal(estimateCost({input_tokens:100000,cache_write_input_tokens:100000},'gpt-6.1-sol').usd,0.25);
 assert.equal(estimateCost({input_tokens:100000},'unknown').fallback,true);
});
test('long context rate and model snapshots',()=>{
 assert.equal(estimateCost({input_tokens:300000,output_tokens:10000},'gpt-6.1-sol-2026-10-01').usd,1.35);
});

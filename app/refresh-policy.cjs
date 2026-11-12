function nextIdleRefresh({startedAt,lastAttempt,lastActivityAt,intervalMinutes=10}) {
 return Math.max(startedAt||0,lastAttempt||0,lastActivityAt||0)+intervalMinutes*60000;
}
module.exports={nextIdleRefresh};

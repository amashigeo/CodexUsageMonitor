function mergeResetCredits(next,previous,nowSeconds=Date.now()/1000){
 if(!next)return null;
 if(next.expiresAt)return {...next,expiryCached:false};
 if(!next.detailsKnown&&next.count>0&&next.count===previous?.count&&previous.expiresAt>nowSeconds)return {...next,expiresAt:previous.expiresAt,expiryCached:true};
 return {...next,expiryCached:false};
}
module.exports={mergeResetCredits};

import Foundation

enum PlayerHTML {
    static let document = #"""
<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#player{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style></head><body><div id="player"></div><script>
let player=null, ready=false, command=null, ended=false, seeking=false, boundaryPending=false, bootFailed=false;
function post(type,extra={}) {window.webkit?.messageHandlers.ghostVideo.postMessage({type,...extra});}
function snapshot(type='clock') {
 if(!ready || !command) return;
 const time=player.getCurrentTime()||0, state=player.getPlayerState(), id=player.getVideoData()?.video_id||'';
 if(id!==command.videoID) return;
 if(seeking) {
   if(Math.abs(time-command.start)>1.0) return;
   seeking=false;
 }
 if(state===2 || state===0) boundaryPending=false;
 if(ended && state===1 && !boundaryPending && command.end!=null && time<command.end-0.07) ended=false;
 if(command.end!=null && state===1 && time>=command.end-0.07) {
   if(ended && !boundaryPending) {ended=false;player.seekTo(command.start,true);seeking=true;return;}
   if(command.loop) {player.seekTo(command.start,true);seeking=true;return;}
   if(!ended) {ended=true;boundaryPending=true;player.pauseVideo();player.seekTo(command.end,true);}
 }
 const actualState=player.getPlayerState();
 if(actualState===2 || actualState===0) boundaryPending=false;
 post(type,{serial:command.serial,videoID:id,time,duration:player.getDuration()||0,state:actualState,rate:player.getPlaybackRate()||1,ended:ended && actualState!==1 && actualState!==3});
}
window.ghostCommand=function(c) {
 command=c;ended=false;boundaryPending=false;
 if(!ready) return;
 const same=player.getVideoData()?.video_id===c.videoID;
 seeking=c.seek || !same;
 if(!same) {
   const request={videoId:c.videoID,startSeconds:c.start};

   if(c.play) player.loadVideoById(request); else player.cueVideoById(request);
 } else {
   if(c.seek) player.seekTo(c.start,true);
   if(c.play) player.playVideo(); else player.pauseVideo();
 }
 const rates=player.getAvailablePlaybackRates();
 if(rates.length) player.setPlaybackRate(rates.reduce((a,b)=>Math.abs(b-c.rate)<Math.abs(a-c.rate)?b:a));
 snapshot();
};
function bootFailure(){if(ready || bootFailed)return;bootFailed=true;post('bootstrapError');}
setTimeout(bootFailure,25000);
function onYouTubeIframeAPIReady() {
 if(bootFailed)return;
 player=new YT.Player('player',{width:'100%',height:'100%',playerVars:{controls:0,playsinline:1,enablejsapi:1,origin:'https://com.calebwieman.ghosthands',rel:0},events:{
  onReady:()=>{if(bootFailed){player.pauseVideo();return;}ready=true;post('ready');if(command) window.ghostCommand(command);},
  onStateChange:()=>snapshot('state'),
  onPlaybackRateChange:()=>snapshot(),
  onAutoplayBlocked:()=>{snapshot();post('blocked',{serial:command?.serial,videoID:player.getVideoData()?.video_id});},
  onError:e=>post('error',{code:e.data,serial:command?.serial,videoID:player.getVideoData()?.video_id||command?.videoID})
 }});
}
setInterval(()=>snapshot(),150);
</script><script src="https://www.youtube.com/iframe_api" onerror="bootFailure()"></script></body></html>
"""#
}

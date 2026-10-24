const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(require('path').join(__dirname,'../GhostHands/PlayerHTML.swift'),'utf8').split('<script>')[1].split('</script>')[0];
let messages=[],tick,onReady,player,time=0,state=2,id='',rate=1,pauses=0,seeks=[];
const context={window:{webkit:{messageHandlers:{ghostVideo:{postMessage:m=>messages.push(m)}}}},setTimeout:()=>{},setInterval:f=>{tick=f},YT:{Player:function(_,options){onReady=options.events.onReady;player={getCurrentTime:()=>time,getPlayerState:()=>state,getVideoData:()=>({video_id:id}),getDuration:()=>264,getPlaybackRate:()=>rate,getAvailablePlaybackRates:()=>[0.25,0.5,0.75,1,1.5,2],setPlaybackRate:r=>rate=r,seekTo:t=>{seeks.push(t)},pauseVideo:()=>{state=2;pauses++},playVideo:()=>state=1,loadVideoById:c=>{id=c.videoId;time=c.startSeconds;state=1},cueVideoById:c=>{id=c.videoId;time=c.startSeconds;state=5}};return player;}}};
vm.createContext(context);vm.runInContext(source,context);
function cmd(serial,start=20,end=31,play=true){return {serial,videoID:'boat',start,end,seek:true,play,rate:0.75,loop:false}}
context.window.ghostCommand(cmd(1));context.window.ghostCommand(cmd(2,31,34));context.onYouTubeIframeAPIReady();onReady();
assert.equal(messages.at(-1).serial,2);assert.equal(time,31);assert.equal(rate,0.75);
time=34;tick();assert.equal(state,2);assert.equal(messages.at(-1).ended,true);assert.equal(messages.at(-1).state,2);
state=1;tick();assert.equal(seeks.at(-1),31); // native Play restarts action
let length=messages.length;time=32.5;context.window.ghostCommand(cmd(3,31,34));assert.equal(messages.length,length); // reject old same-segment clock
// Confirm new seek then let segment end again.
time=31;tick();assert.equal(messages.at(-1).serial,3);assert.equal(messages.at(-1).state,1);
time=34;tick();assert.equal(state,2);assert(pauses>=2);
time=32;state=1;tick();assert.equal(messages.at(-1).state,1);assert.equal(messages.at(-1).ended,false); // native scrub backward + Play
context.window.ghostCommand({...cmd(4,20,31),loop:true});time=20;tick();time=31;tick();assert.equal(seeks.at(-1),20);
context.window.ghostCommand({...cmd(5),end:undefined});time=20;tick();time=180;tick();assert.equal(messages.at(-1).state,1); // author scrub unrestricted
// Delayed pause must keep audio busy until the player acknowledges pause.
context.window.ghostCommand(cmd(6));time=20;tick();player.pauseVideo=()=>{pauses++};time=31;tick();assert.equal(messages.at(-1).state,1);assert.equal(messages.at(-1).ended,false);let seeksBefore=seeks.length;tick();assert.equal(seeks.length,seeksBefore);state=2;tick();assert.equal(messages.at(-1).ended,true);
console.log('Player controller: 8 scenarios passed (latest pending command, endpoint pause, native replay, stale seek, looping, author scrub, native scrub, delayed pause).');

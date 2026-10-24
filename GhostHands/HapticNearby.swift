#if os(iOS) || os(visionOS)
import Foundation
import Combine
import MultipeerConnectivity

// Encrypted local link with explicit one-session pairing code. Never queues taps.
final class HapticNearby:NSObject,ObservableObject,MCSessionDelegate,MCNearbyServiceBrowserDelegate,MCNearbyServiceAdvertiserDelegate {
    static let service="gh-haptics"
    @Published var status="Disconnected"
    @Published var connected=false
    @Published var watchReady=false
    @Published var latencyMS:Int?
    @Published var peers:[MCPeerID]=[]
    @Published var code=""
    private let receiver:Bool
    private let peer:MCPeerID
    private var session:MCSession!
    private var browser:MCNearbyServiceBrowser?
    private var advertiser:MCNearbyServiceAdvertiser?
    private var running=false
    private var invited:MCPeerID?
    private var readyAt:TimeInterval=0
    private var pending:[String:TimeInterval]=[:]
    var onPulse:((HapticMessage)->Void)?
    var onConnection:(()->Void)?
    init(receiver:Bool) {
        self.receiver=receiver;peer=MCPeerID(displayName:receiver ? "GhostHands iPhone" : "GhostHands Vision Pro")
        super.init();makeSession()
    }
    private func makeSession() {session=MCSession(peer:peer,securityIdentity:nil,encryptionPreference:.required);session.delegate=self}
    func start() {
        stop();running=true;makeSession()
        if receiver {
            code=String(format:"%06d",Int.random(in:0...999999))
            advertiser=MCNearbyServiceAdvertiser(peer:peer,discoveryInfo:["version":"1"],serviceType:Self.service)
            advertiser?.delegate=self;advertiser?.startAdvertisingPeer();status="Enter this code on Vision Pro"
        } else {
            browser=MCNearbyServiceBrowser(peer:peer,serviceType:Self.service)
            browser?.delegate=self;browser?.startBrowsingForPeers();status="Looking for iPhone…"
        }
    }
    func stop() {
        running=false;browser?.stopBrowsingForPeers();advertiser?.stopAdvertisingPeer();browser=nil;advertiser=nil
        session?.delegate=nil;session?.disconnect();connected=false;watchReady=false;invited=nil;readyAt=0;pending=[:];peers=[];status="Disconnected"
    }
    func pair(_ target:MCPeerID) {
        guard running,!receiver,!connected,invited==nil,code.count==6,code.allSatisfy(\.isNumber) else{return}
        invited=target;status="Pairing…";browser?.invitePeer(target,to:session,withContext:code.data(using:.utf8),timeout:12)
        DispatchQueue.main.asyncAfter(deadline:.now()+13) {[weak self] in
            guard let self,!self.connected,self.invited==target else{return};self.invited=nil;self.status="Pairing failed. Check the code and retry."
        }
    }
    func pulse() {
        let now=Date().timeIntervalSince1970
        guard running,connected,watchReady,now-readyAt<4 else {watchReady=false;return}
        let message=HapticMessage(kind:"tap");pending=pending.filter{ProcessInfo.processInfo.systemUptime-$0.value<1};pending[message.id]=ProcessInfo.processInfo.systemUptime
        send(message)
    }
    func send(_ message:HapticMessage) {
        guard running,connected,!session.connectedPeers.isEmpty,let data=message.data else{return}
        do {try session.send(data,toPeers:session.connectedPeers,with:.unreliable)}
        catch {status="Link interrupted";watchReady=false}
    }
    func session(_ session:MCSession,peer peerID:MCPeerID,didChange state:MCSessionState) {
        DispatchQueue.main.async {[weak self] in
            guard let self,self.running,self.session===session else{return}
            self.connected=state == .connected
            if state == .connected {self.status="iPhone linked";self.browser?.stopBrowsingForPeers();self.advertiser?.stopAdvertisingPeer();self.onConnection?()}
            else if state == .notConnected {self.watchReady=false;self.invited=nil;self.status="Disconnected — restart pairing"}
        }
    }
    func session(_ session:MCSession,didReceive data:Data,fromPeer peerID:MCPeerID) {
        guard let message=HapticMessage.decode(data) else{return}
        DispatchQueue.main.async {[weak self] in
            guard let self,self.running,self.session===session,session.connectedPeers.contains(peerID) else{return}
            if self.receiver,message.kind=="tap" {self.onPulse?(message)}
            else if !self.receiver,message.kind=="state" {
                self.watchReady=message.ready == true;self.readyAt=Date().timeIntervalSince1970
                self.status=message.note ?? (self.watchReady ? "Watch ready" : "Open the Watch app")
            } else if !self.receiver,message.kind=="ack",let start=self.pending.removeValue(forKey:message.id) {
                if message.ready == true {self.latencyMS=Int((ProcessInfo.processInfo.systemUptime-start)*1000)}
                else {self.status=message.note ?? "Tap dropped"}
            }
        }
    }
    func browser(_ browser:MCNearbyServiceBrowser,foundPeer peerID:MCPeerID,withDiscoveryInfo info:[String:String]?) {
        DispatchQueue.main.async {[weak self] in guard let self,self.running,self.browser===browser,info?["version"]=="1" else{return};if !self.peers.contains(peerID) {self.peers.append(peerID)}}
    }
    func browser(_ browser:MCNearbyServiceBrowser,lostPeer peerID:MCPeerID) {DispatchQueue.main.async {[weak self] in guard let self,self.running,self.browser===browser else{return};self.peers.removeAll{$0==peerID}}}
    func browser(_ browser:MCNearbyServiceBrowser,didNotStartBrowsingForPeers error:Error) {DispatchQueue.main.async {[weak self] in guard let self,self.running,self.browser===browser else{return};self.status="Allow Local Network access, then retry"}}
    func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID:MCPeerID,withContext context:Data?,invitationHandler:@escaping(Bool,MCSession?)->Void) {
        DispatchQueue.main.async {[weak self] in
            guard let self,self.running,self.advertiser===advertiser,!self.connected,self.invited==nil,
                  let context,context.count==6,String(data:context,encoding:.utf8)==self.code else {invitationHandler(false,nil);return}
            self.invited=peerID;invitationHandler(true,self.session)
        }
    }
    func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error:Error) {DispatchQueue.main.async {[weak self] in guard let self,self.running,self.advertiser===advertiser else{return};self.status="Allow Local Network access, then retry"}}
    func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID) {}
    func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress) {}
    func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?) {}
}
#endif

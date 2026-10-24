#if os(iOS) || os(visionOS)
import Foundation
import Combine
import MultipeerConnectivity

// Encrypted local link with explicit one-session pairing code. Never queues taps.
final class HapticNearby:NSObject,ObservableObject,MCSessionDelegate,MCNearbyServiceBrowserDelegate,MCNearbyServiceAdvertiserDelegate {
    static let service="gh-haptics-v2"
    @Published var status="Disconnected"
    @Published var connected=false
    @Published var watchReady=false
    @Published var latencyMS:Int?
    @Published var peers:[MCPeerID]=[]
    @Published var code=""
    private let receiver:Bool
    private let peer:MCPeerID
    private let installationID:String
    var deviceLabel:String {peer.displayName}
    private var peerInstallations:[MCPeerID:String]=[:]
    private var activePeer:MCPeerID?
    private var attemptID=UUID()
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
        self.receiver=receiver
        let defaults=UserDefaults.standard
        let storedID=defaults.string(forKey:"haptics.installationID") ?? UUID().uuidString
        installationID=storedID;defaults.set(storedID,forKey:"haptics.installationID")
        if let data=defaults.data(forKey:"haptics.peer.v2"),let saved=try? NSKeyedUnarchiver.unarchivedObject(ofClass:MCPeerID.self,from:data) {peer=saved}
        else {
            let label=(receiver ? "iPhone " : "Vision Pro ")+String(storedID.prefix(4))
            peer=MCPeerID(displayName:label)
            if let data=try? NSKeyedArchiver.archivedData(withRootObject:peer,requiringSecureCoding:true) {defaults.set(data,forKey:"haptics.peer.v2")}
        }
        super.init();makeSession()
    }
    private static var advertisedRole:String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "phone"
        #endif
    }
    private func makeSession() {session=MCSession(peer:peer,securityIdentity:nil,encryptionPreference:.required);session.delegate=self}
    func start() {
        stop();running=true;makeSession()
        if receiver {
            code=String(format:"%06d",Int.random(in:0...999999))
            advertiser=MCNearbyServiceAdvertiser(peer:peer,discoveryInfo:["version":"2","role":Self.advertisedRole,"installation":installationID],serviceType:Self.service)
            advertiser?.delegate=self;advertiser?.startAdvertisingPeer();status="Enter this code on Vision Pro"
        } else {
            browser=MCNearbyServiceBrowser(peer:peer,serviceType:Self.service)
            browser?.delegate=self;browser?.startBrowsingForPeers();status="Looking for iPhone…"
        }
    }
    func stop() {
        running=false;browser?.stopBrowsingForPeers();advertiser?.stopAdvertisingPeer();browser=nil;advertiser=nil
        session?.delegate=nil;session?.disconnect();connected=false;watchReady=false;invited=nil;activePeer=nil;attemptID=UUID();readyAt=0;pending=[:];peers=[];peerInstallations=[:];status="Disconnected"
    }
    func pair(_ target:MCPeerID) {
        guard running,!receiver,!connected,invited==nil,code.count==6,code.allSatisfy(\.isNumber) else{return}
        // Retire the failed attempt's session so late callbacks cannot disconnect its replacement.
        session.delegate=nil;session.disconnect();makeSession()
        attemptID=UUID();let attempt=attemptID
        invited=target;status="Pairing with \(target.displayName)…";browser?.invitePeer(target,to:session,withContext:code.data(using:.utf8),timeout:12)
        expireInvitation(target,attempt:attempt)
    }
    private func expireInvitation(_ target:MCPeerID,attempt:UUID) {
        DispatchQueue.main.asyncAfter(deadline:.now()+13) {[weak self] in
            guard let self,self.running,self.attemptID==attempt,!self.connected,self.invited==target else{return}
            self.session.delegate=nil;self.session.disconnect();self.makeSession()
            self.invited=nil;self.attemptID=UUID()
            self.status="Check the current code; keep the iPhone app open."
            if self.receiver {self.advertiser?.startAdvertisingPeer()}
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
            guard peerID==self.invited || peerID==self.activePeer else{return}
            if state == .connected {
                self.connected=true;self.activePeer=peerID;self.invited=nil
                self.status=self.receiver ? "Vision Pro linked" : "iPhone linked"
                self.browser?.stopBrowsingForPeers();self.advertiser?.stopAdvertisingPeer();self.onConnection?()
            } else if state == .notConnected {
                let wasConnected=self.activePeer==peerID
                self.connected=false;self.watchReady=false;self.invited=nil;self.activePeer=nil
                self.status=wasConnected ? "Link lost. Keep iPhone app open; restart pairing." : "Check the current code; keep iPhone app open."
                if self.receiver {self.advertiser?.startAdvertisingPeer()}
                else {self.browser?.startBrowsingForPeers()}
            }
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
        DispatchQueue.main.async {[weak self] in
            guard let self,self.running,self.browser===browser,info?["version"]=="2",info?["role"]=="phone",
                  let installation=info?["installation"],UUID(uuidString:installation) != nil else{return}
            // A restarted app may briefly leave a stale discovery entry. One row per installation.
            self.peers.removeAll {old in old != peerID && self.peerInstallations[old]==installation}
            self.peerInstallations[peerID]=installation
            if !self.peers.contains(peerID) {self.peers.append(peerID)}
        }
    }
    func browser(_ browser:MCNearbyServiceBrowser,lostPeer peerID:MCPeerID) {DispatchQueue.main.async {[weak self] in guard let self,self.running,self.browser===browser else{return};self.peers.removeAll{$0==peerID}}}
    func browser(_ browser:MCNearbyServiceBrowser,didNotStartBrowsingForPeers error:Error) {DispatchQueue.main.async {[weak self] in guard let self,self.running,self.browser===browser else{return};self.status="Allow Local Network access, then retry"}}
    func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID:MCPeerID,withContext context:Data?,invitationHandler:@escaping(Bool,MCSession?)->Void) {
        DispatchQueue.main.async {[weak self] in
            guard let self,self.running,self.advertiser===advertiser,!self.connected,self.invited==nil,
                  let context,context.count==6,String(data:context,encoding:.utf8)==self.code else {invitationHandler(false,nil);return}
            self.session.delegate=nil;self.session.disconnect();self.makeSession()
            self.attemptID=UUID();self.invited=peerID
            self.expireInvitation(peerID,attempt:self.attemptID)
            invitationHandler(true,self.session)
        }
    }
    func advertiser(_ advertiser:MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error:Error) {DispatchQueue.main.async {[weak self] in guard let self,self.running,self.advertiser===advertiser else{return};self.status="Allow Local Network access, then retry"}}
    func session(_ session:MCSession,didReceive stream:InputStream,withName streamName:String,fromPeer peerID:MCPeerID) {}
    func session(_ session:MCSession,didStartReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,with progress:Progress) {}
    func session(_ session:MCSession,didFinishReceivingResourceWithName resourceName:String,fromPeer peerID:MCPeerID,at localURL:URL?,withError error:Error?) {}
}
#endif

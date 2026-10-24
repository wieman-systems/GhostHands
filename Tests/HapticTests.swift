import XCTest
@testable import GhostHandsCore
final class HapticTests:XCTestCase {
    func testOnlyKnownLeftPressFiresOnceInEitherCallbackOrder() {
        var a=LeftButtonPulse()
        XCTAssertFalse(a.hand(true,enabled:true));XCTAssertTrue(a.press(true,enabled:true))
        XCTAssertFalse(a.hand(true,enabled:true));XCTAssertFalse(a.press(true,enabled:true))
        XCTAssertFalse(a.press(false,enabled:true));XCTAssertFalse(a.press(true,enabled:true))
        XCTAssertTrue(a.hand(true,enabled:true))
    }
    func testRightUnknownDisabledAndCancelledInputsStaySilent() {
        var a=LeftButtonPulse()
        XCTAssertFalse(a.hand(false,enabled:true));XCTAssertFalse(a.press(true,enabled:true))
        a.reset();XCTAssertFalse(a.hand(true,enabled:false));XCTAssertFalse(a.press(true,enabled:false))
        a.reset();XCTAssertFalse(a.press(true,enabled:true))
    }
    func testRejectsStaleFutureUnavailableAndDuplicatePulse() {
        var gate=HapticPulseGate();let p=HapticMessage(kind:"tap",sentAt:100)
        XCTAssertFalse(gate.accept(p,now:100.1,available:false))
        XCTAssertFalse(gate.accept(p,now:100.1,available:true))
        XCTAssertFalse(gate.accept(HapticMessage(kind:"tap",sentAt:100),now:100.7,available:true))
        XCTAssertFalse(gate.accept(HapticMessage(kind:"tap",sentAt:100),now:99,available:true))
        let fresh=HapticMessage(kind:"tap",sentAt:100)
        XCTAssertTrue(gate.accept(fresh,now:100.1,available:true))
        XCTAssertFalse(gate.accept(fresh,now:100.3,available:true))
    }
    func testBurstsDropRatherThanQueueAndNormalNextTapWorks() {
        var gate=HapticPulseGate()
        XCTAssertTrue(gate.accept(HapticMessage(kind:"tap",sentAt:100),now:100,available:true))
        let burst=HapticMessage(kind:"tap",sentAt:100.02)
        XCTAssertFalse(gate.accept(burst,now:100.02,available:true))
        XCTAssertFalse(gate.accept(burst,now:100.2,available:true))
        XCTAssertTrue(gate.accept(HapticMessage(kind:"tap",sentAt:100.3),now:100.3,available:true))
    }
    func testWireValidationRejectsInvalidAndOversizedMessages() {
        XCTAssertNil(HapticMessage.decode(Data(repeating:65,count:2049)))
        XCTAssertNil(HapticMessage.decode(HapticMessage(kind:"anything").data!))
        XCTAssertNil(HapticMessage.decode(HapticMessage(kind:"tap",id:"bad").data!))
        XCTAssertNil(HapticMessage.decode(HapticMessage(kind:"state",note:String(repeating:"a",count:121)).data!))
        let p=HapticMessage(kind:"tap");XCTAssertEqual(HapticMessage.decode(p.data!)?.id,p.id)
        var gate=HapticPulseGate();XCTAssertFalse(gate.accept(HapticMessage(kind:"state",sentAt:100),now:100,available:true))
    }
}

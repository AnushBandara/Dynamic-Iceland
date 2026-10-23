import Testing
@testable import DynamicIsland

@Test func batteryAlertsOnPlugInAndLowThresholds() {
    #expect(Battery.alert(wasOnAC: nil, isOnAC: true, oldLevel: 0, newLevel: 57) == nil) // first reading
    #expect(Battery.alert(wasOnAC: false, isOnAC: true, oldLevel: 57, newLevel: 57) == .charging)
    #expect(Battery.alert(wasOnAC: true, isOnAC: true, oldLevel: 57, newLevel: 58) == nil)
    #expect(Battery.alert(wasOnAC: false, isOnAC: false, oldLevel: 21, newLevel: 20) == .low)
    #expect(Battery.alert(wasOnAC: false, isOnAC: false, oldLevel: 20, newLevel: 19) == nil) // already warned
    #expect(Battery.alert(wasOnAC: false, isOnAC: false, oldLevel: 11, newLevel: 10) == .low)
    #expect(Battery.alert(wasOnAC: true, isOnAC: true, oldLevel: 21, newLevel: 20) == nil)  // charging, not low
}

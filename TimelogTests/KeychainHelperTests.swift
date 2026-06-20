import Testing
import Foundation
import TimelogCore

@Suite("KeychainHelper")
struct KeychainHelperTests {

    @Test func saveReturnsTrue() {
        let key = "test_kc_\(UUID().uuidString)"
        let result = KeychainHelper.save(key: key, value: "hello")
        #expect(result == true)
        KeychainHelper.delete(key: key)
    }

    @Test func readAfterSaveReturnsValue() {
        let key = "test_kc_\(UUID().uuidString)"
        KeychainHelper.save(key: key, value: "timelog")
        #expect(KeychainHelper.read(key: key) == "timelog")
        KeychainHelper.delete(key: key)
    }

    @Test func readMissingKeyReturnsNil() {
        let key = "test_kc_missing_\(UUID().uuidString)"
        #expect(KeychainHelper.read(key: key) == nil)
    }

    @Test func deleteReturnsTrue() {
        let key = "test_kc_\(UUID().uuidString)"
        KeychainHelper.save(key: key, value: "value")
        let deleted = KeychainHelper.delete(key: key)
        #expect(deleted == true)
    }

    @Test func readAfterDeleteReturnsNil() {
        let key = "test_kc_\(UUID().uuidString)"
        KeychainHelper.save(key: key, value: "value")
        KeychainHelper.delete(key: key)
        #expect(KeychainHelper.read(key: key) == nil)
    }

    @Test func updateExistingKeyReturnsNewValue() {
        let key = "test_kc_\(UUID().uuidString)"
        KeychainHelper.save(key: key, value: "first")
        KeychainHelper.save(key: key, value: "second")
        #expect(KeychainHelper.read(key: key) == "second")
        KeychainHelper.delete(key: key)
    }
}

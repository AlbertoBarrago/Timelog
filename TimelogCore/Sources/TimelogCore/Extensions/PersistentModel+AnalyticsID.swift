import SwiftData

public extension PersistentModel {
    /// Stable per-store identity for analytics grouping and chart series keys.
    ///
    /// Analytics used to key off the sync `mongoId`; with sync gone, the SwiftData
    /// persistent identifier is the only identity that survives across app launches.
    /// It is store-local, so it must never be persisted or shown to the user.
    var analyticsID: String { String(describing: persistentModelID) }
}

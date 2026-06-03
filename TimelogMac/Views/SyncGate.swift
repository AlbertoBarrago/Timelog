import SwiftUI
import TimelogSync

extension View {
    func syncGated(while presented: Binding<Bool>) -> some View {
        self.onChange(of: presented.wrappedValue) { _, isPresented in
            RestSyncService.shared.isUserEditing = isPresented
        }
    }

    func syncGated<T>(whilePresent item: Binding<T?>) -> some View {
        self.onChange(of: item.wrappedValue == nil) { _, isNil in
            RestSyncService.shared.isUserEditing = !isNil
        }
    }
}

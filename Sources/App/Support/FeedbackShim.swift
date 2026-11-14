#if !canImport(UIKit)
import SwiftUI

/// Feedback's capture needs UIKit, so on macOS its tags compile to nothing and the views stay shared.
extension View {
    func feedback(_ name: String, data: Any? = nil) -> some View { self }
    func feedback<V: View>(_ view: V) -> some View { self }
}
#endif

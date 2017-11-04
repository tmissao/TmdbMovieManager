import Foundation


/// Abstraction for performing updates on Main Thread
///
/// - Parameter updates: Function to be executed on main Thread
func performUIUpdatesOnMain(_ updates: @escaping () -> Void) {
  DispatchQueue.main.async {
    updates()
  }
}

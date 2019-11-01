import Foundation

/// An object that coordinates the operation of multiple threads of execution within the same application.
internal final class UnfairLock: NSLocking {
  private var unfairLock: os_unfair_lock_t

  internal init() {
    unfairLock = .allocate(capacity: 1)
    unfairLock.initialize(to: os_unfair_lock())
  }

  internal func lock() {
    os_unfair_lock_lock(unfairLock)
  }

  internal func unlock() {
    os_unfair_lock_unlock(unfairLock)
  }

  deinit {
    unfairLock.deinitialize(count: 1)
    unfairLock.deallocate()
  }
}

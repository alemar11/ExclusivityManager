import Foundation

internal let identifier = "org.tinrobots.ExclusivityManager"

public final class ExclusivityManager {
  public static let shared = ExclusivityManager()

  private enum Exclusivity {
    case available
    case notAvailable
  }

  let dispatchGroupsQueue: DispatchQueue
  /// The private queue used for thread safe operations.
  private let queue: DispatchQueue = DispatchQueue(label: identifier, qos: .userInitiated) // an high priority qos is needed to avoid thread starvation
  private var categories: [String: [DispatchGroup]] = [:]

  /// Creates a new `ExclusivityManager` instance.
  internal init(qos: DispatchQoS = .userInitiated) {
    // https://www.fivestars.blog/code/semaphores.html
    dispatchGroupsQueue = DispatchQueue(label: "\(identifier).DispatchGroupsQueue.\(UUID().uuidString)", qos: qos, attributes: [.concurrent])
  }

  public func lock(for categories: Set<String>, onAvailability completion: @escaping (Token) -> Void) {
    queue.async {
      self._lock(for: categories, completion: completion)
    }
  }

  private func _lock(for categories: Set<String>, completion: @escaping (Token) -> Void) {
    let dipatchGroup = DispatchGroup()
    let token = Token(categories: categories) { [weak self] categories in
      self?.unlock(categories: categories)
    }

    let notAvailableCategoriesCount = categories
      .map { registerDispatchGroup(dipatchGroup, forCategory: $0) }
      .filter { $0 == .notAvailable }
      .count

    if notAvailableCategoriesCount == 0 {
      // the item is free to acquire the exclusivity lock without waiting
      completion(token)
    } else {
      // the item requesting the exclusivity lock will wait until the group is empty
      (0..<notAvailableCategoriesCount).forEach { _ in dipatchGroup.enter() }
      // only then the completion block will be called
      dipatchGroup.notify(queue: dispatchGroupsQueue) {
        completion(token)
      }
    }
  }

  /// Associates a DispatchGroup with a category and returns the exclusivity state for that category.
  private func registerDispatchGroup(_ group: DispatchGroup, forCategory category: String) -> Exclusivity {
    var groupsByCategory = categories[category] ?? []
    let isCategoryAvailable = groupsByCategory.isEmpty
    groupsByCategory.append(group)
    categories[category] = groupsByCategory
    return isCategoryAvailable ? .available : .notAvailable
  }

  private func unlock(categories: Set<String>) {
    queue.async {
      categories.forEach { self.unlock(category: $0) }
    }
  }

  private func unlock(category: String) {
    guard var groupsByCategory = categories[category], !groupsByCategory.isEmpty else {
      return
    }

    // Removes the first item (that has currently the exclusivity lock) for this category.
    _ = groupsByCategory.removeFirst()

    // If there is an item waiting for this category
    if let nextDispatchGroup = groupsByCategory.first {
      // leave its DispatchGroup (it "acquires" the exclusivity lock for this category)
      nextDispatchGroup.leave()
    }

    if !groupsByCategory.isEmpty {
      categories[category] = groupsByCategory
    } else {
      categories.removeValue(forKey: category)
    }
  }
}

extension ExclusivityManager {
  public final class Token {
    public let categories: Set<String>
    private var unlockClosure: ((Set<String>) -> Void)?
    private let lock = UnfairLock()

    fileprivate init(categories: Set<String>, unlockClosure: @escaping (Set<String>) -> Void) {
      self.categories = categories
      self.unlockClosure = unlockClosure
    }

    public func unlock() {
      lock.lock()
      defer { lock.unlock() }

      unlockClosure?(categories)
      // the token is consumed and cannot be used again
      unlockClosure = nil
    }
  }
}

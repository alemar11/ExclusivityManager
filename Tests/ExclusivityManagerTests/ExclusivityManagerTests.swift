import XCTest
@testable import ExclusivityManager

final class ExclusivityManagerTests: XCTestCase {
  func testMutuallyExclusivityWithMultipleQueues() {
    let manager = ExclusivityManager()
    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    // it's atomic because 1 and 3 can access ouput at the same time
    // because their exclusivity categories are completely different
    var output = ""
    let lock = UnfairLock()

    // 1
    manager.lock(for: Set(arrayLiteral: "A", "B")) { token in
      DispatchQueue(label: "1").async {
        sleep(3)
        lock.lock()
        output += "1"
        lock.unlock()

        token.unlock()

        expectation1.fulfill()
      }
    }

    // 2
    manager.lock(for: Set(arrayLiteral: "A", "B", "C")) { token in
      DispatchQueue(label: "2").async {
        lock.lock()
        output += "2"
        lock.unlock()

        token.unlock()

        expectation2.fulfill()
      }
    }

    // 3
    manager.lock(for: Set(arrayLiteral: "C")) { token in
      DispatchQueue(label: "3").async {
        sleep(1)
        lock.lock()
        output += "3"
        lock.unlock()

        token.unlock()

        expectation3.fulfill()
      }
    }

    wait(for: [expectation1, expectation2, expectation3], timeout: 10)
    XCTAssertEqual(output, "123")
  }

  func testMutuallyExclusivityInLoop() {
    let manager = ExclusivityManager()

    // There shouldn't be any access races becuase all the blocks are driven by the
    // same exclusivity category
    var output = [Int]()

    var expectations = [XCTestExpectation]()

    (1...100).forEach { i in
      let exp = XCTestExpectation(description: "\(i)")
      expectations.append(exp)
      DispatchQueue.global().async {
        manager.lock(for: Set(arrayLiteral: "Exclusivity")) { token in
          DispatchQueue(label: "\(i)").async {
            output.append(i)
            token.unlock()
            exp.fulfill()
          }
        }
      }
    }
    wait(for: expectations, timeout: 5)

    let expectedSet = Set(Array(1...100))
    XCTAssertEqual(output.count, 100)
    XCTAssertEqual(output.count, expectedSet.count)
    let result = expectedSet.symmetricDifference(Set(output))
    XCTAssertTrue(result.isEmpty)
  }

  static var allTests = [
    ("testMutuallyExclusivityWithMultipleQueues", testMutuallyExclusivityWithMultipleQueues),
    ("testMutuallyExclusivityInLoop", testMutuallyExclusivityInLoop)
  ]
}

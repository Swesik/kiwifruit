import XCTest
@testable import kiwifruit

final class BookSearchAndUserBooksTests: XCTestCase {

    func testBookSearchViewModelReturnsMockResult() async throws {
        let api = MockAPIClient()
        let vm = BookSearchViewModel(api: api)
        vm.query = "Some query"

        await vm.submit()

        XCTAssertFalse(vm.results.isEmpty, "Expected mock results to be returned")
        XCTAssertEqual(vm.results.count, 1)
        XCTAssertTrue(vm.results[0].title.contains("Mock result"))
    }

    func testUserBooksStoreAddAndPreventDuplicateByISBN() throws {
        let store = UserBooksStore(loadSaved: false)

        let b1 = UserBook(title: "Title A", authors: ["Author"], isbn13: "1112223334445")
        let b2 = UserBook(title: "Title B", authors: ["Author B"], isbn13: nil)
        let b3 = UserBook(title: "Title A", authors: ["Author"], isbn13: "1112223334445")

        store.reset()
        XCTAssertEqual(store.items.count, 0)

        store.add(b1)
        XCTAssertEqual(store.items.count, 1)

        // duplicate by ISBN should be ignored
        store.add(b3)
        XCTAssertEqual(store.items.count, 1)

        store.add(b2)
        XCTAssertEqual(store.items.count, 2)

        // remove
        store.remove(id: b1.id)
        XCTAssertEqual(store.items.count, 1)
    }

    func testUserBooksStorePreventDuplicateByTitleAuthors() throws {
        let store = UserBooksStore(loadSaved: false)
        store.reset()

        let b1 = UserBook(title: "Same Title", authors: ["A1", "A2"], isbn13: nil)
        let b2 = UserBook(title: "Same Title", authors: ["A1", "A2"], isbn13: nil)

        store.add(b1)
        XCTAssertEqual(store.items.count, 1)

        store.add(b2)
        XCTAssertEqual(store.items.count, 1, "Duplicate by title+authors should be ignored")
    }
}

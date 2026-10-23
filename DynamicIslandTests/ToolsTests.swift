import Foundation
import Testing
@testable import DynamicIsland

@Test func todosAddToTopAndRoundTripThroughJSON() {
    var todos = Todos.adding("Buy milk", to: [])
    todos = Todos.adding("  ", to: todos) // blank: ignored
    todos = Todos.adding("Call Nimal ", to: todos)
    #expect(todos.map(\.title) == ["Call Nimal", "Buy milk"])
    todos[1].isDone = true
    #expect(Todos.decode(Todos.encode(todos)) == todos)
    #expect(Todos.decode("not json").isEmpty)
}

@Test func pinnedShortcutsToggleByName() {
    var stored = ShortcutsRunner.toggling("Make GIF", in: "")
    stored = ShortcutsRunner.toggling("Battery Stats", in: stored)
    #expect(ShortcutsRunner.pinned(stored) == ["Make GIF", "Battery Stats"])
    stored = ShortcutsRunner.toggling("Make GIF", in: stored)
    #expect(ShortcutsRunner.pinned(stored) == ["Battery Stats"])
}

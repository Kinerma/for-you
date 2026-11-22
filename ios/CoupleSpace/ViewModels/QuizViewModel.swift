import SwiftUI
import Observation

enum QuizMode: Hashable {
    case questions, answers, guess
}

@Observable
final class QuizViewModel {
    var mode: QuizMode = .questions
    var categoryFilter: String?     // nil = все категории
    var index = 0

    var filtered: [QuizQuestion] {
        let all = QuestionBank.shared.questions
        guard let categoryFilter else { return all }
        return all.filter { $0.category == categoryFilter }
    }

    var current: QuizQuestion? {
        let list = filtered
        guard !list.isEmpty else { return nil }
        return list[min(max(index, 0), list.count - 1)]
    }

    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < filtered.count - 1 }

    func setFilter(_ category: String?) {
        categoryFilter = category
        index = 0
    }

    func next() { if canGoForward { index += 1 } }
    func previous() { if canGoBack { index -= 1 } }

    func focus(on questionId: String) {
        mode = .questions
        categoryFilter = nil
        if let i = QuestionBank.shared.questions.firstIndex(where: { $0.id == questionId }) {
            index = i
        }
    }

    /// После ответа перейти к следующему неотвеченному в текущем списке.
    func advanceToNextUnanswered(isAnswered: (QuizQuestion) -> Bool) {
        let list = filtered
        guard !list.isEmpty else { return }
        for step in 1..<max(list.count, 2) {
            let i = (index + step) % list.count
            if !isAnswered(list[i]) { index = i; return }
        }
    }
}

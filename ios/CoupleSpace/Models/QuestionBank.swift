import Foundation

/// Встроенные вопросы из Resources/couple_quiz_questions.json (тексты сразу на трёх языках).
final class QuestionBank {
    static let shared = QuestionBank()

    let categories: [QuizCategory]
    let questions: [QuizQuestion]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "couple_quiz_questions", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(QuestionBankFile.self, from: data)
        else {
            assertionFailure("couple_quiz_questions.json is missing or invalid")
            categories = []
            questions = []
            return
        }
        categories = file.categories
        questions = file.questions
    }

    func question(id: String) -> QuizQuestion? {
        questions.first { $0.id == id }
    }

    func category(id: String) -> QuizCategory? {
        categories.first { $0.id == id }
    }
}

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Синхронизация в реальном времени через Firestore.
/// Схема (ТЗ, раздел 6):
/// rooms/{roomId} { meta: {...} } + moods / quizAnswers / events / ideas
final class FirestoreBackend: RoomBackend {
    let isCloud = true

    private lazy var db = Firestore.firestore()
    private var room: DocumentReference?
    private var listeners: [ListenerRegistration] = []

    // MARK: Connect

    func connect(roomId: String, onUpdate: @escaping (RoomUpdate) -> Void) {
        disconnect()
        let ref = db.collection("rooms").document(roomId)
        room = ref
        signInIfNeeded { [weak self] in
            guard let self, self.room?.documentID == ref.documentID else { return }
            self.attachListeners(to: ref, onUpdate: onUpdate)
        }
    }

    func disconnect() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        room = nil
    }

    /// Правила Firestore пускают только авторизованных: используем анонимный вход.
    private func signInIfNeeded(_ then: @escaping () -> Void) {
        if Auth.auth().currentUser != nil {
            then()
            return
        }
        Auth.auth().signInAnonymously { _, error in
            if let error { print("Anonymous sign-in failed:", error.localizedDescription) }
            then()
        }
    }

    private func attachListeners(to ref: DocumentReference, onUpdate: @escaping (RoomUpdate) -> Void) {
        listeners.append(ref.addSnapshotListener { snapshot, _ in
            let meta = snapshot?.data(with: .estimate)?["meta"] as? [String: Any] ?? [:]
            onUpdate(.meta(RoomMeta(
                createdAt: (meta["createdAt"] as? Timestamp)?.dateValue(),
                partnerAName: meta["partnerAName"] as? String,
                partnerBName: meta["partnerBName"] as? String,
                langA: meta["langA"] as? String,
                langB: meta["langB"] as? String,
                pinHash: meta["pinHash"] as? String
            )))
        })

        listeners.append(ref.collection("moods").addSnapshotListener { snapshot, _ in
            var result: [Partner: Mood] = [:]
            for doc in snapshot?.documents ?? [] {
                guard let partner = Partner(rawValue: doc.documentID) else { continue }
                let d = doc.data(with: .estimate)
                result[partner] = Mood(
                    emoji: d["emoji"] as? String ?? "",
                    text: d["text"] as? String ?? "",
                    updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            onUpdate(.moods(result))
        })

        listeners.append(ref.collection("quizAnswers").addSnapshotListener { snapshot, _ in
            var result: [String: QuizAnswer] = [:]
            for doc in snapshot?.documents ?? [] {
                let d = doc.data(with: .estimate)
                result[doc.documentID] = QuizAnswer(
                    questionId: doc.documentID,
                    category: d["category"] as? String ?? "",
                    type: d["type"] as? String ?? "",
                    answerA: d["answerA"] as? String,
                    answerB: d["answerB"] as? String,
                    updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            onUpdate(.answers(result))
        })

        listeners.append(ref.collection("events").addSnapshotListener { snapshot, _ in
            let events: [PlanEvent] = (snapshot?.documents ?? []).compactMap { doc in
                let d = doc.data()
                guard let title = d["title"] as? String, let date = d["date"] as? String else { return nil }
                let time = d["time"] as? String
                return PlanEvent(
                    id: doc.documentID,
                    title: title,
                    date: date,
                    time: (time?.isEmpty ?? true) ? nil : time,
                    category: PlanCategory(rawValue: d["category"] as? String ?? "") ?? .special,
                    note: d["note"] as? String ?? "",
                    createdBy: Partner(rawValue: d["createdBy"] as? String ?? "") ?? .a
                )
            }
            onUpdate(.events(events))
        })

        listeners.append(ref.collection("ideas").addSnapshotListener { snapshot, _ in
            let ideas: [Idea] = (snapshot?.documents ?? []).compactMap { doc in
                let d = doc.data()
                guard let title = d["title"] as? String else { return nil }
                return Idea(
                    id: doc.documentID,
                    title: title,
                    category: PlanCategory(rawValue: d["category"] as? String ?? "") ?? .special,
                    note: d["note"] as? String ?? "",
                    createdBy: Partner(rawValue: d["createdBy"] as? String ?? "") ?? .a,
                    isScheduled: d["isScheduled"] as? Bool ?? false
                )
            }
            onUpdate(.ideas(ideas))
        })
    }

    // MARK: Writes

    private func write(_ block: @escaping (DocumentReference) -> Void) {
        guard let ref = room else { return }
        signInIfNeeded { block(ref) }
    }

    func createRoom() {
        write { $0.setData(["meta": ["createdAt": FieldValue.serverTimestamp()]], merge: true) }
    }

    func setProfile(name: String, language: AppLanguage, for partner: Partner) {
        write {
            $0.setData(["meta": [
                "partner\(partner.rawValue)Name": name,
                "lang\(partner.rawValue)": language.rawValue,
            ]], merge: true)
        }
    }

    func setPinHash(_ hash: String) {
        write { $0.setData(["meta": ["pinHash": hash]], merge: true) }
    }

    func setMood(_ mood: Mood, for partner: Partner) {
        write {
            $0.collection("moods").document(partner.rawValue).setData([
                "emoji": mood.emoji,
                "text": mood.text,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    func setAnswer(_ value: String, question: QuizQuestion, for partner: Partner) {
        write {
            $0.collection("quizAnswers").document(question.id).setData([
                "category": question.category,
                "type": question.type.rawValue,
                "answer\(partner.rawValue)": value,
                "updatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
        }
    }

    func saveEvent(_ event: PlanEvent) {
        write {
            $0.collection("events").document(event.id).setData([
                "title": event.title,
                "date": event.date,
                "time": event.time ?? "",
                "category": event.category.rawValue,
                "note": event.note,
                "createdBy": event.createdBy.rawValue,
            ])
        }
    }

    func deleteEvent(id: String) {
        write { $0.collection("events").document(id).delete() }
    }

    func saveIdea(_ idea: Idea) {
        write {
            $0.collection("ideas").document(idea.id).setData([
                "title": idea.title,
                "category": idea.category.rawValue,
                "note": idea.note,
                "createdBy": idea.createdBy.rawValue,
                "isScheduled": idea.isScheduled,
            ])
        }
    }

    func deleteIdea(id: String) {
        write { $0.collection("ideas").document(id).delete() }
    }
}

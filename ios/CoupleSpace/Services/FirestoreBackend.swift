import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
                pinHash: meta["pinHash"] as? String,
                relationshipStartDate: (meta["relationshipStartDate"] as? Timestamp)?.dateValue()
            )))
        })

        listeners.append(ref.collection("moods").addSnapshotListener { snapshot, _ in
            var result: [Partner: Mood] = [:]
            for doc in snapshot?.documents ?? [] {
                guard let partner = Partner(rawValue: doc.documentID) else { continue }
                let d = doc.data(with: .estimate)
                result[partner] = Mood(
                    emoji: d["emoji"] as? String ?? "",
                    text: d["statusText"] as? String ?? d["text"] as? String ?? "",
                    updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    status: d["status"] as? String,
                    energyLevel: d["energyLevel"] as? Int,
                    needTag: d["needTag"] as? String
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
                    updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    reactionA: (d["reactions"] as? [String: Any])?["partnerA"] as? String,
                    reactionB: (d["reactions"] as? [String: Any])?["partnerB"] as? String
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

        listeners.append(ref.collection("coupons").addSnapshotListener { snapshot, _ in
            let coupons: [Coupon] = (snapshot?.documents ?? []).compactMap { doc in
                let d = doc.data(with: .estimate)
                guard let title = d["title"] as? String,
                      let createdBy = Partner(rawValue: d["createdBy"] as? String ?? ""),
                      let recipient = Partner(rawValue: d["recipientId"] as? String ?? "") else { return nil }
                return Coupon(
                    id: doc.documentID,
                    title: title,
                    description: d["description"] as? String ?? "",
                    emoji: d["emoji"] as? String ?? "🎁",
                    createdBy: createdBy,
                    recipientId: recipient,
                    isScratched: d["isScratched"] as? Bool ?? false,
                    isRedeemed: d["isRedeemed"] as? Bool ?? false,
                    redeemedAt: (d["redeemedAt"] as? Timestamp)?.dateValue(),
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            onUpdate(.coupons(coupons))
        })

        listeners.append(ref.collection("swipeSessions").addSnapshotListener { snapshot, _ in
            let sessions: [SwipeSession] = (snapshot?.documents ?? []).map { doc in
                let d = doc.data(with: .estimate)
                return SwipeSession(
                    id: doc.documentID,
                    status: SwipeSession.Status(rawValue: d["status"] as? String ?? "") ?? .active,
                    votesA: d["votesA"] as? [String: Bool] ?? [:],
                    votesB: d["votesB"] as? [String: Bool] ?? [:],
                    matchedIdeaId: d["matchedIdeaId"] as? String,
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            onUpdate(.swipeSessions(sessions))
        })

        listeners.append(ref.collection("presence").document("hug").addSnapshotListener { snapshot, _ in
            let d = snapshot?.data(with: .estimate) ?? [:]
            onUpdate(.hug(HugPresence(
                partnerAHolding: d["partnerAHolding"] as? Bool ?? false,
                partnerBHolding: d["partnerBHolding"] as? Bool ?? false,
                partnerAHoldingAt: (d["partnerAHoldingAt"] as? Timestamp)?.dateValue(),
                partnerBHoldingAt: (d["partnerBHoldingAt"] as? Timestamp)?.dateValue(),
                lastTriggeredBy: Partner(rawValue: d["lastTriggeredBy"] as? String ?? ""),
                updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue()
            )))
        })

        listeners.append(ref.collection("carePings")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { snapshot, _ in
                let pings: [CarePing] = (snapshot?.documents ?? []).compactMap { doc in
                    let d = doc.data(with: .estimate)
                    guard let type = CarePing.Kind(rawValue: d["type"] as? String ?? ""),
                          let sender = Partner(rawValue: d["senderId"] as? String ?? "") else { return nil }
                    return CarePing(
                        id: doc.documentID, type: type, senderId: sender,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        seen: d["seen"] as? Bool ?? false
                    )
                }
                onUpdate(.carePings(pings))
            })

        listeners.append(ref.collection("guessRounds").addSnapshotListener { snapshot, _ in
            let entries: [GuessEntry] = (snapshot?.documents ?? []).compactMap { doc in
                let d = doc.data(with: .estimate)
                guard let questionId = d["questionId"] as? String else { return nil }
                return GuessEntry(
                    id: doc.documentID,
                    roundKey: d["roundKey"] as? String ?? "",
                    questionId: questionId,
                    selfAnswerA: d["selfAnswerA"] as? String,
                    guessPartnerA: d["guessPartnerA"] as? String,
                    selfAnswerB: d["selfAnswerB"] as? String,
                    guessPartnerB: d["guessPartnerB"] as? String,
                    starsEarned: d["starsEarned"] as? Int,
                    completedAt: (d["completedAt"] as? Timestamp)?.dateValue()
                )
            }
            onUpdate(.guesses(entries))
        })

        listeners.append(ref.collection("interactions").document("latest").addSnapshotListener { snapshot, _ in
            let d = snapshot?.data(with: .estimate) ?? [:]
            guard let type = Interaction.Kind(rawValue: d["type"] as? String ?? ""),
                  let from = Partner(rawValue: d["fromPartnerId"] as? String ?? "") else {
                onUpdate(.interaction(nil)); return
            }
            onUpdate(.interaction(Interaction(
                type: type, fromPartnerId: from,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )))
        })

        listeners.append(ref.collection("dailyMoment").document("current").addSnapshotListener { snapshot, _ in
            let d = snapshot?.data(with: .estimate) ?? [:]
            guard let type = DailyMoment.Kind(rawValue: d["type"] as? String ?? ""),
                  let author = Partner(rawValue: d["authorId"] as? String ?? "") else {
                onUpdate(.dailyMoment(nil)); return
            }
            onUpdate(.dailyMoment(DailyMoment(
                type: type,
                imageBase64: d["imageBase64"] as? String ?? "",
                imageUrl: d["imageUrl"] as? String ?? "",
                caption: d["caption"] as? String ?? "",
                authorId: author,
                updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            )))
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
                "statusText": mood.text,
                "status": mood.status.map { $0 as Any } ?? NSNull(),
                "moodType": (mood.moodType?.rawValue).map { $0 as Any } ?? NSNull(),
                "energyLevel": mood.energyLevel.map { $0 as Any } ?? NSNull(),
                "needTag": mood.needTag.map { $0 as Any } ?? NSNull(),
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

    // MARK: Reactions & comments

    func setReaction(_ emoji: String?, questionId: String, for partner: Partner) {
        write {
            $0.collection("quizAnswers").document(questionId).updateData([
                "reactions.partner\(partner.rawValue)": emoji.map { $0 as Any } ?? FieldValue.delete(),
            ])
        }
    }

    func addComment(_ comment: QuizComment, questionId: String) {
        write {
            $0.collection("quizAnswers").document(questionId).collection("comments").document(comment.id).setData([
                "senderId": comment.senderId.rawValue,
                "text": comment.text,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    func deleteComment(id: String, questionId: String) {
        write { $0.collection("quizAnswers").document(questionId).collection("comments").document(id).delete() }
    }

    func observeComments(questionId: String, onUpdate: @escaping ([QuizComment]) -> Void) -> Subscription {
        guard let ref = room else { return Subscription {} }
        var registration: ListenerRegistration?
        var cancelled = false
        signInIfNeeded {
            guard !cancelled else { return }
            registration = ref.collection("quizAnswers").document(questionId).collection("comments")
                .order(by: "createdAt")
                .addSnapshotListener { snapshot, _ in
                    let comments: [QuizComment] = (snapshot?.documents ?? []).compactMap { doc in
                        let d = doc.data(with: .estimate)
                        guard let sender = Partner(rawValue: d["senderId"] as? String ?? ""),
                              let text = d["text"] as? String else { return nil }
                        return QuizComment(
                            id: doc.documentID,
                            senderId: sender,
                            text: text,
                            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                    onUpdate(comments)
                }
        }
        return Subscription {
            cancelled = true
            registration?.remove()
        }
    }

    // MARK: Coupons

    func saveCoupon(_ coupon: Coupon) {
        var data: [String: Any] = [
            "title": coupon.title,
            "description": coupon.description,
            "emoji": coupon.emoji,
            "createdBy": coupon.createdBy.rawValue,
            "recipientId": coupon.recipientId.rawValue,
            "isScratched": coupon.isScratched,
            "isRedeemed": coupon.isRedeemed,
            "createdAt": Timestamp(date: coupon.createdAt),
        ]
        data["redeemedAt"] = coupon.redeemedAt.map { Timestamp(date: $0) as Any } ?? NSNull()
        write { $0.collection("coupons").document(coupon.id).setData(data) }
    }

    func deleteCoupon(id: String) {
        write { $0.collection("coupons").document(id).delete() }
    }

    // MARK: Swipe sessions

    func createSwipeSession(_ session: SwipeSession) {
        write {
            $0.collection("swipeSessions").document(session.id).setData([
                "status": session.status.rawValue,
                "votesA": [String: Bool](),
                "votesB": [String: Bool](),
                "createdAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    func voteSwipe(sessionId: String, ideaId: String, like: Bool, for partner: Partner) {
        write {
            $0.collection("swipeSessions").document(sessionId).updateData([
                FieldPath(["votes\(partner.rawValue)", ideaId]): like,
            ])
        }
    }

    // MARK: Hug & care

    func setHugHolding(_ holding: Bool, for partner: Partner, isNewHug: Bool) {
        var data: [String: Any] = [
            "partner\(partner.rawValue)Holding": holding,
            "partner\(partner.rawValue)HoldingAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if isNewHug { data["lastTriggeredBy"] = partner.rawValue }
        write { $0.collection("presence").document("hug").setData(data, merge: true) }
    }

    func sendCarePing(_ ping: CarePing) {
        write {
            $0.collection("carePings").document(ping.id).setData([
                "type": ping.type.rawValue,
                "senderId": ping.senderId.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "seen": false,
            ])
        }
    }

    func submitGuess(_ entry: GuessEntry, selfAnswer: String, guess: String, for partner: Partner) {
        write {
            $0.collection("guessRounds").document(entry.id).setData([
                "roundKey": entry.roundKey,
                "questionId": entry.questionId,
                "selfAnswer\(partner.rawValue)": selfAnswer,
                "guessPartner\(partner.rawValue)": guess,
            ], merge: true)
        }
    }

    // MARK: Home

    func setRelationshipStart(_ date: Date) {
        write { $0.setData(["meta": ["relationshipStartDate": Timestamp(date: date)]], merge: true) }
    }

    func sendInteraction(_ interaction: Interaction) {
        write {
            $0.collection("interactions").document("latest").setData([
                "type": interaction.type.rawValue,
                "fromPartnerId": interaction.fromPartnerId.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    func uploadMomentPhoto(_ jpeg: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let roomId = room?.documentID else {
            completion(.failure(StorageUnavailableError()))
            return
        }
        signInIfNeeded {
            let ref = Storage.storage().reference().child("rooms/\(roomId)/moments/\(UUID().uuidString).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            ref.putData(jpeg, metadata: metadata) { _, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                ref.downloadURL { url, error in
                    if let url {
                        completion(.success(url.absoluteString))
                    } else {
                        completion(.failure(error ?? StorageUnavailableError()))
                    }
                }
            }
        }
    }

    func setDailyMoment(_ moment: DailyMoment) {
        write {
            $0.collection("dailyMoment").document("current").setData([
                "type": moment.type.rawValue,
                "imageBase64": moment.imageBase64,
                "imageUrl": moment.imageUrl,
                "caption": moment.caption,
                "authorId": moment.authorId.rawValue,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    func completeGuess(id: String, stars: Int) {
        write {
            $0.collection("guessRounds").document(id).updateData([
                "starsEarned": stars,
                "completedAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    func markCarePingSeen(id: String) {
        write { $0.collection("carePings").document(id).updateData(["seen": true]) }
    }

    func setSwipeMatch(sessionId: String, ideaId: String) {
        write {
            $0.collection("swipeSessions").document(sessionId).updateData([
                "status": SwipeSession.Status.matched.rawValue,
                "matchedIdeaId": ideaId,
            ])
        }
    }
}

// Push-уведомления для Couple Space.
// Каждый iPhone подписан на топик room_{roomId}_{A|B}; здесь шлём уведомление второму партнёру.
const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Регион должен совпадать с регионом базы Firestore (asia-east2 = Гонконг, ближе всего к Макао).
setGlobalOptions({ region: "asia-east2" });

initializeApp();
const db = getFirestore();

const TEXT = {
  answer: {
    ru: (n) => [`${n} ответил(а) на вопрос`, "Ответь тоже, чтобы увидеть ответ"],
    zh_Hant: (n) => [`${n} 回答了一條問題`, "你也回答一下就可以看到答案"],
    en: (n) => [`${n} answered a question`, "Answer too to see it"],
  },
  event: {
    ru: (n, t) => [`Новый план от ${n}`, t],
    zh_Hant: (n, t) => [`${n} 新增了計劃`, t],
    en: (n, t) => [`${n} added a plan`, t],
  },
  couponGiven: {
    ru: (n, t) => [`${n} подарил(а) тебе купон`, "Сотри защитный слой, чтобы узнать, что внутри 🎟️"],
    zh_Hant: (n, t) => [`${n} 送了你一張願望券`, "刮開看看裡面是甚麼 🎟️"],
    en: (n, t) => [`${n} gave you a coupon`, "Scratch it to see what's inside 🎟️"],
  },
  couponRedeemed: {
    ru: (n, t) => [`${n} использует купон`, t],
    zh_Hant: (n, t) => [`${n} 使用了願望券`, t],
    en: (n, t) => [`${n} is using a coupon`, t],
  },
  comment: {
    ru: (n, t) => [`Приписка от ${n}`, t],
    zh_Hant: (n, t) => [`${n} 留了言`, t],
    en: (n, t) => [`A note from ${n}`, t],
  },
  match: {
    ru: (n, t) => ["Match! 💞", `Вы оба хотите: ${t}`],
    zh_Hant: (n, t) => ["配對成功！💞", `你們都想去：${t}`],
    en: (n, t) => ["It's a match! 💞", `You both want: ${t}`],
  },
  hug: {
    ru: (n, t) => ["Тебя обняли 🤗", `${n} обнимает тебя — открой приложение и обними в ответ`],
    zh_Hant: (n, t) => ["有人抱住了你 🤗", `${n} 抱住了你，打開 App 回抱吧`],
    en: (n, t) => ["You've been hugged 🤗", `${n} is hugging you — open the app to hug back`],
  },
  moment: {
    ru: (n, t) => [`${n} поделился(лась) моментом дня 📸`, t || "Загляни на главную"],
    zh_Hant: (n, t) => [`${n} 分享了今日時刻 📸`, t || "去主頁看看"],
    en: (n, t) => [`${n} shared a moment 📸`, t || "Take a look on the home screen"],
  },
  care: {
    ru: (n, t) => [`${n} шлёт тебе поддержку ${t}`, "Открой приложение 🤍"],
    zh_Hant: (n, t) => [`${n} 送你一點關心 ${t}`, "打開 App 看看 🤍"],
    en: (n, t) => [`${n} is sending you love ${t}`, "Open the app 🤍"],
  },
  guessTurn: {
    ru: (n, t) => [`${n} прошёл(ла) раунд «Насколько хорошо ты меня знаешь?»`, "Твоя очередь — угадай ответы ✨"],
    zh_Hant: (n, t) => [`${n} 完成了「你有多了解我？」`, "到你了，猜猜對方的答案 ✨"],
    en: (n, t) => [`${n} finished "How well do you know me?"`, "Your turn — guess their answers ✨"],
  },
  idea: {
    ru: (n, t) => [`Новая идея от ${n}`, t],
    zh_Hant: (n, t) => [`${n} 放了一個新點子`, t],
    en: (n, t) => [`${n} added an idea`, t],
  },
};

const other = (p) => (p === "A" ? "B" : "A");

async function notify(roomId, from, kind, title = "") {
  const to = other(from);
  const snap = await db.doc(`rooms/${roomId}`).get();
  const meta = (snap.exists && snap.get("meta")) || {};
  const lang = TEXT[kind][meta[`lang${to}`]] ? meta[`lang${to}`] : "en";
  const name = meta[`partner${from}Name`] || "♡";
  const [heading, body] = TEXT[kind][lang](name, title);
  await getMessaging().send({
    topic: `room_${roomId}_${to}`,
    notification: { title: heading, body },
    apns: { payload: { aps: { sound: "default" } } },
  });
}

// Новый ответ в опросе (только первый ответ на вопрос, не каждое исправление).
exports.onQuizAnswer = onDocumentWritten("rooms/{roomId}/quizAnswers/{questionId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : {};
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  for (const p of ["A", "B"]) {
    const key = `answer${p}`;
    if (after[key] && !before[key]) {
      await notify(event.params.roomId, p, "answer");
    }
  }
});

exports.onEventCreated = onDocumentCreated("rooms/{roomId}/events/{eventId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.createdBy) return;
  await notify(event.params.roomId, data.createdBy, "event", data.title || "");
});

exports.onIdeaCreated = onDocumentCreated("rooms/{roomId}/ideas/{ideaId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.createdBy) return;
  await notify(event.params.roomId, data.createdBy, "idea", data.title || "");
});

// v2: купоны — уведомить получателя о новом купоне и дарителя об использовании.
exports.onCouponCreated = onDocumentCreated("rooms/{roomId}/coupons/{couponId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.createdBy) return;
  await notify(event.params.roomId, data.createdBy, "couponGiven");
});

exports.onCouponUpdated = onDocumentWritten("rooms/{roomId}/coupons/{couponId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!before || !after || !after.recipientId) return;
  if (after.isRedeemed && !before.isRedeemed) {
    await notify(event.params.roomId, after.recipientId, "couponRedeemed", `${after.emoji || ""} ${after.title || ""}`.trim());
  }
});

// v2: приписки к ответам в опросе.
exports.onQuizComment = onDocumentCreated("rooms/{roomId}/quizAnswers/{questionId}/comments/{commentId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.senderId) return;
  await notify(event.params.roomId, data.senderId, "comment", data.text || "");
});

// v2: «Тиндер» для идей — сообщить обоим о совпадении.
exports.onSwipeMatch = onDocumentWritten("rooms/{roomId}/swipeSessions/{sessionId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : {};
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after || after.status !== "matched" || before.status === "matched" || !after.matchedIdeaId) return;
  const roomId = event.params.roomId;
  const idea = await db.doc(`rooms/${roomId}/ideas/${after.matchedIdeaId}`).get();
  const title = (idea.exists && idea.get("title")) || "";
  // notify(from) шлёт второму партнёру, поэтому вызываем от имени каждого.
  await Promise.all([notify(roomId, "A", "match", title), notify(roomId, "B", "match", title)]);
});

// Главная: объятие (удержание кнопки «Обнять» ~1.5 сек) — пуш «Тебя обняли».
exports.onInteraction = onDocumentWritten("rooms/{roomId}/interactions/latest", async (event) => {
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after || after.type !== "hug" || !after.fromPartnerId) return;
  await notify(event.params.roomId, after.fromPartnerId, "hug");
});

// Главная: новый «момент дня» (фото или рисунок).
exports.onDailyMoment = onDocumentWritten("rooms/{roomId}/dailyMoment/current", async (event) => {
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after || !after.authorId) return;
  await notify(event.params.roomId, after.authorId, "moment", after.caption || "");
});

// v2: «Отправить поддержку».
const CARE_EMOJI = { sakura: "🌸", hearts: "💗", hug_sparkle: "🤗" };
exports.onCarePing = onDocumentCreated("rooms/{roomId}/carePings/{pingId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data || !data.senderId) return;
  await notify(event.params.roomId, data.senderId, "care", CARE_EMOJI[data.type] || "🤍");
});

// v2: угадайка — когда партнёр ответил на все 5 вопросов раунда, сообщить второму.
const GUESS_ROUND_SIZE = 5;
exports.onGuessAnswer = onDocumentWritten("rooms/{roomId}/guessRounds/{entryId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : {};
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after || !after.roundKey) return;
  for (const p of ["A", "B"]) {
    const key = `guessPartner${p}`;
    if (!after[key] || before[key]) continue;
    const round = await db.collection(`rooms/${event.params.roomId}/guessRounds`)
      .where("roundKey", "==", after.roundKey).get();
    const done = round.docs.filter((d) => d.get(`selfAnswer${p}`) && d.get(key)).length;
    const otherDone = round.docs.filter((d) => d.get(`guessPartner${p === "A" ? "B" : "A"}`)).length;
    if (done === GUESS_ROUND_SIZE && otherDone < GUESS_ROUND_SIZE) {
      await notify(event.params.roomId, p, "guessTurn");
    }
  }
});

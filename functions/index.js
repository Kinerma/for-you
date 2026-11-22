// Push-уведомления для Couple Space.
// Каждый iPhone подписан на топик room_{roomId}_{A|B}; здесь шлём уведомление второму партнёру.
const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
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

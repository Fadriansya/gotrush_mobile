const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// HTTP function to backfill order_history.completed_at from archived_at
// Usage: deploy, then call via curl or from browser (only callable by authorized users if you secure it)
exports.backfillCompletedAt = functions.https.onRequest(async (req, res) => {
  try {
    let totalUpdated = 0;
    const batchSize = 500;

    // We will query for documents where completed_at == null (missing) and process in batches.
    // Note: querying for null is supported for Firestore equality.
    while (true) {
      const q = db.collection("order_history").where("completed_at", "==", null).limit(batchSize);

      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      snap.docs.forEach((doc) => {
        const data = doc.data();
        const archived = data["archived_at"];
        const toSet = {};
        if (archived) {
          toSet["completed_at"] = archived;
        } else {
          toSet["completed_at"] = admin.firestore.FieldValue.serverTimestamp();
        }
        batch.update(doc.ref, toSet);
      });

      await batch.commit();
      totalUpdated += snap.size;

      // If we got fewer than batchSize, we're likely done
      if (snap.size < batchSize) break;
    }

    res.status(200).json({ ok: true, updated: totalUpdated });
  } catch (e) {
    console.error("backfill error", e);
    res.status(500).json({ ok: false, error: String(e) });
  }
});

// Cloud Function to send FCM notifications on order status changes
exports.sendOrderStatusNotification = functions.firestore.document("orders/{orderId}").onUpdate(async (change, context) => {
  const newData = change.after.data();
  const previousData = change.before.data();

  const newStatus = newData.status;
  const previousStatus = previousData.status;

  // Only send notification if status has changed
  if (newStatus === previousStatus) return;

  let targetUserId;
  let messageTitle;
  let messageBody;

  if (["accepted", "on_the_way", "arrived", "pickup_confirmed_by_driver"].includes(newStatus)) {
    // Send to user
    targetUserId = newData.user_id;
    switch (newStatus) {
      case "accepted":
        messageTitle = "Driver Ditemukan";
        messageBody = "Driver telah menerima pesanan Anda.";
        break;
      case "on_the_way":
        messageTitle = "Driver Menuju Lokasi";
        messageBody = "Driver sedang menuju lokasi Anda.";
        break;
      case "arrived":
        messageTitle = "Driver Telah Sampai";
        messageBody = "Driver telah sampai di lokasi. Silakan siapkan sampah.";
        break;
      case "pickup_confirmed_by_driver":
        messageTitle = "Konfirmasi Pengambilan";
        messageBody = "Driver telah mengkonfirmasi pengambilan sampah. Harap konfirmasi.";
        break;
    }
  } else if (newStatus === "payment_success") {
    // Send to driver when payment successfully completed
    targetUserId = newData.driver_id;
    messageTitle = "Pembayaran Berhasil";
    messageBody = "Pengguna telah membayar. Silakan konfirmasi pengambilan.";
  } else if (newStatus === "completed") {
    // Send to driver
    targetUserId = newData.driver_id;
    messageTitle = "Pesanan Selesai";
    messageBody = "Pengguna telah mengkonfirmasi pengambilan sampah. Pesanan selesai.";
  } else {
    return; // No notification for other statuses
  }

  if (!targetUserId) return;

  try {
    // Get the FCM token from the users collection
    const userDoc = await db.collection("users").doc(targetUserId).get();
    const fcmToken = userDoc.data()?.fcm_token;

    if (!fcmToken) {
      console.log(`No FCM token for user ${targetUserId}`);
      return;
    }

    // Send the notification
    const message = {
      token: fcmToken,
      notification: {
        title: messageTitle,
        body: messageBody,
      },
      data: {
        orderId: context.params.orderId,
        status: newStatus,
      },
    };

    await admin.messaging().send(message);
    console.log(`Notification sent to ${targetUserId} for status ${newStatus}`);
  } catch (error) {
    console.error("Error sending notification:", error);
  }
});

// Push notification to online drivers when a new order for today is created
exports.notifyDriversOnNewOrder = functions.firestore.document("orders/{orderId}").onCreate(async (snap, context) => {
  try {
    const data = snap.data();
    const status = data.status;
    const pickupDate = data.pickup_date ? data.pickup_date.toDate() : null;
    if (!pickupDate) return;

    // Check if pickup date is today
    const now = new Date();
    const isSameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    if (!isSameDay(pickupDate, now)) return;

    // Only notify for waiting/pending orders
    if (!(status === "waiting" || status === "pending")) return;

    // Query online drivers with fcm_token
    const driversSnap = await db.collection("users").where("role", "==", "driver").where("status", "==", "online").get();

    const tokens = driversSnap.docs.map((d) => d.data().fcm_token).filter((t) => !!t);

    if (!tokens.length) {
      console.log("No online drivers with tokens");
      return;
    }

    const message = {
      notification: {
        title: "Pesanan Baru Hari Ini",
        body: "Ada pesanan baru untuk dijemput hari ini.",
      },
      data: {
        orderId: context.params.orderId,
        status: status,
      },
      tokens,
    };

    const response = await admin.messaging().sendMulticast(message);
    console.log(`notifyDriversOnNewOrder sent to ${tokens.length}, success: ${response.successCount}`);
  } catch (e) {
    console.error("notifyDriversOnNewOrder error", e);
  }
});

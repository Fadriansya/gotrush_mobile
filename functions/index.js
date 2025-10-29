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

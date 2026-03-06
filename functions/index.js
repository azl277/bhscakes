/* eslint-disable */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendOrderStatusNotification = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    
    const before = change.before.data();
    const after = change.after.data();

    // 1. Only run if the status actually changed
    if (before.status === after.status) {
      console.log("Status did not change. Exiting.");
      return null;
    }

    const newStatus = after.status;
    const userId = after.userId;

    if (!userId || userId === "GUEST") {
      console.log("No userId or Guest user. Cannot send push notification.");
      return null;
    }

    // 2. Look up the user's FCM token in the database
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found.`);
      return null;
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log(`User ${userId} does not have an FCM token saved.`);
      return null;
    }

    // 3. Set the notification message
    let title = "Order Update";
    let body = `Your order is now ${newStatus}`;

    if (newStatus.toLowerCase() === "baking" || newStatus.toLowerCase() === "preparing") {
      title = "🧑‍🍳 Baking Started!";
      body = "Your order is currently being prepared with love.";
    } else if (newStatus.toLowerCase() === "out for delivery") {
      title = "🛵 Out for Delivery!";
      body = "Hang tight! Your delivery partner is on the way.";
    } else if (newStatus.toLowerCase() === "delivered") {
      title = "🥳 Order Delivered!";
      body = "Enjoy your delicious treats! 🎉";
    } else if (newStatus.toLowerCase() === "cancelled") {
      title = "❌ Order Cancelled";
      body = "Your order has been cancelled.";
    }

    // 4. Construct the notification payload
    const payload = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "bhs_orders_high_priority_v5", // 🟢 Matches your Android channel exactly!
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    // 5. Send it!
    try {
      const response = await admin.messaging().send(payload);
      console.log("✅ Successfully sent message:", response);
    } catch (error) {
      console.error("❌ Error sending message:", error);
    }

    return null;
  });
// supabase/functions/notify-chat-message/index.ts
// Deploy: supabase functions deploy notify-chat-message

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function sendFCM(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      to: fcmToken,
      notification: {
        title,
        body,
        sound: "notification_sound",
        android_channel_id: "moka_chat",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
      android: {
        priority: "high",
        notification: {
          channel_id: "moka_chat",
          sound: "notification_sound",
          notification_priority: "PRIORITY_HIGH",
          visibility: "PUBLIC",
          default_vibrate_timings: false,
          vibrate_timings: ["0s", "0.2s", "0.1s", "0.2s"],
        },
      },
      apns: {
        payload: { aps: { sound: "notification_sound.mp3", badge: 1 } },
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
      },
      priority: "high",
      content_available: true,
    }),
  });
  return res.json();
}

serve(async (req) => {
  try {
    // Triggered by Database Webhook on messages INSERT
    const payload = await req.json();
    const message = payload.record;

    if (!message) {
      return new Response(JSON.stringify({ error: "No message record" }), {
        status: 400,
      });
    }

    const { conversation_id, sender_id, content } = message;

    // Get conversation + participants
    const { data: conv } = await supabase
      .from("conversations")
      .select("customer_id, worker_id, jobs(title)")
      .eq("id", conversation_id)
      .single();

    if (!conv) {
      return new Response(JSON.stringify({ error: "Conversation not found" }), {
        status: 404,
      });
    }

    // Determine recipient (the other person)
    const recipientId =
      conv.customer_id === sender_id ? conv.worker_id : conv.customer_id;

    // Get sender name
    const { data: sender } = await supabase
      .from("profiles")
      .select("name")
      .eq("id", sender_id)
      .single();

    // Get recipient FCM token
    const { data: recipient } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", recipientId)
      .single();

    if (!recipient?.fcm_token) {
      return new Response(
        JSON.stringify({ message: "Recipient has no FCM token" }),
        { status: 200 }
      );
    }

    const jobTitle = (conv.jobs as any)?.title ?? "Job Chat";
    const senderName = sender?.name ?? "Someone";
    const notifBody =
      content.length > 80 ? content.substring(0, 80) + "..." : content;

    await sendFCM(
      recipient.fcm_token,
      `💬 ${senderName}`,
      notifBody,
      {
        type: "chat",
        conversation_id,
        job_title: jobTitle,
        sender_id,
      }
    );

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});

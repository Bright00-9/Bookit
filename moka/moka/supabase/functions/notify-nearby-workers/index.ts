// supabase/functions/notify-nearby-workers/index.ts
// Deploy with: supabase functions deploy notify-nearby-workers

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!; // From Firebase Console

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Haversine formula to calculate distance in km
function getDistanceKm(
  lat1: number, lng1: number,
  lat2: number, lng2: number
): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number) {
  return (deg * Math.PI) / 180;
}

// Send FCM push notification to a single device
async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  urgency: string
) {
  const isEmergency = urgency === 'emergency';
  const isUrgent = urgency === 'urgent';

  const response = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      to: fcmToken,
      // ✅ Notification payload — shown by system when app is in background/killed
      notification: {
        title,
        body,
        sound: "notification_sound",   // matches res/raw/notification_sound.mp3
        android_channel_id: isEmergency ? "moka_emergency" : "moka_jobs",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      // ✅ Data payload — received in foreground for local notification
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      // ✅ Android specific config
      android: {
        priority: isEmergency ? "high" : "high",
        notification: {
          channel_id: isEmergency ? "moka_emergency" : "moka_jobs",
          sound: "notification_sound",
          default_vibrate_timings: false,
          vibrate_timings: isEmergency
            ? ["0s", "0.5s", "0.2s", "0.5s"]
            : ["0s", "0.25s", "0.25s", "0.25s"],
          notification_priority: isEmergency
            ? "PRIORITY_MAX"
            : "PRIORITY_HIGH",
          visibility: "PUBLIC",  // show on lock screen
          // ✅ Heads-up notification
          notification_count: 1,
        },
      },
      // ✅ APNs (iOS) config
      apns: {
        payload: {
          aps: {
            sound: "notification_sound.mp3",
            badge: 1,
            "interruption-level": isEmergency ? "critical" : "active",
          },
        },
        headers: {
          "apns-priority": "10",  // 10 = immediate
          "apns-push-type": "alert",
        },
      },
      priority: "high",
      content_available: true,  // wake up app even when killed (iOS)
      mutable_content: true,
    }),
  });
  return response.json();
}

serve(async (req) => {
  try {
    // This function is triggered by a Supabase Database Webhook
    // when a new row is inserted into the jobs table
    const payload = await req.json();
    const job = payload.record;

    if (!job) {
      return new Response(JSON.stringify({ error: "No job record found" }), {
        status: 400,
      });
    }

    const { id, title, skill_needed, urgency, lat, lng } = job;

    if (!lat || !lng) {
      return new Response(JSON.stringify({ error: "Job has no location" }), {
        status: 400,
      });
    }

    // Fetch all online workers with matching skill who have an FCM token
    const { data: workers, error } = await supabase
      .from("profiles")
      .select("id, name, fcm_token, lat, lng, skill")
      .eq("role", "worker")
      .eq("is_online", true)
      .eq("skill", skill_needed)
      .not("fcm_token", "is", null);

    if (error) {
      console.error("Error fetching workers:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
      });
    }

    if (!workers || workers.length === 0) {
      return new Response(
        JSON.stringify({ message: "No online workers found nearby" }),
        { status: 200 }
      );
    }

    // Filter workers within 10km radius
    const RADIUS_KM = 10;
    const nearbyWorkers = workers.filter((worker) => {
      if (!worker.lat || !worker.lng) return false;
      const distance = getDistanceKm(lat, lng, worker.lat, worker.lng);
      return distance <= RADIUS_KM;
    });

    if (nearbyWorkers.length === 0) {
      return new Response(
        JSON.stringify({ message: "No workers within radius" }),
        { status: 200 }
      );
    }

    // Build notification content based on urgency
    const urgencyPrefix =
      urgency === "emergency"
        ? "EMERGENCY"
        : urgency === "urgent"
        ? "Urgent"
        : "New";

    const notificationTitle = `${urgencyPrefix} Job Near You`;
    const notificationBody = `${title} — Tap to accept`;

    // Send notifications to all nearby workers in parallel
    const results = await Promise.allSettled(
      nearbyWorkers.map((worker) =>
        sendPushNotification(
          worker.fcm_token,
          notificationTitle,
          notificationBody,
          {
            job_id: id,
            skill: skill_needed,
            urgency: urgency,
            type: "new_job",
          },
          urgency
        )
      )
    );

    const sent = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;

    console.log(`Notified ${sent} workers, ${failed} failed`);

    return new Response(
      JSON.stringify({
        success: true,
        workers_notified: sent,
        workers_failed: failed,
        total_nearby: nearbyWorkers.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});

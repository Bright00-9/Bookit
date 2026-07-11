// supabase/functions/expire-old-jobs/index.ts
// Deploy: supabase functions deploy expire-old-jobs
// Then schedule via Supabase Dashboard → Edge Functions → Schedule
// Or call manually: supabase functions invoke expire-old-jobs

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async () => {
  try {
    // Expire all open jobs older than 72 hours
    const { data, error } = await supabase
      .from("jobs")
      .update({ status: "expired" })
      .eq("status", "open")
      .lt("expires_at", new Date().toISOString())
      .select("id, title");

    if (error) throw error;

    const count = data?.length ?? 0;
    console.log(`Expired ${count} jobs`);

    return new Response(
      JSON.stringify({ success: true, expired: count }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});

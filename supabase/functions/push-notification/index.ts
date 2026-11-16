// Supabase Edge Function: push-notification
// Triggered by Database Webhook on public.notifications INSERT
// Dispatches push notifications to Android & iOS devices using Firebase Cloud Messaging (FCM v1 API).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface NotificationRecord {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string | null;
  ref_type: string | null;
  ref_id: string | null;
}

interface WebhookPayload {
  type: "INSERT";
  table: "notifications";
  schema: "public";
  record: NotificationRecord;
}

// Function to generate Google OAuth2 Access Token from Service Account Key
async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp,
    iat,
  };

  const encodeBase64Url = (str: string) =>
    btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const encodedHeader = encodeBase64Url(JSON.stringify(header));
  const encodedClaim = encodeBase64Url(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaim}`;

  // Import private key for signing
  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binaryKey = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const encodedSignature = encodeBase64Url(
    String.fromCharCode(...new Uint8Array(signature))
  );

  const jwt = `${unsignedToken}.${encodedSignature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const record = payload.record;

    if (!record || !record.user_id) {
      return new Response("No valid record found", { status: 400 });
    }

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      console.error("Missing FIREBASE_SERVICE_ACCOUNT environment secret in Supabase");
      return new Response("Missing FIREBASE_SERVICE_ACCOUNT secret", { status: 500 });
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    // Connect to Supabase to retrieve target user's device tokens
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("user_id", record.user_id);

    if (tokensError || !tokens || tokens.length === 0) {
      console.log(`No registered FCM device tokens for user: ${record.user_id}`);
      return new Response("No tokens found", { status: 200 });
    }

    // Acquire Google FCM OAuth2 token
    const accessToken = await getAccessToken(serviceAccount);

    // Send push notification to all active devices of the recipient
    const sendPromises = tokens.map(async ({ token }) => {
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
      const fcmPayload = {
        message: {
          token,
          notification: {
            title: record.title,
            body: record.body || "",
          },
          data: {
            ref_type: record.ref_type || "",
            ref_id: record.ref_id || "",
            type: record.type || "",
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "high_importance_channel",
              sound: "default",
            },
          },
        },
      };

      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmPayload),
      });

      if (!res.ok) {
        const errorText = await res.text();
        console.error(`FCM error for token ${token}:`, errorText);
        // Clean up unregistered/invalid tokens automatically
        if (errorText.includes("UNREGISTERED")) {
          await supabase.from("fcm_tokens").delete().eq("token", token);
        }
      }
    });

    await Promise.all(sendPromises);
    return new Response(JSON.stringify({ success: true, dispatched: tokens.length }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("Failed to process push webhook:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});

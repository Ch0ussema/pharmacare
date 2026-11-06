import "server-only";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * Server-only Supabase admin client.
 *
 * Uses the project's secret key (`sb_secret_…`, equivalent to `service_role`).
 * The key bypasses RLS and must never reach the browser: this module imports
 * `server-only`, and the env variable is intentionally not prefixed with
 * `NEXT_PUBLIC_`.
 *
 * The client is created lazily so a missing environment variable never breaks
 * the build and so Phase 0 remains database-free.
 */

let adminClient: SupabaseClient | null = null;

export type SupabaseAdmin = SupabaseClient;

export function getSupabaseAdmin(): SupabaseAdmin {
  if (adminClient) {
    return adminClient;
  }

  const url = process.env.SUPABASE_URL;
  const secretKey = process.env.SUPABASE_SECRET_KEY;

  if (!url || !secretKey) {
    throw new Error(
      "Configuration Supabase manquante : définissez SUPABASE_URL et " +
        "SUPABASE_SECRET_KEY (voir .env.example). / Missing Supabase " +
        "configuration: set SUPABASE_URL and SUPABASE_SECRET_KEY " +
        "(see .env.example).",
    );
  }

  adminClient = createClient(url, secretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  return adminClient;
}

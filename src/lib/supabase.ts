import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = String(import.meta.env.VITE_SUPABASE_URL || "").trim();
const SUPABASE_KEY = String(import.meta.env.VITE_SUPABASE_ANON_KEY || "").trim();

if (!SUPABASE_URL) {
  throw new Error("Supabase is not configured: VITE_SUPABASE_URL is missing. Add it to your .env file and restart Vite.");
}

if (!/^https?:\/\//i.test(SUPABASE_URL)) {
  throw new Error(`Invalid VITE_SUPABASE_URL: "${SUPABASE_URL}". It must start with http:// or https://.`);
}

if (!SUPABASE_KEY) {
  throw new Error("Supabase is not configured: add VITE_SUPABASE_ANON_KEY to your .env file and restart Vite.");
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
import { createClient } from '@supabase/supabase-js';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Environment variable ${name} belum di-set`);
  return value;
}

const clientOptions = { auth: { persistSession: false, autoRefreshToken: false } };

/** Client yang bertindak sebagai user pemilik token — RLS Supabase tetap berlaku. */
export function clientForToken(accessToken) {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_ANON_KEY'), {
    ...clientOptions,
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}

/** Client admin (service role) — hanya untuk script lokal seperti seed & import, jangan dipakai di route API. */
export function adminClient() {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), clientOptions);
}

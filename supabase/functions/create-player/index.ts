import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function emailFromNombre(nombre: string) {
  const slug = nombre.trim().toLowerCase().replace(/[^a-z0-9]/g, "");
  return { slug, email: `darbala+${slug}@gmail.com` };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  let payload: { nombre?: unknown; password?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "No se pudo crear la cuenta" });
  }

  const nombre = typeof payload.nombre === "string" ? payload.nombre.trim() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  if (nombre.length < 2 || nombre.length > 24) {
    return json(400, {
      error: "El nombre debe tener entre 2 y 24 caracteres",
    });
  }
  const { slug, email } = emailFromNombre(nombre);
  if (!slug) {
    return json(400, { error: "El nombre necesita letras o números" });
  }
  if (password.length < 6) {
    return json(400, {
      error: "La contraseña debe tener al menos 6 caracteres",
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const display = nombre.toUpperCase();
  const { error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: display },
  });

  if (error) {
    const message = error.message.toLowerCase();
    if (
      message.includes("already") ||
      message.includes("registered") ||
      message.includes("exists") ||
      message.includes("duplicate")
    ) {
      return json(409, {
        error: "Ese nombre ya está registrado. Usa Entrar.",
      });
    }
    return json(400, { error: "No se pudo crear la cuenta" });
  }

  return json(200, { ok: true });
});

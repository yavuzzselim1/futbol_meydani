import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { hashCode, isValidEmail } from "../_shared/otp.ts";

const MAX_ATTEMPTS = 5;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, code } = await req.json();
    if (typeof email !== "string" || !isValidEmail(email)) {
      return jsonResponse({ error: "Geçerli bir e-posta adresi girin." }, 400);
    }
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return jsonResponse({ error: "6 haneli kodu eksiksiz gir." }, 400);
    }
    const normalizedEmail = email.trim().toLowerCase();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: otpRow, error: fetchError } = await supabase
      .from("otp_requests")
      .select("id, code_hash, attempts, expires_at")
      .eq("email", normalizedEmail)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (fetchError) throw fetchError;

    if (!otpRow) {
      return jsonResponse(
        { error: "Kod bulunamadı. Yeni bir kod iste." },
        400,
      );
    }

    if (new Date(otpRow.expires_at).getTime() < Date.now()) {
      return jsonResponse(
        { error: "Kodun süresi doldu. Yeni bir kod iste." },
        400,
      );
    }

    if (otpRow.attempts >= MAX_ATTEMPTS) {
      return jsonResponse(
        { error: "Çok fazla yanlış deneme yaptın. Yeni bir kod iste." },
        400,
      );
    }

    const submittedHash = await hashCode(code);
    if (submittedHash !== otpRow.code_hash) {
      await supabase
        .from("otp_requests")
        .update({ attempts: otpRow.attempts + 1 })
        .eq("id", otpRow.id);

      const remaining = MAX_ATTEMPTS - (otpRow.attempts + 1);
      return jsonResponse(
        {
          error:
            remaining > 0
              ? `Kod hatalı. ${remaining} deneme hakkın kaldı.`
              : "Kod hatalı. Yeni bir kod iste.",
        },
        400,
      );
    }

    await supabase
      .from("otp_requests")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", otpRow.id);

    const { data: linkData, error: linkError } =
      await supabase.auth.admin.generateLink({
        type: "magiclink",
        email: normalizedEmail,
      });
    if (linkError) throw linkError;

    const hashedToken = linkData?.properties?.hashed_token;
    if (!hashedToken) {
      throw new Error("hashed_token alınamadı");
    }

    return jsonResponse({ ok: true, hashed_token: hashedToken });
  } catch (error) {
    console.error("verify-otp error", error);
    return jsonResponse(
      { error: "Doğrulama sırasında bir hata oluştu. Tekrar dene." },
      500,
    );
  }
});

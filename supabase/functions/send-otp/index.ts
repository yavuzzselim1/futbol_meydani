import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { generateSixDigitCode, hashCode, isValidEmail } from "../_shared/otp.ts";

const RESEND_COOLDOWN_SECONDS = 30;
const CODE_TTL_MINUTES = 10;

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
    const { email } = await req.json();
    if (typeof email !== "string" || !isValidEmail(email)) {
      return jsonResponse({ error: "Geçerli bir e-posta adresi girin." }, 400);
    }
    const normalizedEmail = email.trim().toLowerCase();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Kısa bekleme kontrolü: aynı e-posta için art arda kod isteğini sınırla.
    const { data: recent } = await supabase
      .from("otp_requests")
      .select("created_at")
      .eq("email", normalizedEmail)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (recent) {
      const secondsSince =
        (Date.now() - new Date(recent.created_at).getTime()) / 1000;
      if (secondsSince < RESEND_COOLDOWN_SECONDS) {
        return jsonResponse(
          {
            error: `Çok sık istek gönderdin. ${Math.ceil(
              RESEND_COOLDOWN_SECONDS - secondsSince,
            )} saniye sonra tekrar dene.`,
          },
          429,
        );
      }
    }

    const code = generateSixDigitCode();
    const codeHash = await hashCode(code);
    const expiresAt = new Date(
      Date.now() + CODE_TTL_MINUTES * 60_000,
    ).toISOString();

    const { error: insertError } = await supabase.from("otp_requests").insert({
      email: normalizedEmail,
      code_hash: codeHash,
      expires_at: expiresAt,
    });
    if (insertError) throw insertError;

    const smtpPort = Number(Deno.env.get("SMTP_PORT") ?? "465");
    const smtpEncryption = (Deno.env.get("SMTP_ENCRYPTION") ?? "ssl").toLowerCase();

    const client = new SMTPClient({
      connection: {
        hostname: Deno.env.get("SMTP_HOST")!,
        port: smtpPort,
        tls: smtpEncryption === "ssl",
        auth: {
          username: Deno.env.get("SMTP_USER")!,
          password: Deno.env.get("SMTP_PASS")!,
        },
      },
    });

    try {
      await client.send({
        from: Deno.env.get("SMTP_FROM")!,
        to: normalizedEmail,
        subject: "Futbol Meydanı Doğrulama Kodun",
        content: `Doğrulama kodun: ${code}\nBu kod ${CODE_TTL_MINUTES} dakika içinde geçerliliğini yitirir.`,
        html: `<div style="font-family:sans-serif;font-size:16px;color:#111">
          <p>Futbol Meydanı'na hoş geldin!</p>
          <p>Doğrulama kodun:</p>
          <p style="font-size:28px;font-weight:800;letter-spacing:4px">${code}</p>
          <p style="color:#666;font-size:13px">Bu kod ${CODE_TTL_MINUTES} dakika içinde geçerliliğini yitirir. Bu isteği sen yapmadıysan e-postayı yok sayabilirsin.</p>
        </div>`,
      });
    } finally {
      await client.close();
    }

    // En eski/tüketilmiş kayıtları arka planda temizle (hataları yut).
    supabase.rpc("cleanup_expired_otp_requests").then(
      () => {},
      () => {},
    );

    return jsonResponse({ ok: true });
  } catch (error) {
    console.error("send-otp error", error);
    return jsonResponse(
      { error: "Kod gönderilirken bir hata oluştu. Tekrar dene." },
      500,
    );
  }
});

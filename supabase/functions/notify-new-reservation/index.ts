// supabase/functions/notify-new-reservation/index.ts
//
// Triggered by a Supabase Database Webhook on:
//   Table  : reservations
//   Event  : INSERT
//
// Setup steps (run once):
//   1. supabase functions deploy notify-new-reservation
//   2. In Supabase Dashboard → Database → Webhooks → Create:
//      - Name    : on_new_reservation
//      - Table   : reservations
//      - Events  : INSERT
//      - URL     : https://<project-ref>.supabase.co/functions/v1/notify-new-reservation
//     - Headers : Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
//   3. In Supabase Dashboard → Settings → Edge Functions → Secrets:
//      - RESEND_API_KEY   : re_xxxxxxxxxxxx   (from resend.com)
//      - ADMIN_EMAIL      : admin@meridianmotors.com
//      - ADMIN_EMAIL_FROM : Meridian Motors <noreply@meridianmotors.com>
//
// Install Resend:  npm install resend  (not needed — uses fetch directly)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const RESEND_API_KEY   = Deno.env.get("RESEND_API_KEY")!;
const ADMIN_EMAIL      = Deno.env.get("ADMIN_EMAIL")!;
const ADMIN_EMAIL_FROM = Deno.env.get("ADMIN_EMAIL_FROM") ??
  "Meridian Motors <noreply@meridianmotors.com>";

serve(async (req: Request) => {
  try {
    // ── Parse webhook payload
    const payload = await req.json();
    const record  = payload.record as Record<string, unknown>;

    if (!record) {
      return new Response(
        JSON.stringify({ error: "No record in payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // ── Extract reservation details
    const customerName  = record.customer_name  as string ?? "A customer";
    const customerEmail = record.customer_email as string ?? "";
    const customerPhone = record.customer_phone as string ?? "—";
    const reservationId = record.id             as string ?? "—";
    const resDate       = record.reservation_date as string ?? "—";
    const notes         = record.notes          as string ?? "None";
    const createdAt     = record.created_at     as string ?? new Date().toISOString();

    // ── Format date nicely
    const formatDate = (iso: string) => {
      try {
        return new Date(iso).toLocaleDateString("en-US", {
          weekday: "long",
          year:    "numeric",
          month:   "long",
          day:     "numeric",
        });
      } catch {
        return iso;
      }
    };

    const formatDateTime = (iso: string) => {
      try {
        return new Date(iso).toLocaleString("en-US", {
          year:   "numeric",
          month:  "short",
          day:    "numeric",
          hour:   "2-digit",
          minute: "2-digit",
        });
      } catch {
        return iso;
      }
    };

    // ── Build branded HTML email
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>New Reservation — Meridian Motors</title>
</head>
<body style="margin:0;padding:0;background:#0A0A0F;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0A0A0F;padding:32px 16px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">

          <!-- Header -->
          <tr>
            <td style="background:#0F2C59;border-radius:16px 16px 0 0;padding:28px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td>
                    <div style="display:inline-block;background:rgba(255,255,255,0.1);border-radius:10px;padding:10px;margin-bottom:16px;">
                      <span style="font-size:22px;">🛡️</span>
                    </div>
                    <p style="margin:0;color:rgba(255,255,255,0.6);font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">
                      Meridian Motors Admin
                    </p>
                    <h1 style="margin:6px 0 0;color:#FFFFFF;font-size:26px;font-weight:900;letter-spacing:-0.5px;">
                      New Reservation Received
                    </h1>
                  </td>
                  <td align="right" valign="top">
                    <span style="background:#1E56D6;color:white;font-size:11px;font-weight:700;padding:6px 12px;border-radius:20px;letter-spacing:0.5px;">
                      ACTION REQUIRED
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Alert banner -->
          <tr>
            <td style="background:#1E56D6;padding:14px 32px;">
              <p style="margin:0;color:#FFFFFF;font-size:14px;">
                📅 &nbsp;<strong>${customerName}</strong> just reserved a vehicle on
                <strong>${formatDate(resDate)}</strong>.
                Log in to review and approve.
              </p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background:#12121A;padding:32px;">

              <!-- Customer section -->
              <p style="margin:0 0 12px;color:#8A8A9A;font-size:10px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;">
                Customer Information
              </p>
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:#1C1C27;border-radius:12px;border:1px solid #1F1F2E;margin-bottom:20px;">
                <tr>
                  <td style="padding:16px 20px;">
                    ${_emailRow("Full Name",    customerName)}
                    ${_emailRow("Email",        customerEmail || "—")}
                    ${_emailRow("Phone",        customerPhone)}
                  </td>
                </tr>
              </table>

              <!-- Reservation section -->
              <p style="margin:0 0 12px;color:#8A8A9A;font-size:10px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;">
                Reservation Details
              </p>
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:#1C1C27;border-radius:12px;border:1px solid #1F1F2E;margin-bottom:20px;">
                <tr>
                  <td style="padding:16px 20px;">
                    ${_emailRow("Reservation ID",   reservationId)}
                    ${_emailRow("Reservation Date", formatDate(resDate))}
                    ${_emailRow("Status",           "Pending Review")}
                    ${_emailRow("Submitted At",     formatDateTime(createdAt))}
                    ${notes !== "None" ? _emailRow("Notes", notes) : ""}
                  </td>
                </tr>
              </table>

              <!-- CTA button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0 24px;">
                    <a href="https://admin.meridianmotors.com/reservations"
                       style="display:inline-block;background:#1E56D6;color:#FFFFFF;text-decoration:none;
                              font-size:15px;font-weight:700;padding:14px 32px;
                              border-radius:12px;letter-spacing:0.3px;">
                      Review Reservation →
                    </a>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#0D0D16;border-radius:0 0 16px 16px;padding:20px 32px;
                       border-top:1px solid #1F1F2E;">
              <p style="margin:0;color:#3D3D50;font-size:12px;text-align:center;">
                This is an automated notification from Meridian Motors Admin System.<br/>
                Do not reply to this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `.trim();

    // ── Send via Resend
    const res = await fetch("https://api.resend.com/emails", {
      method:  "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type":  "application/json",
      },
      body: JSON.stringify({
        from:    ADMIN_EMAIL_FROM,
        to:      [ADMIN_EMAIL],
        subject: `🚗 New Reservation — ${customerName} · ${formatDate(resDate)}`,
        html,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error("Resend error:", err);
      return new Response(
        JSON.stringify({ error: "Email send failed", details: err }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const data = await res.json();
    console.log("Email sent:", data.id);

    return new Response(
      JSON.stringify({ success: true, emailId: data.id }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );

  } catch (err) {
    console.error("Function error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

// ── Helper: email info row HTML
function _emailRow(label: string, value: string): string {
  return `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:10px;">
      <tr>
        <td width="140" style="color:#8A8A9A;font-size:12px;vertical-align:top;padding-right:12px;">
          ${label}
        </td>
        <td style="color:#FFFFFF;font-size:13px;font-weight:500;">
          ${value}
        </td>
      </tr>
    </table>
  `;
}
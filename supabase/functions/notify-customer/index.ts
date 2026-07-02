// supabase/functions/notify-customer/index.ts
//
// Triggered by TWO Supabase Database Webhooks:
//   1. Table: reservations · Event: UPDATE
//   2. Table: inquiries    · Event: UPDATE
//
// What it does:
//   - When admin updates a reservation status → emails the customer
//   - When admin responds to an inquiry      → emails the customer
//
// Secrets needed (Supabase Dashboard → Settings → Edge Functions → Secrets):
//   RESEND_API_KEY        : re_xxxxxxxxxxxx
//   EMAIL_FROM            : Meridian Motors <noreply@meridianmotors.com>
//   SUPABASE_URL          : https://xxxx.supabase.co
//   SUPABASE_SERVICE_KEY  : your service role key (to query DB for extra data)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Secrets
const RESEND_API_KEY       = Deno.env.get("RESEND_API_KEY")!;
const EMAIL_FROM           = Deno.env.get("EMAIL_FROM") ??
  "Meridian Motors <noreply@meridianmotors.com>";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ── Logo hosted publicly — replace with your real logo URL
const LOGO_URL = "https://euucepsoguteynqcxbkb.supabase.co/storage/v1/object/public/company-assets/meridian_logo.png";



// ── Brand colours
const BRAND_NAVY   = "#0F2C59";
const BRAND_BLUE   = "#1E56D6";
const BG_DARK      = "#0A0A0F";
const BG_CARD      = "#12121A";
const BG_SURFACE   = "#1C1C27";
const BORDER       = "#1F1F2E";
const TEXT_SUB     = "#8A8A9A";
const TEXT_MUTED   = "#3D3D50";
const GREEN        = "#22C55E";
const AMBER        = "#F59E0B";
const RED          = "#EF4444";
const PURPLE       = "#8B5CF6";

// ════════════════════════════════════════════════════════
//  MAIN HANDLER
// ════════════════════════════════════════════════════════
serve(async (req: Request) => {
  try {
    const payload = await req.json();

    // Supabase webhooks send { type, table, record, old_record }
    const table     = payload.table  as string;
    const record    = payload.record as Record<string, unknown>;
    const oldRecord = payload.old_record as Record<string, unknown> | null;

    if (!record) {
      return _response({ error: "No record in payload" }, 400);
    }

    // Route to correct handler based on table
    if (table === "reservations") {
      return await _handleReservationUpdate(record, oldRecord);
    }

    if (table === "inquiries") {
      return await _handleInquiryUpdate(record, oldRecord);
    }

    return _response({ error: `Unknown table: ${table}` }, 400);

  } catch (err) {
    console.error("Function error:", err);
    return _response({ error: String(err) }, 500);
  }
});

// ════════════════════════════════════════════════════════
//  RESERVATION UPDATE HANDLER
//  Fires when admin changes: pending → approved / rejected / completed
// ════════════════════════════════════════════════════════
async function _handleReservationUpdate(
  record: Record<string, unknown>,
  oldRecord: Record<string, unknown> | null,
): Promise<Response> {

  const newStatus = record.status as string ?? "";
  const oldStatus = oldRecord?.status as string ?? "";

  // Only notify when status actually changed
  if (newStatus === oldStatus) {
    console.log("Status unchanged — skipping notification.");
    return _response({ skipped: true, reason: "status_unchanged" });
  }

  // Only notify for meaningful status changes
  const notifiableStatuses = ["approved", "completed", "rejected", "pending"];
  if (!notifiableStatuses.includes(newStatus)) {
    return _response({ skipped: true, reason: "status_not_notifiable" });
  }

  // ── Extract customer info from reservation record
  const customerName  = record.customer_name  as string ?? "Valued Customer";
  const customerEmail = record.customer_email as string ?? "";
  const reservationId = record.id             as string ?? "—";
  const notes         = record.notes          as string ?? "";
  const resDate       = record.reservation_date as string ?? "";
  const updatedAt     = record.updated_at     as string ?? new Date().toISOString();

  // Try to get car details from DB
  const carId  = record.car_id as string | null;
  let   carLabel = "your reserved vehicle";

  if (carId && SUPABASE_URL && SUPABASE_SERVICE_KEY) {
    try {
      const sb  = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      const res = await sb
        .from("cars")
        .select("make, model, year")
        .eq("id", carId)
        .single();
      if (res.data) {
        carLabel = `${res.data.year} ${res.data.make} ${res.data.model}`;
      }
    } catch (e) {
      console.warn("Could not fetch car details:", e);
    }
  }

  if (!customerEmail) {
    console.warn("No customer email on reservation — cannot notify.");
    return _response({ skipped: true, reason: "no_customer_email" });
  }

  // ── Status display config
  const statusConfig = _reservationStatusConfig(newStatus);

  // ── Build subject line
  const subject = `${statusConfig.emoji} Your Reservation — ${statusConfig.label} | Meridian Motors`;

  // ── Build HTML email
  const html = _buildReservationEmail({
    customerName,
    carLabel,
    newStatus,
    oldStatus,
    statusConfig,
    reservationId,
    resDate,
    notes,
    updatedAt,
  });

  // ── Send email
  return await _sendEmail({
    to:      customerEmail,
    subject,
    html,
  });
}

// ════════════════════════════════════════════════════════
//  INQUIRY UPDATE HANDLER
//  Fires when admin marks is_read or adds admin_response
// ════════════════════════════════════════════════════════
async function _handleInquiryUpdate(
  record: Record<string, unknown>,
  oldRecord: Record<string, unknown> | null,
): Promise<Response> {

  const newResponse = record.admin_response as string | null;
  const oldResponse = oldRecord?.admin_response as string | null;

  // Only notify when admin has ADDED a response (not just marked as read)
  if (!newResponse || newResponse === oldResponse) {
    console.log("No new admin response — skipping notification.");
    return _response({ skipped: true, reason: "no_new_response" });
  }

  const customerName  = record.name    as string ?? "Valued Customer";
  const customerEmail = record.email   as string ?? "";
  const subject_line  = record.subject as string ?? "Your Inquiry";
  const message       = record.message as string ?? "";
  const respondedAt   = record.responded_at as string ?? new Date().toISOString();
  const inquiryId     = record.id      as string ?? "—";

  if (!customerEmail) {
    console.warn("No customer email on inquiry — cannot notify.");
    return _response({ skipped: true, reason: "no_customer_email" });
  }

  const emailSubject =
    `💬 We've Responded to Your Inquiry | Meridian Motors`;

  const html = _buildInquiryEmail({
    customerName,
    subject_line,
    originalMessage: message,
    adminResponse:   newResponse,
    respondedAt,
    inquiryId,
  });

  return await _sendEmail({
    to:      customerEmail,
    subject: emailSubject,
    html,
  });
}

// ════════════════════════════════════════════════════════
//  EMAIL BUILDER — RESERVATION UPDATE
// ════════════════════════════════════════════════════════
interface ReservationEmailParams {
  customerName:  string;
  carLabel:      string;
  newStatus:     string;
  oldStatus:     string;
  statusConfig:  ReturnType<typeof _reservationStatusConfig>;
  reservationId: string;
  resDate:       string;
  notes:         string;
  updatedAt:     string;
}

function _buildReservationEmail(p: ReservationEmailParams): string {
  const { customerName, carLabel, newStatus, statusConfig,
          reservationId, resDate, notes, updatedAt } = p;

  const isCompleted = newStatus === "completed";
  const isRejected  = newStatus === "rejected";
  const isApproved  = newStatus === "approved";

  // Personalised message per status
  const personalMessage = isApproved
    ? `Great news! Your reservation for the <strong>${carLabel}</strong> has been <strong style="color:${GREEN}">approved</strong> by our team. We're excited to have you visit us.`
    : isCompleted
    ? `Your reservation for the <strong>${carLabel}</strong> has been marked as <strong style="color:${PURPLE}">completed</strong>. Thank you for choosing Meridian Motors!`
    : isRejected
    ? `We regret to inform you that your reservation for the <strong>${carLabel}</strong> could not be processed at this time. Please contact us or submit a new inquiry and we'll do our best to assist you.`
    : `Your reservation for the <strong>${carLabel}</strong> has been updated to <strong>${statusConfig.label}</strong>.`;

  // CTA label
  const ctaLabel = isRejected
    ? "Contact Us"
    : "View My Reservations";

  const ctaUrl = isRejected
    ? "https://meridianmotors.com/contact"
    : "https://meridianmotors.com/dashboard/reservations";

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>Reservation Update — Meridian Motors</title>
</head>
<body style="margin:0;padding:0;background:${BG_DARK};
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0"
         style="background:${BG_DARK};padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0"
               style="max-width:600px;width:100%;">

          <!-- ══ HEADER with logo ════════════════════════ -->
          <tr>
            <td style="background:${BRAND_NAVY};
                       border-radius:20px 20px 0 0;
                       padding:32px 36px 24px;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td>
                    <!-- Logo -->
                    <img
                      src="${LOGO_URL}"
                      alt="Meridian Motors"
                      width="120"
                      style="display:block;margin-bottom:20px;
                             border-radius:8px;"
                      onerror="this.style.display='none'"
                    />
                    <!-- Fallback text logo if image fails -->
                    <p style="margin:0 0 4px;
                               color:rgba(255,255,255,0.5);
                               font-size:10px;font-weight:700;
                               letter-spacing:2.5px;
                               text-transform:uppercase;">
                      Meridian Motors
                    </p>
                    <h1 style="margin:0;color:#FFFFFF;
                               font-size:26px;font-weight:900;
                               letter-spacing:-0.5px;line-height:1.2;">
                      Reservation Update
                    </h1>
                  </td>
                  <td align="right" valign="top">
                    <!-- Status badge -->
                    <span style="display:inline-block;
                                 background:${statusConfig.color};
                                 color:#FFFFFF;
                                 font-size:11px;font-weight:700;
                                 padding:7px 14px;
                                 border-radius:20px;
                                 letter-spacing:0.8px;
                                 text-transform:uppercase;">
                      ${statusConfig.emoji} ${statusConfig.label}
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ══ STATUS BANNER ══════════════════════════ -->
          <tr>
            <td style="background:${statusConfig.color};padding:14px 36px;">
              <p style="margin:0;color:#FFFFFF;font-size:14px;line-height:1.5;">
                ${statusConfig.emoji}&nbsp;
                Hi <strong>${customerName}</strong> —
                your reservation status has changed to
                <strong>${statusConfig.label}</strong>.
              </p>
            </td>
          </tr>

          <!-- ══ BODY ════════════════════════════════════ -->
          <tr>
            <td style="background:${BG_CARD};padding:36px;">

              <!-- Greeting -->
              <p style="margin:0 0 20px;color:#FFFFFF;
                         font-size:16px;line-height:1.6;">
                Dear <strong>${customerName}</strong>,
              </p>
              <p style="margin:0 0 28px;color:#CBD5E1;
                         font-size:14px;line-height:1.7;">
                ${personalMessage}
              </p>

              <!-- Reservation details card -->
              <p style="margin:0 0 10px;
                         color:${TEXT_SUB};
                         font-size:10px;font-weight:700;
                         letter-spacing:1.5px;
                         text-transform:uppercase;">
                Reservation Details
              </p>
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:${BG_SURFACE};
                            border-radius:14px;
                            border:1px solid ${BORDER};
                            margin-bottom:28px;">
                <tr>
                  <td style="padding:20px 24px;">
                    ${_row("Vehicle",          carLabel)}
                    ${_row("Reservation ID",   _short(reservationId))}
                    ${_row("Reservation Date", resDate ? _fmtDate(resDate) : "—")}
                    ${_row("New Status",       statusConfig.label,
                           statusConfig.color)}
                    ${_row("Updated At",       _fmtDateTime(updatedAt))}
                    ${notes ? _row("Notes", notes) : ""}
                  </td>
                </tr>
              </table>

              ${isApproved ? _nextStepsBox() : ""}
              ${isRejected ? _rejectedBox() : ""}

              <!-- CTA button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0 8px;">
                    <a href="${ctaUrl}"
                       style="display:inline-block;
                              background:${BRAND_BLUE};
                              color:#FFFFFF;
                              text-decoration:none;
                              font-size:15px;font-weight:700;
                              padding:15px 36px;
                              border-radius:14px;
                              letter-spacing:0.3px;">
                      ${ctaLabel} →
                    </a>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- ══ FOOTER ══════════════════════════════════ -->
          ${_footer()}

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();
}

// ════════════════════════════════════════════════════════
//  EMAIL BUILDER — INQUIRY RESPONSE
// ════════════════════════════════════════════════════════
interface InquiryEmailParams {
  customerName:    string;
  subject_line:    string;
  originalMessage: string;
  adminResponse:   string;
  respondedAt:     string;
  inquiryId:       string;
}

function _buildInquiryEmail(p: InquiryEmailParams): string {
  const { customerName, subject_line, originalMessage,
          adminResponse, respondedAt, inquiryId } = p;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>Inquiry Response — Meridian Motors</title>
</head>
<body style="margin:0;padding:0;background:${BG_DARK};
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0"
         style="background:${BG_DARK};padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0"
               style="max-width:600px;width:100%;">

          <!-- ══ HEADER with logo ════════════════════════ -->
          <tr>
            <td style="background:${BRAND_NAVY};
                       border-radius:20px 20px 0 0;
                       padding:32px 36px 24px;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td>
                    <!-- Company logo -->
                    <img
                      src="${LOGO_URL}"
                      alt="Meridian Motors"
                      width="120"
                      style="display:block;margin-bottom:20px;
                             border-radius:8px;"
                      onerror="this.style.display='none'"
                    />
                    <p style="margin:0 0 4px;
                               color:rgba(255,255,255,0.5);
                               font-size:10px;font-weight:700;
                               letter-spacing:2.5px;
                               text-transform:uppercase;">
                      Meridian Motors
                    </p>
                    <h1 style="margin:0;color:#FFFFFF;
                               font-size:26px;font-weight:900;
                               letter-spacing:-0.5px;line-height:1.2;">
                      We've Responded to<br/>Your Inquiry
                    </h1>
                  </td>
                  <td align="right" valign="top">
                    <span style="display:inline-block;
                                 background:${BRAND_BLUE};
                                 color:#FFFFFF;
                                 font-size:11px;font-weight:700;
                                 padding:7px 14px;
                                 border-radius:20px;
                                 letter-spacing:0.8px;">
                      💬 REPLY
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ══ BANNER ══════════════════════════════════ -->
          <tr>
            <td style="background:${BRAND_BLUE};padding:14px 36px;">
              <p style="margin:0;color:#FFFFFF;font-size:14px;line-height:1.5;">
                💬&nbsp; Hi <strong>${customerName}</strong> —
                our team has responded to your inquiry.
              </p>
            </td>
          </tr>

          <!-- ══ BODY ════════════════════════════════════ -->
          <tr>
            <td style="background:${BG_CARD};padding:36px;">

              <!-- Greeting -->
              <p style="margin:0 0 20px;color:#FFFFFF;
                         font-size:16px;line-height:1.6;">
                Dear <strong>${customerName}</strong>,
              </p>
              <p style="margin:0 0 28px;color:#CBD5E1;
                         font-size:14px;line-height:1.7;">
                Thank you for reaching out to us. Our team has reviewed
                your inquiry and provided a response below.
              </p>

              <!-- Subject line -->
              <p style="margin:0 0 10px;
                         color:${TEXT_SUB};
                         font-size:10px;font-weight:700;
                         letter-spacing:1.5px;
                         text-transform:uppercase;">
                Your Inquiry
              </p>
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:${BG_SURFACE};
                            border-radius:14px;
                            border:1px solid ${BORDER};
                            margin-bottom:24px;">
                <tr>
                  <td style="padding:18px 22px;">
                    <p style="margin:0 0 8px;
                               color:${TEXT_SUB};font-size:11px;
                               font-weight:700;letter-spacing:1px;
                               text-transform:uppercase;">
                      Subject
                    </p>
                    <p style="margin:0 0 16px;color:#FFFFFF;
                               font-size:14px;font-weight:600;">
                      ${subject_line}
                    </p>
                    ${originalMessage ? `
                    <p style="margin:0 0 8px;
                               color:${TEXT_SUB};font-size:11px;
                               font-weight:700;letter-spacing:1px;
                               text-transform:uppercase;">
                      Your Message
                    </p>
                    <p style="margin:0;color:#9CA3AF;
                               font-size:13px;line-height:1.6;
                               font-style:italic;
                               border-left:3px solid ${BORDER};
                               padding-left:12px;">
                      ${originalMessage}
                    </p>` : ""}
                  </td>
                </tr>
              </table>

              <!-- Admin response -->
              <p style="margin:0 0 10px;
                         color:${TEXT_SUB};
                         font-size:10px;font-weight:700;
                         letter-spacing:1.5px;
                         text-transform:uppercase;">
                Response from Meridian Motors
              </p>
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:#0F2C59;
                            border-radius:14px;
                            border:1px solid rgba(30,86,214,0.3);
                            margin-bottom:28px;">
                <tr>
                  <td style="padding:22px 24px;">
                    <!-- Team avatar row -->
                    <table cellpadding="0" cellspacing="0"
                           style="margin-bottom:14px;">
                      <tr>
                        <td style="width:38px;">
                          <div style="width:36px;height:36px;
                                      background:rgba(30,86,214,0.3);
                                      border-radius:50%;
                                      display:flex;align-items:center;
                                      justify-content:center;
                                      font-size:16px;text-align:center;
                                      line-height:36px;">
                            🛡️
                          </div>
                        </td>
                        <td style="padding-left:10px;">
                          <p style="margin:0;color:#FFFFFF;
                                     font-size:13px;font-weight:700;">
                            Meridian Motors Team
                          </p>
                          <p style="margin:0;color:rgba(255,255,255,0.5);
                                     font-size:11px;">
                            ${_fmtDateTime(respondedAt)}
                          </p>
                        </td>
                      </tr>
                    </table>
                    <p style="margin:0;color:#E2E8F0;
                               font-size:14px;line-height:1.75;
                               white-space:pre-wrap;">
                      ${adminResponse}
                    </p>
                  </td>
                </tr>
              </table>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0;">
                    <a href="https://meridianmotors.com/dashboard/inquiries"
                       style="display:inline-block;
                              background:${BRAND_BLUE};
                              color:#FFFFFF;text-decoration:none;
                              font-size:15px;font-weight:700;
                              padding:15px 36px;
                              border-radius:14px;">
                      View Full Conversation →
                    </a>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- ══ FOOTER ══════════════════════════════════ -->
          ${_footer()}

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();
}

// ════════════════════════════════════════════════════════
//  SHARED EMAIL SENDER
// ════════════════════════════════════════════════════════
async function _sendEmail(params: {
  to:      string;
  subject: string;
  html:    string;
}): Promise<Response> {
  const res = await fetch("https://api.resend.com/emails", {
    method:  "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type":  "application/json",
    },
    body: JSON.stringify({
      from:    EMAIL_FROM,
      to:      [params.to],
      subject: params.subject,
      html:    params.html,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("Resend error:", err);
    return _response({ error: "Email send failed", details: err }, 500);
  }

  const data = await res.json();
  console.log(`✅ Email sent to ${params.to} — ID: ${data.id}`);
  return _response({ success: true, emailId: data.id });
}

// ════════════════════════════════════════════════════════
//  STATUS CONFIG
// ════════════════════════════════════════════════════════
function _reservationStatusConfig(status: string) {
  const map: Record<string, { label: string; color: string; emoji: string }> = {
    approved:  { label: "Approved",   color: "#22C55E", emoji: "✅" },
    completed: { label: "Completed",  color: "#8B5CF6", emoji: "🎉" },
    rejected:  { label: "Rejected",   color: "#EF4444", emoji: "❌" },
    pending:   { label: "Pending",    color: "#F59E0B", emoji: "⏳" },
    cancelled: { label: "Cancelled",  color: "#6B7280", emoji: "🚫" },
  };
  return map[status] ?? { label: status, color: "#1E56D6", emoji: "ℹ️" };
}

// ════════════════════════════════════════════════════════
//  HTML SNIPPETS
// ════════════════════════════════════════════════════════

// Info row inside a details card
function _row(label: string, value: string, valueColor?: string): string {
  return `
    <table width="100%" cellpadding="0" cellspacing="0"
           style="margin-bottom:12px;">
      <tr>
        <td width="150" style="color:${TEXT_SUB};
                                font-size:12px;
                                vertical-align:top;
                                padding-right:12px;">
          ${label}
        </td>
        <td style="color:${valueColor ?? "#FFFFFF"};
                   font-size:13px;font-weight:600;">
          ${value}
        </td>
      </tr>
    </table>`;
}

// Next steps box shown when approved
function _nextStepsBox(): string {
  return `
    <table width="100%" cellpadding="0" cellspacing="0"
           style="background:rgba(34,197,94,0.08);
                  border-radius:14px;
                  border:1px solid rgba(34,197,94,0.2);
                  margin-bottom:24px;">
      <tr>
        <td style="padding:18px 22px;">
          <p style="margin:0 0 10px;color:#22C55E;
                     font-size:12px;font-weight:700;
                     letter-spacing:1px;text-transform:uppercase;">
            ✅ Next Steps
          </p>
          <ul style="margin:0;padding-left:18px;
                     color:#CBD5E1;font-size:13px;
                     line-height:1.8;">
            <li>Our team will contact you to confirm the visit date.</li>
            <li>Please bring a valid ID and proof of insurance.</li>
            <li>The vehicle will be held for 48 hours pending your visit.</li>
          </ul>
        </td>
      </tr>
    </table>`;
}

// Info box shown when rejected
function _rejectedBox(): string {
  return `
    <table width="100%" cellpadding="0" cellspacing="0"
           style="background:rgba(239,68,68,0.08);
                  border-radius:14px;
                  border:1px solid rgba(239,68,68,0.2);
                  margin-bottom:24px;">
      <tr>
        <td style="padding:18px 22px;">
          <p style="margin:0 0 10px;color:#EF4444;
                     font-size:12px;font-weight:700;
                     letter-spacing:1px;text-transform:uppercase;">
            What to do next
          </p>
          <p style="margin:0;color:#CBD5E1;
                     font-size:13px;line-height:1.7;">
            Don't worry — we have many other vehicles available.
            Browse our full inventory or send us a new inquiry
            and our team will help find the perfect car for you.
          </p>
        </td>
      </tr>
    </table>`;
}

// Shared footer
function _footer(): string {
  return `
    <tr>
      <td style="background:#0D0D16;
                 border-radius:0 0 20px 20px;
                 padding:24px 36px;
                 border-top:1px solid ${BORDER};">
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr>
            <td align="center">
              <p style="margin:0 0 8px;
                         color:${TEXT_MUTED};
                         font-size:12px;line-height:1.6;">
                © ${new Date().getFullYear()} Meridian Motors.
                All rights reserved.
              </p>
              <p style="margin:0;
                         color:${TEXT_MUTED};
                         font-size:11px;">
                You received this email because you have an account
                with Meridian Motors.<br/>
                Please do not reply to this email — contact us at
                <a href="mailto:contact@meridianmotors.com"
                   style="color:#1E56D6;text-decoration:none;">
                  contact@meridianmotors.com
                </a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>`;
}

// ════════════════════════════════════════════════════════
//  UTILITY HELPERS
// ════════════════════════════════════════════════════════
function _response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function _fmtDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("en-US", {
      weekday: "long",
      year:    "numeric",
      month:   "long",
      day:     "numeric",
    });
  } catch { return iso; }
}

function _fmtDateTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString("en-US", {
      year:   "numeric",
      month:  "short",
      day:    "numeric",
      hour:   "2-digit",
      minute: "2-digit",
    });
  } catch { return iso; }
}

function _short(id: string): string {
  return id.length > 8 ? `${id.substring(0, 8)}…` : id;
}
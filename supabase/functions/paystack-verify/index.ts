import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(null, { status: 405 });
  }

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return new Response(null, { status: 401 });
  }

  const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secretKey) {
    return Response.json({ error: "Missing PAYSTACK_SECRET_KEY" }, { status: 500 });
  }

  const body = await req.json().catch(() => null);
  const reference = body?.reference;

  if (typeof reference !== "string" || !reference) {
    return Response.json({ error: "Missing reference" }, { status: 400 });
  }

  const response = await fetch(
    `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
    { headers: { Authorization: `Bearer ${secretKey}` } },
  );

  const json = await response.json().catch(() => null);
  if (!response.ok || !json?.status) {
    return Response.json({ error: json?.message ?? "Unable to verify payment" }, { status: 400 });
  }

  const rawStatus = json.data?.status;
  const paid = rawStatus === "success";

  return Response.json({ paid, rawStatus }, { status: 200 });
});

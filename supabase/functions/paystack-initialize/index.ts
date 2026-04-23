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
  const email = body?.email;
  const amountKobo = body?.amountKobo;
  const reference = body?.reference;

  if (typeof email !== "string" || !email) {
    return Response.json({ error: "Missing email" }, { status: 400 });
  }
  if (typeof amountKobo !== "number" || !Number.isFinite(amountKobo) || amountKobo <= 0) {
    return Response.json({ error: "Invalid amountKobo" }, { status: 400 });
  }
  if (typeof reference !== "string" || !reference) {
    return Response.json({ error: "Missing reference" }, { status: 400 });
  }

  const response = await fetch("https://api.paystack.co/transaction/initialize", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, amount: amountKobo, reference, currency: "NGN" }),
  });

  const json = await response.json().catch(() => null);
  if (!response.ok || !json?.status) {
    return Response.json({ error: json?.message ?? "Unable to initialize payment" }, { status: 400 });
  }

  return Response.json(
    { accessCode: json.data.access_code, reference: json.data.reference },
    { status: 200 },
  );
});

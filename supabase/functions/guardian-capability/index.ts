import { createHandler, createRpc, createTransport } from "./server.mjs";

// Deployment remains inert until consent, receiver and hosted synthetic gates pass.
Deno.serve(createHandler({
  enabled: Deno.env.get("GUARDIAN_CAPABILITY_ENABLED") === "true",
  rpc: () =>
    createRpc(
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      createTransport(),
    ),
}));

import {
  createFcmProvider,
  createHandler,
  createRpc,
  createTransport,
  dispatchBatch,
} from "./worker.mjs";

// Explicitly disabled until reviewed backend secret/scheduler deployment.
Deno.serve(createHandler({
  enabled: Deno.env.get("GUARDIAN_DISPATCH_ENABLED") === "true",
  secret: Deno.env.get("GUARDIAN_WORKER_SECRET"),
  run: async () => {
    const transport = createTransport();
    const rpc = createRpc(
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      transport,
    );
    const provider = createFcmProvider(
      Deno.env.get("GUARDIAN_FCM_PROJECT_ID"),
      JSON.parse(Deno.env.get("GUARDIAN_FCM_SERVICE_ACCOUNT") ?? "{}"),
      transport,
    );
    return await dispatchBatch(rpc, provider);
  },
}));

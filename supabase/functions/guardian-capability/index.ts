import { createHandler, createRpc, createTransport } from "./server.mjs";
import {
  createProcessingWindowGate,
  createWindowFetch,
} from "../_shared/processing_window.mjs";

const processingAllowed = createProcessingWindowGate(
  Deno.env.get("GUARDIAN_CAPABILITY_ENABLED"),
  Deno.env.get("GUARDIAN_PROCESSING_WINDOW_V1"),
);

// Deployment remains inert until consent, receiver and hosted synthetic gates pass.
Deno.serve(createHandler({
  enabled: processingAllowed,
  rpc: () =>
    createRpc(
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      createTransport(createWindowFetch(processingAllowed)),
    ),
}));

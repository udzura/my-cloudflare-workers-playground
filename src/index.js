import { createWorker } from "../generated/worker/runtime/index.js";
import app from "../generated/worker/app.bin";
import { cloudflareBindingTypes } from "../generated/worker/bindings.js";

export { PicoRubyDurableObject } from "../generated/worker/runtime/index.js";

async function timingSafeEqual(a, b) {
  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);
  if (aBytes.byteLength !== bBytes.byteLength) return false;
  return crypto.subtle.timingSafeEqual(aBytes, bBytes);
}

async function rackEnv(request, env, _ctx) {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Basic ")) return {};

  let credentials;
  try {
    credentials = atob(authorization.slice(6));
  } catch {
    return {};
  }
  const separator = credentials.indexOf(":");
  if (separator < 0) return {};

  const user = credentials.slice(0, separator);
  const pass = credentials.slice(separator + 1);
  const passed =
    (await timingSafeEqual(user, env.BASIC_AUTH_USER || "dummy")) &&
    (await timingSafeEqual(pass, env.BASIC_AUTH_PASS || "dummy"));
  return passed ? { "custom.basic_auth_passed": true } : {};
}

async function afterRequest(request, env, _ctx, rackEnv, response) {
  if (rackEnv["custom.basic_auth_passed"] !== true) return response;

  const pathname = new URL(request.url).pathname;
  if (pathname === "/" || pathname === "/index.html") {
    return env.ASSETS.fetch(request);
  }
  return response;
}

export default createWorker({
  app,
  bindingTypes: cloudflareBindingTypes,
  rackEnv,
  afterRequest,
});

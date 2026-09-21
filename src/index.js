import { createWorker } from "../generated/worker/runtime/index.js";
import app from "../generated/worker/app.bin";
import { cloudflareBindingTypes } from "../generated/worker/bindings.js";

export { PicoRubyDurableObject } from "../generated/worker/runtime/index.js";

async function timingSafeEqual(a, b) {
    const enc = new TextEncoder();
    const aBytes = enc.encode(a);
    const bBytes = enc.encode(b);
    if (aBytes.byteLength !== bBytes.byteLength) return false;
    return crypto.subtle.timingSafeEqual(aBytes, bBytes);
}

export default {
    async fetch(request, env) {
        const authorization = request.headers.get('Authorization');

        if (!authorization || !authorization.startsWith('Basic ')) {
            return new Response('Authentication required.', {
                status: 401,
                headers: { 'WWW-Authenticate': 'Basic realm="Restricted"' },
            });
        }

        const [user, pass] = atob(authorization.slice(6)).split(':');
        const ok =
            (await timingSafeEqual(user, (env.BASIC_AUTH_USER || "dummy"))) &&
            (await timingSafeEqual(pass, (env.BASIC_AUTH_PASS || "dummy")));

        if (!ok) {
            return new Response('Authentication required.', {
                status: 401,
                headers: { 'WWW-Authenticate': 'Basic realm="Restricted"' },
            });
        }

        const url = new URL(request.url);
        if (url.pathname !== '/' && url.pathname !== ('/index.html')) {
            const workerFetch = createWorker({ app, bindingTypes: cloudflareBindingTypes });
            return workerFetch.fetch(request, env);
        }

        return env.ASSETS.fetch(request);
    },
};

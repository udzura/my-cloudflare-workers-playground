import { bindings, defineConfig, exports } from "cf/config";

/**
 * Secret-like files were detected but not read or migrated: .env, .picoruby-build/repos/worker/picoruby-cloudflare-worker-wasm/examples/cookie-simple/.dev.vars.example. Only `secrets.required` entries are migrated.
 * @see https://developers.cloudflare.com/workers/configuration/secrets/
 */

export default defineConfig({
	worker: {
		name: "hello-mruby",
		compatibilityDate: "2026-08-22",
		entrypoint: "src/index.js",
		assets: {
			runWorkerFirst: true,
		},
		env: {
			CF_ACCESS_TEAM: bindings.text("test"),
			GREETING: bindings.text("Hello from PicoRuby on Cloudflare!"),
			VECTOR_INDEX: bindings.vectorize({
				name: "hello-mruby-documents",
				dev: {
					remote: true,
				},
			}),
			SESSIONS: bindings.durableObject({
				worker: "hello-mruby",
				exportName: "PicoRubyDurableObject",
			}),
			AI: bindings.ai({}),
			ASSETS: bindings.assets(),
		},
		exports: {
			PicoRubyDurableObject: exports.durableObject({ storage: "sqlite" }),
		}
	},
});

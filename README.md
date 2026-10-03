# hello-mruby

PicoRuby Rack application on Cloudflare Workers.

1. Install Ruby >= 3.2 and Node.js (supported by Wrangler). On macOS, install Emscripten via Homebrew as shown below.
2. Set `PICORUBY_ROOT` to a PicoRuby checkout with its submodules initialized.
3. Run `bundle install` and `npm install`.
4. Run `bundle exec rake doctor`, then `bundle exec rake`.
5. Run `npm run dev`. Wrangler's custom build also runs Rake on startup and Ruby changes.

```sh
brew install emscripten
export PATH="$(brew --prefix emscripten)/bin:$PATH"
emcc --version
```

Emscripten 5.0.0 or later is accepted; 5.0.7 and Homebrew 6.0.9 are tested.
Newer versions are accepted but not necessarily tested. If switching from emsdk,
use a shell without `emsdk_env.sh` and unset `EMSDK`, `EM_CONFIG`, and `EM_CACHE`.

The pinned Wrangler version is paired with compatibility date `2026-08-22`.
Update and test them together; a dry-run alone does not start workerd.

During development of the unpublished runtime, set these attributes in the
`cloudflare_worker!` block in `build_config.rb`:

```ruby
conf.cloudflare_worker! do |cf|
  cf.picoruby_cloudflare_worker_wasm_mgem_dir = "/path/to/picoruby-cloudflare-worker-wasm"
  # Optional: use a local Rack checkout too.
  cf.mruby_rack_mgem_dir = "/path/to/mruby-rack"
end
```

The block receives the CrossBuild object itself and runs before build setup.
Calling without a block is also supported. Both directory attributes default to `nil`, which selects the GitHub sources
configured by the template gem. Override those refs in the same block using
`cf.picoruby_cloudflare_worker_wasm_revision` and `cf.mruby_rack_mgem_revision`.
Directory attributes take precedence over revision attributes; relative paths
are resolved against `build_config.rb`. These sources are not selected through
environment variables. The Worker source is pinned by the template gem; see its README for the current revision.

`build_config.rb` selects mrbgems and exports an ES module to `generated/worker/`.
Do not edit generated files. The generated Wasm, JS and app bytecode are one unit;
use Wrangler to bundle them, not a plain Node.js import of `src/index.js`.

Configure bindings in `wrangler.jsonc`; the build regenerates `bindings.js`.
Ruby can use `env["cloudflare.env"].CACHE_KV` or
`Cloudflare::KV.from_env(env, "CACHE_KV")`, and similarly `Cloudflare::Queue.from_env`.
Durable Objects use `Cloudflare::DurableObject.from_env`; `put` accepts POJO,
Hash, Array, or an object responding to `to_pojo`.
String/JSON vars and secrets are accessible through Ruby `ENV`.

If this project was generated with `--bindings`, app.rb exposes `/kv`, `/queue`,
`/durable-object` and `/access`
examples and `.picoruby-cloudflare-template.json` tracks their generated state.
Run `picoruby-cloudflare bindings .` with a newer template to refresh unedited
binding examples. The command refuses to overwrite an edited app.rb or wrangler.jsonc.

For `/access`, set `CF_ACCESS_TEAM` to your team name (not its URL) in Wrangler vars
or .dev.vars, and send a `CF_Authorization` cookie issued by Access.
`Rack::Cloudflare::Access.new(app, team: "my-team")` is Rack middleware.
Omit `team:` to read `CF_ACCESS_TEAM` from the Worker environment.
Before calling the app, it stores the decoded identity in `env["cloudflare.identity"]`,
with `email`, `user_uuid` and `raw_data`. The generated example wraps only `/access`.
The helper `Cloudflare::Access.get_identity(token, team: "my-team")` calls
`Cloudflare.fetch` from Ruby. Missing/invalid configuration returns 503; missing/invalid
cookies and Access 401/403 responses return 401; upstream/protocol failures return 502.
Failures do not call the downstream app. This does not locally validate JWT signatures or audience.
Protect your application with Access and follow Cloudflare's token validation guidance.
The default Worker and mruby-rack revisions include Access, cookie parsing and
middleware keyword forwarding. No local mrbgem checkout overrides are required.

Keep secrets in `.dev.vars` locally and use `npx wrangler secret put NAME` remotely.
Never put them in `app.rb`, `build_config.rb` or committed config files.

## RAG API

The application uses Workers AI and Vectorize to register, search, and answer
questions over short text documents. Create the 1,024-dimensional index once
before starting the Worker:

```sh
npx wrangler vectorize create hello-mruby-documents --dimensions=1024 --metric=cosine
```

Register and search documents with JSON requests:

```sh
curl -X POST http://localhost:8787/documents \
  -H 'content-type: application/json' \
  -d '{"id":"picoruby","title":"PicoRuby","text":"PicoRuby is a compact Ruby implementation for microcontrollers and small environments."}'

curl -X POST http://localhost:8787/search \
  -H 'content-type: application/json' \
  -d '{"query":"What is PicoRuby?","top_k":5}'

curl -X POST http://localhost:8787/rag \
  -H 'content-type: application/json' \
  -d '{"question":"What is PicoRuby?","top_k":5}'
```

The example stores the complete text in Vectorize metadata and intentionally
limits each document to 7,000 bytes. It treats one registered document as one
vector; production ingestion should split larger documents into chunks with
stable IDs and suitable overlap.

For named environments, set `CLOUDFLARE_ENV=staging npm run dev` (or `npm run deploy`)
so Wrangler and the binding registry select the same environment. Do not select an
environment using only `--env`; custom build processes need `CLOUDFLARE_ENV` too.

Commit `Gemfile.lock` and `package-lock.json`. Deploy explicitly with `npm run deploy`.

## Clef decision demo

Open `/clef.html` to try a support-triage form backed by `POST /api/clef` in
Sinatra. The browser sends a support request as `state`; the endpoint calls
`@cf/cloudflare/clef` with `noul`, `choice`, and `score` questions and returns
the model response, including its per-option probabilities. The example limits
`state` to 12,000 bytes. Inference errors are logged by the Worker and returned
as a generic 502 JSON response.

```sh
curl -X POST http://localhost:8787/api/clef \
  -H 'content-type: application/json' \
  -d '{"state":"Checkout has been failing for every customer for the last hour."}'
```

The page is served from Cloudflare Static Assets and uses the same Basic Auth
as the rest of this playground. See [Cloudflare's Clef model documentation](https://developers.cloudflare.com/workers-ai/models/clef/)
for input types, model limits, and pricing.

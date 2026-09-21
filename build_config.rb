require "picoruby/cloudflare/build"

MRuby::CrossBuild.new("worker") do |conf|
  conf.cloudflare_worker! do |cf|
    # Optional overrides, applied before build setup:
    # cf.picoruby_cloudflare_worker_wasm_mgem_dir = "vendor/picoruby-cloudflare-worker-wasm"
    # cf.mruby_rack_mgem_dir = "vendor/mruby-rack"
    cf.picoruby_cloudflare_worker_wasm_revision = "b3b33aebaf8338ab1d2ee825ca8bffd63469d5f8"
    # cf.picoruby_cloudflare_worker_wasm_revision = "ebab3afc4b06cdb29508de453795de90349c4691"
    # cf.mruby_rack_mgem_revision = "<commit SHA>"
  end

  # Add application mrbgems here, for example:
  # conf.gem gemdir: File.join(__dir__, "vendor/my-gem")
  conf.gem github: "udzura/picoruby-sinatra-covers", checksum_hash: "0b9e08ca47c2f6df42ee03beffe24cf1f386bdac"
  conf.gem github: "udzura/picoruby-rack-sessions-cloudflare", branch: "main"

  conf.worker_export(
    app: "app.rb",
    output_dir: "generated/worker",
    wrangler_config: "wrangler.jsonc",
    environment: ENV.fetch("CLOUDFLARE_ENV", nil),
    project_root: __dir__,
  )
end

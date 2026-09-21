require "picoruby/cloudflare/build"

MRuby::CrossBuild.new("worker") do |conf|
  conf.cloudflare_worker! do |cf|
    # Optional overrides, applied before build setup:
    # cf.picoruby_cloudflare_worker_wasm_mgem_dir = "vendor/picoruby-cloudflare-worker-wasm"
    # cf.mruby_rack_mgem_dir = "vendor/mruby-rack"
    cf.picoruby_cloudflare_worker_wasm_revision = "ff20feb1733a891d03a0c66bf790b2dc7dae4f45"
    # cf.mruby_rack_mgem_revision = "<commit SHA>"
  end

  # Add application mrbgems here, for example:
  # conf.gem gemdir: File.join(__dir__, "vendor/my-gem")
  conf.gem github: "udzura/picoruby-sinatra-covers", checksum_hash: "0.3.1"
  conf.gem github: "udzura/picoruby-rack-sessions-cloudflare", branch: "main"

  conf.worker_export(
    app: "app.rb",
    output_dir: "generated/worker",
    wrangler_config: "wrangler.jsonc",
    environment: ENV["CLOUDFLARE_ENV"],
    project_root: __dir__,
  )
end

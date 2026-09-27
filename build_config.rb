require "picoruby/cloudflare/build"
ENV["PICORUBY_USE_MRUBY_JSONRS"] = "1"

MRuby::CrossBuild.new("worker") do |conf|
  conf.cloudflare_worker! do |cf|
    # Optional overrides, applied before build setup:
    # cf.picoruby_cloudflare_worker_wasm_mgem_dir = "/Users/udzura/ghq/github.com/udzura/picoruby-cloudflare-worker-wasm"
    # cf.mruby_rack_mgem_dir = "vendor/mruby-rack"
    # cf.picoruby_cloudflare_worker_wasm_revision = "ebab3afc4b06cdb29508de453795de90349c4691"
    # cf.mruby_rack_mgem_revision = "<commit SHA>"
  end

  # Add application mrbgems here, for example:
  # conf.gem gemdir: File.join(__dir__, "vendor/my-gem")
  conf.gem github: "udzura/picoruby-sinatra-covers", checksum_hash: "84a2c7f31e80894df4bdf8b6672da2a720ce9fc5"
  conf.gem github: "udzura/picoruby-rack-sessions-cloudflare", branch: "main", checksum_hash: "98a0d34bc6254a839de9abb6d21dee1bd6ff654b"
  conf.gem github: "udzura/mruby-jsonrs", checksum_hash: "0.1.0"

  conf.worker_export(
    app: "app.rb",
    output_dir: "generated/worker",
    wrangler_config: "wrangler.jsonc",
    environment: ENV.fetch("CLOUDFLARE_ENV", nil),
    project_root: __dir__,
  )
end

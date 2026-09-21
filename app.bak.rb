class App < Sinatra::Base
  enable :sessions
  set :session_secret, ENV["SESSION_SECRET"] || ("secret!!"*4)
  if development?
    set :session_store, Rack::Session::CookieSimple, secret: settings.session_secret
  else
    set :session_store, Rack::Session::DurableObject
    set :sessions, {
      binding: "SESSIONS",
      expire_after: 3600,
      secure: true
    }
  end

  get "/" do
    "Hello from Sinatra on Cloudflare Worker!"
  end

  get "/countup" do
    session[:count] ||= 0
    session[:count] += 1
    "Count: #{session[:count]}"
  end

  get "/json" do
    begin
      json({ message: "Hello from JSON endpoint!" })
    rescue StandardError => e
      "An error occurred: #{e.message}"
    end
  end

  get "/raise" do
    raise "This is a test error"
  end
  
  not_found do
    json({ error: "Not Found" })
  end

  error do
    json({ error: "An error occurred: #{env['sinatra.error'].message}" })
  end
end

Rackup::Handler::CloudflareWorker.run(App)

# app = lambda do |env|
#   begin
#     value = case env["PATH_INFO"]
#     when "/kv"
#       kv = Cloudflare::KV.from_env(env, "CACHE_KV")
#       kv.put("greeting", "Hello from Cloudflare KV!", ttl: 60)
#       kv.get("greeting")
#     when "/queue"
#       Cloudflare::Queue.from_env(env, "EVENTS").send("Hello from PicoRuby!")
#       "Message sent to Cloudflare Queue!"
#     when "/durable-object"
#       store = Cloudflare::DurableObject.from_env(env, "OBJECTS")
#       store.put("example", { "message" => "Hello from a Durable Object!" })
#       store.get("example")["message"]
#     when "/access"
#       identity = env["cloudflare.identity"]
#       identity.email || "Access identity has no email"
#     else
#       ENV["GREETING"] || "Hello from PicoRuby on Cloudflare!"
#     end
#     [200, { "content-type" => "text/plain; charset=utf-8" }, [value + "\n"]]
#   rescue
#     [500, { "content-type" => "text/plain; charset=utf-8" }, ["Internal Server Error\n"]]
#   end
# end

# # Apply Access middleware to the identity example.
# access_app = Rack::Builder.new do
#   use Rack::Cloudflare::Access
#   run app
# end
# Rackup::Handler::CloudflareWorker.run(lambda do |env|
#   [200, { "content-type" => "text/plain; charset=utf-8" }, [value + "\n"]]
# end)

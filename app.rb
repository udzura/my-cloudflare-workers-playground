class App < Sinatra::Base
  EMBEDDING_MODEL = "@cf/qwen/qwen3-embedding-0.6b"
  GENERATION_MODEL = "@cf/meta/llama-3.1-8b-instruct-fast"
  VECTOR_INDEX = "VECTOR_INDEX"
  MAX_DOCUMENT_BYTES = 7_000
  MAX_QUERY_BYTES = 2_000
  MAX_CLEF_STATE_BYTES = 12_000
  MAX_TOP_K = 10

  before do
    halt 401, { "WWW-Authenticate" => 'Basic realm="Restricted"' }, "Authentication required." unless env["custom.basic_auth_passed"]
  end

  helpers do
    def cloudflare_hijack(descriptor)
      content_type "text/event-stream"
      headers "cache-control" => "no-cache"
      env["cloudflare.hijack"] = descriptor
      body []
    end
  end

  def json_response(value, status_code = 200)
    status status_code
    headers "content-type" => "application/json; charset=utf-8"
    JSON.generate(value)
  end

  def request_json
    value = JSON.parse(env["rack.input"].read)
    raise ArgumentError, "request body must be a JSON object" unless value.is_a?(Hash)

    value
  rescue JSON::JSONError, JSON::ParserError => error
    raise ArgumentError, "request body contains invalid JSON: #{error.message}"
  end

  def required_string(payload, key, max_bytes)
    value = payload[key]
    unless value.is_a?(String) && !value.empty?
      raise ArgumentError, "#{key} must be a non-empty String"
    end
    raise ArgumentError, "#{key} is too long" if value.bytesize > max_bytes

    value
  end

  def optional_string(payload, key, max_bytes)
    value = payload[key]
    return nil if value.nil?
    unless value.is_a?(String) && value.bytesize <= max_bytes
      raise ArgumentError, "#{key} must be a String of at most #{max_bytes} bytes"
    end

    value
  end

  def top_k(payload)
    value = payload["top_k"] || 5
    unless value.is_a?(Integer) && value >= 1 && value <= MAX_TOP_K
      raise ArgumentError, "top_k must be an Integer between 1 and #{MAX_TOP_K}"
    end

    value
  end

  def cloudflare
    env["cloudflare.env"]
  end

  def embed(text)
    cloudflare.AI.embed(EMBEDDING_MODEL, { "text" => [text] }).first
  end

  def search_documents(query, limit)
    result = cloudflare[VECTOR_INDEX].query(
      embed(query), top_k: limit, return_metadata: :all
    )
    matches = result["matches"]
    raise Cloudflare::ProtocolError, "Vectorize query result must contain matches" unless matches.is_a?(Array)

    matches
  end

  def source_from_match(match)
    metadata = match["metadata"].is_a?(Hash) ? match["metadata"] : {}
    {
      "id" => match["id"],
      "score" => match["score"],
      "title" => metadata["title"],
      "text" => metadata["text"],
    }
  end

  def context_from_matches(matches)
    parts = []
    matches.each_with_index do |match, index|
      source = source_from_match(match)
      parts << "[#{index + 1}] #{source["title"] || source["id"]}\n#{source["text"]}"
    end
    parts.join("\n\n")
  end

  get "/" do
    json_response({
      "service" => "PicoRuby RAG API",
      "embedding_model" => EMBEDDING_MODEL,
      "generation_model" => GENERATION_MODEL,
      "endpoints" => {
        "register" => "POST /documents",
        "search" => "POST /search",
        "rag" => "POST /rag",
        "clef" => "POST /api/clef",
      },
    })
  end

  get "/healthz" do
    p "debug env: #{env["rack.input"].inspect}"
    json_response({ "status" => "ok", "now" => Time.now.to_s, "now_jst" => Time.now.getlocal("+09:00").to_s })
  end

  post "/documents" do
    begin
      payload = request_json
      id = required_string(payload, "id", 64)
      text = required_string(payload, "text", MAX_DOCUMENT_BYTES)
      title = optional_string(payload, "title", 512)

      metadata = { "text" => text }
      metadata["title"] = title unless title.nil?
      mutation = cloudflare[VECTOR_INDEX].upsert([
        { "id" => id, "values" => embed(text), "metadata" => metadata },
      ])

      json_response({
        "id" => id,
        "model" => EMBEDDING_MODEL,
        "mutation" => mutation,
      }, 202)
    rescue ArgumentError => error
      json_response({ "error" => error.message }, 400)
    end
  end

  post "/search" do
    begin
      payload = request_json
      query = required_string(payload, "query", MAX_QUERY_BYTES)
      sources = search_documents(query, top_k(payload)).map { |match| source_from_match(match) }
      json_response({ "query" => query, "sources" => sources })
    rescue ArgumentError => error
      p "ArgumentError: #{error.message}"
      json_response({ "error" => error.message }, 400)
    rescue => error
      p "Error: #{error.message}"
      json_response({ "error" => error.message }, 500)
    end
  end

  post "/rag" do
    begin
      payload = request_json
      question = required_string(payload, "question", MAX_QUERY_BYTES)
      matches = search_documents(question, top_k(payload))

      descriptor = cloudflare.AI.generate(GENERATION_MODEL, {
        "messages" => [
          {
            "role" => "system",
            "content" => "Answer using only the supplied context. If the context does not contain the answer, say that you do not know. Cite sources as [1], [2], and so on.",
          },
          {
            "role" => "user",
            "content" => "Context:\n#{context_from_matches(matches)}\n\nQuestion:\n#{question}",
          },
        ],
        "stream" => true,
      })
      cloudflare_hijack(descriptor)
    rescue ArgumentError => error
      json_response({ "error" => error.message }, 400)
    end
  end

  post "/api/clef" do
    begin
      payload = request_json
      state = required_string(payload, "state", MAX_CLEF_STATE_BYTES)
      raise ArgumentError, "state must not be blank" if state.strip.empty?

      result = cloudflare.AI.run("@cf/cloudflare/clef", {
        "model" => "clef",
        "state" => state,
        "questions" => {
          "urgent" => {
            "type" => "noul",
            "instructions" => "Is this support request urgent?",
          },
          "team" => {
            "type" => "choice",
            "instructions" => "Which team should handle this request?",
            "criteria" => {
              "billing" => "Payments, invoices, and refunds",
              "technical" => "Outages, errors, and configuration",
              "sales" => "Plans and upgrades",
            },
          },
          "severity" => {
            "type" => "score",
            "instructions" => "How severe is the customer impact?",
            "criteria" => ["No impact", "Minor", "Major", "Critical"],
          },
        },
      })

      json_response(result)
    rescue ArgumentError => error
      json_response({ "error" => error.message }, 400)
    rescue => error
      p "Clef inference error: #{error.message}"
      json_response({ "error" => "Clef inference failed" }, 502)
    end
  end
end

Rackup::Handler::CloudflareWorker.run(App)

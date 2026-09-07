require 'net/http'
require 'digest'

# Reads only the existing LK Flagship inbox. Credentials never leave the server.
class DeskChatwootSource
  class Denied < StandardError; end
  class Unavailable < StandardError; end

  def initialize(local_account_id)
    @local_account_id = local_account_id
  end

  def read(path, query = {})
    raise Denied unless path.match?(%r{\A(?:inboxes(?:/3)?|conversations(?:/(?:search|meta|\d+(?:/(?:messages|attachments|labels))?))?)\z})

    conversation = scoped_conversation(path)
    return adapt(conversation) if conversation && path.match?(%r{\Aconversations/\d+\z})

    allowed = query.slice('page', 'before', 'after', 'q', 'status', 'assignee_type', 'sort_by')
    allowed['inbox_id'] = '3' if %w[conversations conversations/search conversations/meta].include?(path)
    result = get(path, allowed)
    result = filter_inbox_response(path, result)
    adapt(result)
  end

  def send_message(path, params)
    raise Denied unless path.match?(%r{\Aconversations/\d+/messages\z})

    conversation = scoped_conversation(path)
    request_id = params['echo_id']
    validate_content!(params)
    files = validate_files!(params)
    fingerprint = Digest::SHA256.hexdigest(JSON.generate([params['content'], params['is_voice_message'].to_s, files.map do |file|
      file_fingerprint(file)
    end]))
    reconcile(conversation['id'])
    DeskSourceAttempt.deliver(account_id: @local_account_id, conversation_id: conversation['id'],
                              request_id: request_id, fingerprint: fingerprint) do
      adapt(post_message(path, params, files))
    end
  rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError, OpenSSL::SSL::SSLError
    raise DeskSourceAttempt::Pending
  end

  def reconcile(conversation_id)
    pending = DeskSourceAttempt.where(account_id: @local_account_id, conversation_id: conversation_id, response: nil)
    return unless pending.exists?

    # ponytail: scans the most recent page; older uncertain sends stay blocked for manual reconciliation.
    messages = get("conversations/#{conversation_id}/messages").fetch('payload')
    pending.each do |attempt|
      message = messages.find { |item| item.dig('content_attributes', 'desk_request_id') == attempt.request_id }
      attempt.update!(response: adapt(message).merge('echo_id' => attempt.request_id)) if message
    end
  end

  private

  def validate_content!(params)
    id = params['echo_id']
    content = params['content']
    raise Denied unless id.is_a?(String) && id.match?(/\A[a-zA-Z0-9_-]{1,100}\z/)
    raise Denied unless content.nil? || (content.is_a?(String) && content.length <= 10_000)
    raise Denied if params['private'].in?([true, 'true'])
  end

  def validate_files!(params)
    files = Array(params['attachments'])
    raise Denied if params['content'].to_s.empty? && files.empty?
    raise Denied if files.size > 5
    raise Denied unless files.all?(ActionDispatch::Http::UploadedFile)
    raise Denied if files.sum(&:size) > 20.megabytes

    files
  end

  def file_fingerprint(file)
    [file.original_filename, file.content_type, Digest::SHA256.file(file.path).hexdigest]
  end

  def post_message(path, params, files)
    uri = URI("https://chat.lkskrs.online/api/v1/accounts/1/#{path}")
    request = Net::HTTP::Post.new(uri)
    request['api_access_token'] = ENV.fetch('DESK_LK_SOURCE_TOKEN')
    body = { content: params['content'], message_type: 'outgoing', private: false,
             echo_id: params['echo_id'], content_attributes: { desk_request_id: params['echo_id'] } }
    if files.empty?
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(body)
    else
      request.set_form(multipart_fields(body, params, files), 'multipart/form-data')
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
      http.max_retries = 0
      http.request(request)
    end
    raise DeskSourceAttempt::Pending unless response.code == '200'

    JSON.parse(response.body)
  end

  def multipart_fields(body, params, files)
    fields = body.map { |key, value| [key.to_s, value.is_a?(Hash) ? JSON.generate(value) : value.to_s] }
    fields << %w[is_voice_message true] if params['is_voice_message'].in?([true, 'true'])
    files.each do |file|
      file.tempfile.rewind
      fields << ['attachments[]', file.tempfile, { filename: file.original_filename, content_type: file.content_type }]
    end
    fields
  end

  def scoped_conversation(path)
    id = path[%r{\Aconversations/(\d+)(?:/|\z)}, 1]
    return unless id

    conversation = get("conversations/#{id}")
    raise Denied unless conversation['inbox_id'] == 3

    conversation
  end

  def get(path, query = {})
    uri = URI("https://chat.lkskrs.online/api/v1/accounts/1/#{path}")
    uri.query = URI.encode_www_form(query) unless query.empty?
    request = Net::HTTP::Get.new(uri)
    request['api_access_token'] = ENV.fetch('DESK_LK_SOURCE_TOKEN')
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
      http.max_retries = 0
      http.request(request)
    end
    raise Unavailable unless response.code == '200'

    JSON.parse(response.body)
  rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError, OpenSSL::SSL::SSLError
    raise Unavailable
  end

  def filter_inbox_response(path, result)
    case path
    when 'inboxes'
      result['payload'] = result.fetch('payload').select { |inbox| inbox['id'] == 3 }.map { |inbox| public_inbox(inbox) }
      result
    when 'inboxes/3' then public_inbox(result)
    else result
    end
  end

  def public_inbox(inbox)
    inbox.slice('id', 'name', 'avatar_url', 'channel_type', 'channel_id', 'phone_number', 'allow_messages_after_resolved')
  end

  def adapt_hash(value)
    value.reject { |key, _| key.match?(/token|password|secret|api_key|webhook_url/i) }.transform_values { |item| adapt(item) }.tap do |item|
      item['account_id'] = @local_account_id if item['account_id'] == 1
      if item.key?('inbox_id') || item.key?('channel_type')
        item['desk_source'] = true
        item['desk_read_only'] = ENV['DESK_LK_SOURCE_SEND_ENABLED'] != 'true'
      end
    end
  end

  def adapt(value)
    case value
    when Array then value.map { |item| adapt(item) }
    when Hash then adapt_hash(value)
    else value
    end
  end
end

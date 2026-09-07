require 'net/http'

# Reads only the existing LK Flagship inbox. Credentials never leave the server.
class DeskChatwootSource
  class Denied < StandardError; end
  class Unavailable < StandardError; end

  def initialize(local_account_id)
    @local_account_id = local_account_id
  end

  def read(path, query = {})
    raise Denied unless path.match?(%r{\A(?:inboxes(?:/3)?|conversations(?:/(?:search|meta|\d+(?:/(?:messages|attachments|labels))?))?)\z})

    if path.start_with?('conversations/') && (id = path.split('/')[1]).match?(/\A\d+\z/)
      conversation = get("conversations/#{id}")
      raise Denied unless conversation['inbox_id'] == 3
      return adapt(conversation) if path == "conversations/#{id}"
    end

    allowed = query.slice('page', 'before', 'after', 'q', 'status', 'assignee_type', 'sort_by')
    allowed['inbox_id'] = '3' if %w[conversations conversations/search conversations/meta].include?(path)
    result = get(path, allowed)
    if path == 'inboxes'
      result['payload'] = result.fetch('payload').select { |inbox| inbox['id'] == 3 }.map { |inbox| public_inbox(inbox) }
    elsif path == 'inboxes/3'
      result = public_inbox(result)
    end
    adapt(result)
  end

  private

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

  def public_inbox(inbox)
    inbox.slice('id', 'name', 'avatar_url', 'channel_type', 'channel_id', 'phone_number', 'allow_messages_after_resolved')
  end

  def adapt(value)
    case value
    when Array then value.map { |item| adapt(item) }
    when Hash
      value.reject { |key, _| key.match?(/token|password|secret|api_key|webhook_url/i) }.transform_values { |item| adapt(item) }.tap do |item|
        item['account_id'] = @local_account_id if item['account_id'] == 1
        item['desk_read_only'] = true if item.key?('inbox_id') || item.key?('channel_type')
      end
    else value
    end
  end
end

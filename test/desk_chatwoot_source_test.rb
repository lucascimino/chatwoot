require 'minitest/autorun'
require 'json'
require_relative '../app/services/desk_chatwoot_source'

class DeskChatwootSourceTest < Minitest::Test
  def setup
    @calls = []
    @source = DeskChatwootSource.new(2)
    calls = @calls
    @source.define_singleton_method(:get) do |path, query = {}|
      calls << [path, query]
      case path
      when 'inboxes' then { 'payload' => [{ 'id' => 3, 'channel_type' => 'Channel::Api', 'hmac_token' => 'must-not-leave-server' }, { 'id' => 2 }] }
      when 'conversations/10' then { 'account_id' => 1, 'inbox_id' => 3, 'id' => 10 }
      when 'conversations/11' then { 'account_id' => 1, 'inbox_id' => 2, 'id' => 11 }
      else { 'payload' => [] }
      end
    end
  end

  def test_inbox_scope_and_query_override
    assert_not @source.read('inboxes')['payload'].first.key?('hmac_token')
    assert_equal([3], @source.read('inboxes')['payload'].map { |i| i['id'] })
    @source.read('conversations', { 'inbox_id' => '2', 'account_id' => '9', 'page' => '2' })
    assert_equal({ 'inbox_id' => '3', 'page' => '2' }, @calls.last[1])
  end

  def test_conversation_scope_before_message_read
    assert_raises(DeskChatwootSource::Denied) { @source.read('conversations/11/messages') }
    assert_equal [['conversations/11', {}]], @calls
    result = @source.read('conversations/10')
    assert_equal 2, result['account_id']
    assert result['desk_read_only']
  end

  def test_sending_flag_reaches_both_inbox_and_conversation
    previous = ENV.fetch('DESK_LK_SOURCE_SEND_ENABLED', nil)
    ENV['DESK_LK_SOURCE_SEND_ENABLED'] = 'true'
    inbox = @source.read('inboxes')['payload'].first
    assert inbox['desk_source']
    assert_not inbox['desk_read_only']
    conversation = @source.read('conversations/10')
    assert conversation['desk_source']
    assert_not conversation['desk_read_only']
  ensure
    ENV['DESK_LK_SOURCE_SEND_ENABLED'] = previous
  end

  def test_arbitrary_paths_are_denied_without_request
    %w[../users inboxes/2 conversations/10/transcript conversations/10/../11/messages].each do |path|
      assert_raises(DeskChatwootSource::Denied) { @source.read(path) }
    end
    assert_empty @calls
  end
end

require 'minitest/autorun'
require 'active_record'
require 'securerandom'

schema = "desk_attempt_test_#{SecureRandom.hex(6)}"
ActiveRecord::Base.establish_connection(adapter: 'postgresql', host: '127.0.0.1', port: 55_439,
                                        database: 'chatwoot_messenger_preview', username: 'lc', pool: 5)
ActiveRecord::Base.connection.execute("CREATE SCHEMA #{schema}")
ActiveRecord::Base.establish_connection(adapter: 'postgresql', host: '127.0.0.1', port: 55_439,
                                        database: 'chatwoot_messenger_preview', username: 'lc', pool: 5, schema_search_path: schema)
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
require_relative '../app/models/desk_source_attempt'
require_relative '../db/migrate/20260907200000_create_desk_source_attempts'
ActiveRecord::Base.connection.create_table(:accounts)
ActiveRecord::Base.connection.execute('INSERT INTO accounts(id) VALUES (2)')
CreateDeskSourceAttempts.new.migrate(:up)
Minitest.after_run { ActiveRecord::Base.connection.execute("DROP SCHEMA #{schema} CASCADE") }

class DeskSourceAttemptTest < Minitest::Test
  def setup
    DeskSourceAttempt.delete_all
    @args = { account_id: 2, conversation_id: 123, request_id: 'request-1', fingerprint: 'digest' }
  end

  def test_success_is_reused_without_sending_twice
    calls = 0
    2.times do
      assert_equal({ 'id' => 1 }, DeskSourceAttempt.deliver(**@args) do
        calls += 1
        { 'id' => 1 }
      end)
    end
    assert_equal 1, calls
    assert_raises(DeskSourceAttempt::Pending) { DeskSourceAttempt.deliver(**@args, fingerprint: 'different') { flunk } }
  end

  def test_uncertain_result_survives_exception_and_blocks_new_key
    assert_raises(IOError) { DeskSourceAttempt.deliver(**@args) { raise IOError } }
    assert_nil DeskSourceAttempt.first.response
    assert_raises(DeskSourceAttempt::Pending) { DeskSourceAttempt.deliver(**@args) { flunk } }
    assert_raises(DeskSourceAttempt::Pending) { DeskSourceAttempt.deliver(**@args, request_id: 'request-2') { flunk } }
  end

  def test_concurrent_call_cannot_send_while_first_is_pending
    entered = Queue.new
    finish = Queue.new
    thread = Thread.new do
      DeskSourceAttempt.deliver(**@args) do
        entered << true
        finish.pop
        { 'id' => 1 }
      end
    end
    entered.pop
    assert_raises(DeskSourceAttempt::Pending) { DeskSourceAttempt.deliver(**@args) { flunk } }
    finish << true
    thread.value
    assert_equal 1, DeskSourceAttempt.count
  end
end

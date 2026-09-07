class DeskSourceAttempt < ApplicationRecord
  class Pending < StandardError; end

  def self.deliver(account_id:, conversation_id:, request_id:, fingerprint:)
    connection_pool.with_connection do |connection|
      # ponytail: one database connection per send; move to jobs if send concurrency grows.
      locked = connection.select_value("SELECT pg_try_advisory_lock(48192, #{Integer(conversation_id)})")
      raise Pending unless locked

      begin
        attempts = where(account_id: account_id, conversation_id: conversation_id)
        previous = where(account_id: account_id).find_by(request_id: request_id)
        if previous
          raise Pending unless previous.conversation_id == conversation_id && previous.fingerprint == fingerprint && previous.response.present?

          return previous.response
        end
        raise Pending if attempts.exists?(response: nil)

        attempt = create!(account_id: account_id, conversation_id: conversation_id, request_id: request_id, fingerprint: fingerprint)
        response = yield
        attempt.update!(response: response)
        response
      ensure
        connection.execute("SELECT pg_advisory_unlock(48192, #{Integer(conversation_id)})")
      end
    end
  end
end

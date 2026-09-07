module DeskChatwootSourceConcern
  extend ActiveSupport::Concern

  included do
    before_action :read_desk_chatwoot_source
  end

  private

  def read_desk_chatwoot_source
    return unless Current.account.id.to_s == ENV['DESK_LK_SOURCE_ACCOUNT_ID']
    return head :forbidden unless current_user&.id.to_s == ENV['DESK_LK_SOURCE_OWNER_ID']
    return head :method_not_allowed unless source_method_allowed?

    path = request.path.delete_prefix("/api/v1/accounts/#{Current.account.id}/")
    return if path.match?(%r{\A(?:labels|teams|agents|custom_attribute_definitions|custom_filters|canned_responses|notifications)(?:/|\z)})

    render_desk_source(path)
  end

  def source_method_allowed?
    request.get? || (request.post? && ENV['DESK_LK_SOURCE_SEND_ENABLED'] == 'true')
  end

  def render_desk_source(path)
    response.headers['Cache-Control'] = 'no-store'
    source = DeskChatwootSource.new(Current.account.id)
    result = request.get? ? source.read(path, request.query_parameters) : source.send_message(path, request.request_parameters)
    render json: result
  rescue DeskSourceAttempt::Pending
    render json: { error: 'Envio aguardando confirmação. Não repita a mensagem; atualize para conferir o resultado.' }, status: :conflict
  rescue DeskChatwootSource::Denied
    head :forbidden
  rescue DeskChatwootSource::Unavailable
    render json: { error: 'Chatwoot source temporarily unavailable' }, status: :bad_gateway
  end
end

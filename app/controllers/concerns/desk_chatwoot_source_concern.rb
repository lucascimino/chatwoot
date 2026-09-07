module DeskChatwootSourceConcern
  extend ActiveSupport::Concern

  included do
    before_action :read_desk_chatwoot_source
  end

  private

  def read_desk_chatwoot_source
    return unless Current.account.id.to_s == ENV['DESK_LK_SOURCE_ACCOUNT_ID']
    return head :forbidden unless current_user&.id.to_s == ENV['DESK_LK_SOURCE_OWNER_ID']
    return head :method_not_allowed unless request.get?

    path = request.path.delete_prefix("/api/v1/accounts/#{Current.account.id}/")
    return if path.match?(%r{\A(?:labels|teams|agents|custom_attribute_definitions|custom_filters|canned_responses|notifications)(?:/|\z)})

    response.headers['Cache-Control'] = 'no-store'
    render json: DeskChatwootSource.new(Current.account.id).read(path, request.query_parameters)
  rescue DeskChatwootSource::Denied
    head :forbidden
  rescue DeskChatwootSource::Unavailable
    render json: { error: 'Chatwoot source temporarily unavailable' }, status: :bad_gateway
  end
end

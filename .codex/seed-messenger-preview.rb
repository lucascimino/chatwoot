# Synthetic data only. Never run against a shared or production database.
config = ActiveRecord::Base.connection_db_config.configuration_hash
abort 'Preview database required' unless Rails.env.development? && config[:host] == '127.0.0.1' && config[:database] == 'chatwoot_messenger_preview'
ConfigLoader.new.process
account = Account.find_or_create_by!(name: 'Demonstração Messenger')
account.update!(locale: 'pt_BR')
user = User.find_or_initialize_by(email: 'demo@example.test')
user.assign_attributes(name: 'Demonstração', password: ENV.fetch('MESSENGER_PREVIEW_PASSWORD'))
user.skip_confirmation!
user.save!
AccountUser.find_or_create_by!(account: account, user: user) { |membership| membership.role = :administrator }
['Pessoal', 'LK Flagship', 'LK Compras', 'SPITI', 'Zipper', 'Claw'].each_with_index do |name, index|
  next if account.inboxes.exists?(name: name)
  channel = Channel::Api.create!(account: account)
  inbox = Inbox.create!(account: account, channel: channel, name: name)
  InboxMember.create!(inbox: inbox, user: user)
  6.times do |position|
    link = ContactInboxWithContactBuilder.new(source_id: "preview-#{index}-#{position}", inbox: inbox, hmac_verified: true,
      contact_attributes: { name: "Contato de exemplo #{position + 1}" }).perform
    conversation = Conversation.create!(account: account, inbox: inbox, contact: link.contact, contact_inbox: link, status: :open)
    Message.create!(account: account, inbox: inbox, conversation: conversation, sender: link.contact,
      message_type: :incoming, content: 'Olá! Esta conversa contém apenas dados fictícios para avaliar o novo layout.')
    Message.create!(account: account, inbox: inbox, conversation: conversation, sender: user,
      message_type: :outgoing, content: 'Aqui usamos o histórico e os componentes nativos do Chatwoot.')
  end
end
puts 'Preview fixtures ready'

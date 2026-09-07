class CreateDeskSourceAttempts < ActiveRecord::Migration[7.1]
  def change
    create_table :desk_source_attempts do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :conversation_id, null: false
      t.string :request_id, null: false
      t.string :fingerprint, null: false
      t.jsonb :response
      t.timestamps
    end
    add_index :desk_source_attempts, [:account_id, :request_id], unique: true
    add_index :desk_source_attempts, [:account_id, :conversation_id], where: 'response IS NULL', name: 'desk_source_pending'
  end
end

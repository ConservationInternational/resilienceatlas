# frozen_string_literal: true

class CreateAiChatMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_chat_messages do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string     :bedrock_session_id, null: false
      t.string     :role,               null: false   # 'user' | 'agent'
      t.text       :content,            null: false

      t.timestamps
    end

    add_index :ai_chat_messages, [:admin_user_id, :created_at]
    add_index :ai_chat_messages, :bedrock_session_id
  end
end

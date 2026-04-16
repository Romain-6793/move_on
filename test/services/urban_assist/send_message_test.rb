# frozen_string_literal: true

require "test_helper"

module UrbanAssist
  class SendMessageTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(
        email: "urban-assist-test@example.com",
        password: "password123",
        password_confirmation: "password123",
        firstname: "Test",
        lastname: "User",
        date_of_birth: Date.new(1990, 1, 1),
        situation: "working"
      )
      @session = {}
      @chat = @user.chats.create!(title: "Test")
    end

    test "persiste un message assistant quand RubyLLM répond" do
      fake_llm = Object.new
      fake_llm.define_singleton_method(:with_tools) { |_t| self }
      fake_llm.define_singleton_method(:with_temperature) { |_x| self }
      fake_llm.define_singleton_method(:with_instructions) { |_x| self }
      fake_llm.define_singleton_method(:add_message) { |_m| nil }
      fake_llm.define_singleton_method(:ask) do |_q|
        Struct.new(:content, :tool_calls).new("Réponse test", [])
      end

      previous = SendMessage.llm_chat_entry_override
      SendMessage.llm_chat_entry_override = -> { fake_llm }
      result = SendMessage.new(
        user: @user,
        session: @session,
        content: "Bonjour",
        chat: @chat
      ).call

      assert result.success
      assert_equal "assistant", result.assistant_message.role
      assert_includes result.assistant_message.content, "Réponse"
      assert_equal @chat.id, @session[SendMessage::SESSION_CHAT_KEY]
    ensure
      SendMessage.llm_chat_entry_override = previous
    end

    test "refuse un contenu vide" do
      result = SendMessage.new(user: @user, session: @session, content: "   ", chat: @chat).call
      assert_not result.success
      assert_equal :blank_content, result.error
    end
  end
end

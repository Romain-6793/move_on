# frozen_string_literal: true

require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "msg-ctrl@example.com",
      password: "password123",
      password_confirmation: "password123",
      firstname: "Ctrl",
      lastname: "Test",
      date_of_birth: Date.new(1988, 6, 6),
      situation: "working"
    )
  end

  test "refuse si non connecté" do
    post messages_path(format: :json),
         params: { message: { content: "Hello" } },
         as: :json
    assert_response :unauthorized
  end

  test "répond JSON quand connecté (LLM stubbé)" do
    fake_llm = Object.new
    fake_llm.define_singleton_method(:with_tools) { |_t| self }
    fake_llm.define_singleton_method(:with_temperature) { |_x| self }
    fake_llm.define_singleton_method(:with_instructions) { |_x| self }
    fake_llm.define_singleton_method(:add_message) { |_m| nil }
    fake_llm.define_singleton_method(:ask) { |_q| Struct.new(:content, :tool_calls).new("OK bot", []) }

    sign_in @user

    previous = UrbanAssist::SendMessage.llm_chat_entry_override
    UrbanAssist::SendMessage.llm_chat_entry_override = -> { fake_llm }
    post messages_path(format: :json),
         params: { message: { content: "Question test" } },
         as: :json
    UrbanAssist::SendMessage.llm_chat_entry_override = previous

    assert_response :success
    body = JSON.parse(response.body)
    assert body["ok"]
    assert body["chat_id"]
    assert_equal "user", body["user_message"]["role"]
    assert_equal "assistant", body["assistant_message"]["role"]
  end
end

# frozen_string_literal: true

require "test_helper"

class MessagePolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "policy-msg@example.com",
      password: "password123",
      password_confirmation: "password123",
      firstname: "Pol",
      lastname: "Icy",
      date_of_birth: Date.new(1991, 2, 2),
      situation: "family"
    )
    @other = User.create!(
      email: "policy-other@example.com",
      password: "password123",
      password_confirmation: "password123",
      firstname: "Oth",
      lastname: "Er",
      date_of_birth: Date.new(1992, 3, 3),
      situation: "student"
    )
    @own_chat = @user.chats.create!(title: "OK")
    @foreign_chat = @other.chats.create!(title: "No")
  end

  test "create? autorise le propriétaire du chat" do
    assert MessagePolicy.new(@user, @own_chat).create?
  end

  test "create? refuse le chat d'un autre utilisateur" do
    assert_not MessagePolicy.new(@user, @foreign_chat).create?
  end
end

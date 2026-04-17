# frozen_string_literal: true

# Configuration du client LLM (Azure OpenAI / endpoint compatible OpenAI).
# Les secrets ne sont jamais versionnés : ENV en dev, credentials en prod si besoin.
RubyLLM.configure do |config|
  api_key = ENV["OPENAI_API_KEY"].presence ||
            Rails.application.credentials.dig(:openai, :api_key)
  config.openai_api_key = api_key if api_key.present?

  api_base = ENV["OPENAI_API_BASE"].presence ||
             Rails.application.credentials.dig(:openai, :api_base)
  config.openai_api_base = api_base if api_base.present?
end

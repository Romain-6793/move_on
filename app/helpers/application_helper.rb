module ApplicationHelper
  # Rendu markdown pour les réponses du chatbot (Redcarpet + filtrage HTML).
  def markdown(text)
    return "" if text.blank?

    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank", noopener: true, noreferrer: true }
    }
    extensions = {
      autolink: true,
      superscript: true,
      fenced_code_blocks: true
    }
    renderer = Redcarpet::Render::HTML.new(options)
    markdown_engine = Redcarpet::Markdown.new(renderer, extensions)
    markdown_engine.render(text).html_safe
  end
end

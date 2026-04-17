# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)

# pdf.scss est un stylesheet autonome dédié à l'export WickedPDF.
# Il ne doit pas être importé dans application.scss pour ne pas alourdir
# le bundle principal — on le précompile ici pour qu'il soit accessible
# via wicked_pdf_stylesheet_link_tag "pdf" dans le layout PDF.
Rails.application.config.assets.precompile += %w(pdf.css)

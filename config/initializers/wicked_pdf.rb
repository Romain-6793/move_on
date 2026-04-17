# frozen_string_literal: true

# WickedPDF orchestre la conversion de vues HTML/ERB en fichiers PDF via wkhtmltopdf,
# un moteur de rendu basé sur WebKit (même moteur que Safari).
#
# Le gem wkhtmltopdf-binary fournit le binaire natif pour Linux/Mac/Windows,
# ce qui évite d'avoir à l'installer manuellement sur chaque environnement.
#
# Les options de rendu (page_size, marges, layout…) sont passées directement
# dans le `render pdf:` de chaque action contrôleur, pas ici.
# WickedPdf.configure (nouveau bloc) remplace l'ancienne syntaxe WickedPdf.config=
# supprimée dans WickedPDF 2.x. Le bloc vide suffit : wkhtmltopdf-binary
# configure automatiquement exe_path via son propre hook d'initialisation.
WickedPdf.configure do |config|
  # exe_path est résolu automatiquement par wkhtmltopdf-binary.
  # À surcharger uniquement si on veut pointer vers un binaire système personnalisé.
  # config.exe_path = '/usr/local/bin/wkhtmltopdf'
end

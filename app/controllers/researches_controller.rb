# open-uri permet d'ouvrir une URL distante comme un fichier local (URI.open).
# Il gère les redirections HTTP automatiquement, ce qui est indispensable
# pour Wikimedia Commons (les URLs redirigent souvent vers le vrai fichier image).
require 'open-uri'

class ResearchesController < ApplicationController
  # Les actions new et create ont été déplacées dans SearchStepsController
  # qui gère le wizard multi-étapes (gem wicked). ResearchesController ne gère
  # plus que la consultation, la modification et la suppression des recherches existantes.

  def show
    @research = Research.find(params[:id])
    authorize @research

    # CityRankerService calcule un score composite pour chaque ville selon les
    # critères et les filtres géographiques de la recherche, puis retourne les 5
    # meilleures en SQL (sans tout charger en mémoire Ruby).
    @ranked_cities = CityRankerService.new(@research).top_cities

    # Même logique que dans GuestSearchesController : les images sont récupérées
    # une seule fois par ville et mises en cache dans la colonne image_url.
    @ranked_cities.each { |city| CityImageFetcherService.new(city).call }
  end

  def edit
    # On retrouve la recherche par son id et on vérifie que l'utilisateur connecté
    # en est bien le propriétaire (Pundit → ResearchPolicy#edit?).
    @research = Research.find(params[:id])
    authorize @research
  end

  def update
    @research = Research.find(params[:id])
    authorize @research

    if @research.update(research_params)
      redirect_to research_path(@research), notice: "Recherche mise à jour"
    else
      # status: :unprocessable_entity est la convention Rails 7 pour signaler
      # à Turbo que la réponse est une erreur de validation (ne remplace pas l'URL).
      render :edit, status: :unprocessable_entity
    end
  end

  def export_pdf
    @research = Research.find(params[:id])

    # Pundit délègue à ResearchPolicy#export_pdf? → vérifie que l'utilisateur
    # est bien le propriétaire de cette recherche avant de générer le PDF.
    authorize @research

    # On réutilise exactement la même logique que show : calcul des scores
    # et récupération des images (avec cache en base via image_url).
    @ranked_cities = CityRankerService.new(@research).top_cities
    @ranked_cities.each { |city| CityImageFetcherService.new(city).call }

    # ── Images des villes encodées en base64 ────────────────────────────────
    # Problème : wkhtmltopdf doit faire des requêtes HTTP sortantes pour charger
    # les images Wikimedia. En WSL2 / environnements restreints, ces requêtes
    # échouent silencieusement (timeout, User-Agent bloqué, certificat non reconnu).
    #
    # Solution : on télécharge chaque image côté Rails (en RAM, pas sur disque),
    # on l'encode en base64 et on la passe au template comme data URI.
    # wkhtmltopdf reçoit alors le contenu inline dans le HTML → aucune requête HTTP.
    #
    # each_with_object construit un Hash { city.id => "data:image/jpeg;base64,..." }
    # directement pendant l'itération, sans variable temporaire intermédiaire.
    @city_image_data_uris = @ranked_cities.each_with_object({}) do |city, hash|
      next unless city.image_url.present?

      hash[city.id] = fetch_image_as_data_uri(city.image_url)
    end

    # ── Logo encodé depuis le disque ────────────────────────────────────────
    # wicked_pdf_image_tag génère un chemin file:// que wkhtmltopdf tente de lire,
    # mais son WebKit embarqué (version ~2012) rend les SVG de façon aléatoire.
    # On lit le SVG directement depuis le disque Rails et on l'inline en base64 :
    # le moteur reçoit les octets dans le HTML, plus de dépendance au système de fichiers.
    logo_path = Rails.root.join('app', 'assets', 'images', 'square_logo.png')
    logo_raw  = File.binread(logo_path)
    # MIME type image/png : doit correspondre au format réel du fichier.
    # Un mismatch (ex: image/svg+xml pour un PNG) empêche wkhtmltopdf de décoder l'image.
    @logo_data_uri = "data:image/png;base64,#{Base64.strict_encode64(logo_raw)}"

    # render pdf: déclenche WickedPDF : il rend la vue en HTML puis appelle
    # wkhtmltopdf pour convertir ce HTML en fichier PDF téléchargeable.
    #
    # Options notables :
    #   - disposition: 'attachment' → force le téléchargement (pas l'affichage dans le navigateur)
    #   - page_size: 'A4'          → format européen standard
    #   - encoding: 'UTF-8'        → indispensable pour les accents et caractères spéciaux
    #   - margin                   → marges en millimètres
    render pdf:         @research.research_name.parameterize(separator: '_'),
           layout:      'pdf',
           template:    'researches/export_pdf',
           disposition: 'attachment',
           page_size:   'A4',
           encoding:    'UTF-8',
           margin:      { top: 10, bottom: 10, left: 12, right: 12 }
  end

  def destroy
    @research = Research.find(params[:id])
    authorize @research
    @research.destroy

    # Après suppression on renvoie l'utilisateur sur son profil
    # plutôt que sur researches#index (qui n'existe pas).
    # profile_user_path est le helper généré par la route member `get 'profile'`
    # définie dans resources :users (config/routes.rb).
    redirect_to profile_user_path(current_user), notice: "Recherche supprimée"
  end

  private

  # Télécharge une image distante et la retourne sous forme de data URI base64.
  #
  # Pourquoi une méthode privée dédiée ?
  #   → Responsabilité unique : cette méthode ne fait qu'une chose.
  #   → Testable indépendamment de l'action export_pdf.
  #   → Le rescue isole les erreurs réseau sans planter toute l'action PDF.
  #
  # URI.open (open-uri) suit automatiquement les redirections HTTP/HTTPS,
  # ce qui est indispensable pour Wikimedia Commons.
  # Le User-Agent identifie l'application : certains CDN bloquent les requêtes
  # sans User-Agent ou avec un User-Agent de bot générique.
  #
  # Retourne une String "data:<mime>;base64,<données>" ou nil si erreur.
  def fetch_image_as_data_uri(url)
    io   = URI.open(url, 'User-Agent' => 'MoveOnApp/1.0', read_timeout: 10)
    raw  = io.read
    # content_type est fourni par open-uri depuis l'en-tête Content-Type HTTP.
    # presence || 'image/jpeg' évite un nil si l'en-tête est absent.
    mime = io.content_type.presence || 'image/jpeg'
    "data:#{mime};base64,#{Base64.strict_encode64(raw)}"
  rescue OpenURI::HTTPError, Net::ReadTimeout, SocketError => e
    # On logue l'échec mais on ne plante pas : la ville s'affichera sans photo.
    Rails.logger.warn "[PDF Export] Image non chargée (#{url}) : #{e.message}"
    nil
  end

  # Strong Parameters : on liste explicitement chaque champ autorisé.
  # Les critères sont des integers (0/1/2/3), les filtres géographiques des booléens.
  # On n'autorise JAMAIS user_id ici : il est assigné via current_user.researches.build.
  def research_params
    rp = params.require(:research).permit(
      :research_name,
      :coast, :mountain, :no_filters, :density,
      :real_estate, :transport_network, :cultural_heritage,
      :health, :commercial_life, :leisures_and_sports, :education, :education_levels
    )

    # Convertit le JSON string → Array Ruby
    if rp[:education_levels].present?
      rp[:education_levels] = JSON.parse(rp[:education_levels])
    end

    rp
  end


end

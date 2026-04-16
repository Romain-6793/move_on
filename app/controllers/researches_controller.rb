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

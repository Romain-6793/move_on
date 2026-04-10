class ResearchesController < ApplicationController

  def new
    # On instancie un Research vide pour que form_with puisse construire le formulaire.
    # Rails utilise cet objet pour déduire l'URL (POST /researches) et pré-remplir les champs.
    @research = Research.new
    authorize @research
  end

  def create
    # On construit la recherche associée à l'utilisateur connecté (current_user fourni par Devise).
    # build est équivalent à Research.new(research_params.merge(user: current_user))
    # mais passe par l'association, ce qui est plus idiomatique Rails.
    @research = current_user.researches.build(research_params)

    # Pundit vérifie que l'utilisateur a le droit de créer cette ressource.
    # À placer après le build pour que la policy puisse inspecter l'objet.
    authorize @research

    if @research.save
      redirect_to research_path(@research), notice: "Recherche sauvegardée"
    else
      redirect_to new_research_path, alert: "Impossible de sauvegarder la recherche"
    end
  end

  def show
    @research = Research.find(params[:id])
    authorize @research

    # CityRankerService calcule un score composite pour chaque ville selon les
    # critères et les filtres géographiques de la recherche, puis retourne les 5
    # meilleures en SQL (sans tout charger en mémoire Ruby).
    @ranked_cities = CityRankerService.new(@research).top_cities
  end

  def edit
    
  end

  def update
    
  end

  def destroy
    
  end

  private

  # Strong Parameters : on liste explicitement chaque champ autorisé.
  # Les critères sont des integers (0/1/2/3), les filtres géographiques des booléens.
  # On n'autorise JAMAIS user_id ici : il est assigné via current_user.researches.build.
  def research_params
    params.require(:research).permit(
      :research_name,
      :coast, :mountain, :no_filters, :density,
      :real_estate, :transport_network, :cultural_heritage,
      :health, :commercial_life, :leisures_and_sports
    )
  end


end

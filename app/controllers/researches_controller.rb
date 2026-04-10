class ResearchesController < ApplicationController

  def new
    # On instancie un Research vide pour que form_with puisse construire le formulaire.
    # Rails utilise cet objet pour déduire l'URL (POST /researches) et pré-remplir les champs.
    @research = Research.new
    authorize @research
  end

  def create
    @research = @user.researches.build(research_params)

    # Définir le titre de la recherche si nécessaire (nouvelle recherche ou titre vide)
    # if @research.new_record? || @research.research_name.blank?
    #   @research.research_name = "Some title"
    # end
    
    if @research.save
      redirect_to research_path(@research), notice: "Recherche sauvegardée"
    else
      redirect_to new_research_path(@research), alert: "Impossible de sauvegarder la recherche"
    end
    authorize @research
  end

  def show
    
  end

  def edit
    
  end

  def update
    
  end

  def destroy
    
  end

  private

  def research_params
  end


end

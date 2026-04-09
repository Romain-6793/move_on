class ResearchesController < ApplicationController

  def new
    # On instancie un Research vide pour que form_with puisse construire le formulaire.
    # Rails utilise cet objet pour déduire l'URL (POST /researches) et pré-remplir les champs.
    @research = Research.new
  end

  def create
    
  end

  def show
    
  end

  def edit
    
  end

  def update
    
  end

  def destroy
    
  end
end

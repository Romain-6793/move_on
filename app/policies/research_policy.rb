class ResearchPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  def new?
    create?
  end

  def create?
    true
  end

  def show?
    record.user == user
  end

  def edit?
    update?
  end

  def update?
    record.user == user
  end

  def destroy?
    record.user == user
  end

  # L'export PDF expose les mêmes données que show → même règle d'accès :
  # seul le propriétaire de la recherche peut générer le PDF.
  def export_pdf?
    show?
  end

  # La carte des résultats expose les mêmes 5 villes que la page show →
  # seul le propriétaire peut y accéder.
  def results?
    show?
  end


  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    # def resolve
    #   scope.all
    # end
  end
end

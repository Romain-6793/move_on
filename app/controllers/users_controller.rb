class UsersController < ApplicationController

  def show
  @user = current_user
  authorize @user
  end

  def edit
  @user = current_user
  authorize @user
  end

  def update
  @user = current_user
  authorize @user
  end

  def destroy
  @user = current_user
  authorize @user
  end
end

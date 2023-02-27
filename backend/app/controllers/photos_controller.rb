class PhotosController < ApplicationController
  def create
    @photo = Photo.new(photo_params)
    if @photo.save
      render :show, status: :created
    else
      render json: @photo.errors, status: :unprocessable_entity
    end
  end

  private

  def photo_params
    params.require(:photo).permit(:image)
  end
end

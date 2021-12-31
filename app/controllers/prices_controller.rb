class PricesController < ApplicationController
  before_action :set_, only: %i[ edit update destroy ]

  def new
    @price = Price.new
  end

  def create
    @price = Price.new(price_params)

      if @price.save
        redirect_to Product.find(price_params[:product_id])
        flash[:success] = "price was successfully created"
      else
        render :new, status: :unprocessable_entity
      end
  end

  def edit
  end

  def update
    if @price.update(price_params)
      redirect_to Product.find(price_params[:product_id])
      flash[:success] = "price was successfully updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product = @price.product
    @price.destroy
    redirect_to @product
    flash[:success] = "price was successfully deleted"
  end

  private

    def set_price
      @price = price.find(params[:id])
    end

    def price_params
      params.require(:price).permit(:price, :date_from, :product_id)
    end
end

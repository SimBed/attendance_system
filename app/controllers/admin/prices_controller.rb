class Admin::PricesController < Admin::BaseController
  before_action :set_price, only: [:edit, :update, :destroy]

  def new
    @price = Price.new
    @product = Product.find(params[:product_id])
  end

  def create
    @price = Price.new(price_params)

    if @price.save
      redirect_to admin_product_path(Product.find(price_params[:product_id]))
      flash[:success] = t('.success')
    else
      @product = Product.find(price_params[:product_id])
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @price.update(price_params)
      redirect_to admin_product_path(Product.find(price_params[:product_id]))
      flash[:success] = t('.success')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product = @price.product
    @price.destroy
    redirect_to admin_product_path(@product)
    flash[:success] = t('.success')
  end

  private

  def set_price
    @price = Price.find(params[:id])
  end

  def price_params
    params.require(:price).permit(:name, :price, :date_from, :product_id, :current)
  end
end

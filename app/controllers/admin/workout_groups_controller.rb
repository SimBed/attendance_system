class Admin::WorkoutGroupsController < Admin::BaseController
  skip_before_action :admin_account, only: [:show, :index]
  before_action :partner_or_admin_account, only: [:index]
  before_action :correct_account_or_superadmin, only: [:show]
  before_action :set_workout_group, only: [:show, :edit, :update, :destroy]

  def index
    if logged_in_as?('partner')
      partner_id = current_account.partners.first.id
      # reformat to scope
      @workout_groups = WorkoutGroup.where(partner_id: partner_id).order_by_name
    else
      @workout_groups = WorkoutGroup.order_by_name
    end
  end

  def show
    session[:revenue_period] =
      params[:revenue_period] || session[:revenue_period] || Date.today.beginning_of_month.strftime('%b %Y')
    # prepare attendances by date and workout_group
    # it seemes the format of the date in the where helper can be String or Date class.
    # Earlier I thought it had to be sting and converted with .strftime('%Y-%m-%d') but subsequently found either worked
    start_date = Date.parse(session[:revenue_period])
    end_date = Date.parse(session[:revenue_period]).end_of_month.end_of_day
    attendances_in_period = Attendance.confirmed.by_workout_group(@workout_group.name, start_date, end_date)
    classes_in_period = Wkclass.in_workout_group(@workout_group.name).between(start_date, end_date)
    base_revenue = attendances_in_period.map(&:revenue).inject(0, :+)
    expiry_revenue = @workout_group.expiry_revenue(session[:revenue_period])
    gross_revenue = base_revenue + expiry_revenue
    gst = gross_revenue * (1 - (1 / (1 + @workout_group.gst_rate)))
    net_revenue = gross_revenue - gst
    @fixed_expenses = Expense.by_workout_group(@workout_group.name, start_date, end_date)
    total_fixed_expense = @fixed_expenses.map(&:amount).inject(0, :+)
    @wkclasses_with_instructor_expense = classes_in_period.has_instructor_cost
    total_instructor_expense = @wkclasses_with_instructor_expense.map(&:instructor_cost).inject(0, &:+)
    total_expense = total_fixed_expense + total_instructor_expense
    profit = net_revenue - total_expense
    partner_share = profit * @workout_group.partner_share.to_f / 100
    @revenue = {
      attendance_count: attendances_in_period.size,
      class_count: classes_in_period.size,
      base_revenue: base_revenue,
      expiry_revenue: expiry_revenue,
      gross_revenue: gross_revenue,
      gst: gst,
      net_revenue: net_revenue,
      total_fixed_expense: total_fixed_expense,
      total_instructor_expense: total_instructor_expense,
      total_expense: total_expense,
      profit: profit,
      partner_share: partner_share
    }

    # prepare items for the revenue date select
    # months_logged method defined in application helper
    @months = months_logged
  end

  def new
    @workout_group = WorkoutGroup.new
    @workouts = Workout.all
    @partners = Partner.all.map { |p| [p.first_name, p.id] }
  end

  def edit
    @workouts = Workout.all
    @partners = Partner.all.map { |p| [p.first_name, p.id] }
    @partner = @workout_group.partner
  end

  def create
    # @workout_group = WorkoutGroup.new(name: params[:workout_group][:name], workout_ids: params[:workout_ids])
    @workout_group = WorkoutGroup.new(workout_group_params)
    if @workout_group.save
      redirect_to admin_workout_groups_path
      flash[:success] = 'Workout Group was successfully created.'
    else
      @workouts = Workout.all
      @partners = Partner.all.map { |p| [p.first_name, p.id] }
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @workout_group.update(workout_group_params)
      redirect_to admin_workout_groups_path
      flash[:success] = 'Workout Group was successfully updated.'
    else
      @workouts = Workout.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workout_group.destroy
    redirect_to admin_workout_groups_path
    flash[:success] = 'Workout Group was successfully destroyed.'
  end

  private

  def set_workout_group
    @workout_group = WorkoutGroup.find(params[:id])
  end

  def workout_group_params
    params.require(:workout_group).permit(:name, :partner_id, :partner_share, :gst_applies, :requires_invoice,
                                          workout_ids: [])
  end

  def correct_account_or_superadmin
    unless WorkoutGroup.find(params[:id]).partner.account == current_account || logged_in_as?('superadmin')
      redirect_to login_path
    end
  end

  def partner_or_superadmin_account
    redirect_to login_path unless logged_in_as?('superadmin') || logged_in_as?('partner')
  end

  def partner_or_admin_account
    unless logged_in_as?('admin', 'superadmin') || logged_in_as?('partner')
      redirect_to login_path
      flash[:warning] = 'Forbidden'
    end
  end
end

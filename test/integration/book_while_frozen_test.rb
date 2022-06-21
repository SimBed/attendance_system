require "test_helper"

class BookWhileFrozenTest < ActionDispatch::IntegrationTest
  def setup
    @account_client = accounts(:client_for_unlimited)
    @client = @account_client.clients.first
    @purchase = @client.purchases.last
    @tomorrows_class_early = wkclasses(:wkclass_for_booking_early)
    @tomorrows_class_late = wkclasses(:wkclass_for_booking_late)
    @freeze_start_date = @tomorrows_class_early.start_time.advance(days: -3)
    @freeze_end_date = @tomorrows_class_early.start_time.advance(days: 6)
    @admin = accounts(:admin)
    travel_to(@tomorrows_class_early.start_time.beginning_of_day)
  end

  test 'new booking book while frozen terminates freeze early' do
    log_in_as(@admin)
    assert_equal Date.parse('20 Jun 2022'), @purchase.expiry_date_calc
    # freeze
    assert_difference 'Freeze.count', 1 do
      post admin_freezes_path, params:
       { freeze:
          { purchase_id: @purchase.id,
            start_date: @freeze_start_date,
            end_date: @freeze_end_date } }
    end
    follow_redirect!
    assert_equal Date.parse('30 Jun 2022'), @purchase.reload.expiry_date_calc
    assert_equal 10, @purchase.freezes.last.duration

    # book during freeze
    post admin_attendances_path, params:
     { attendance:
        { wkclass_id: @tomorrows_class_early.id,
          purchase_id: @purchase.id,
          status: 'booked' } }
    assert_equal Date.parse('23 Jun 2022'), @purchase.reload.expiry_date_calc
    assert_equal 3, @purchase.freezes.last.duration
  end

  test 'update booking to booked/attended while frozen terminates freeze early' do
    log_in_as(@admin)
    # book class
    post admin_attendances_path, params:
     { attendance:
        { wkclass_id: @tomorrows_class_early.id,
          purchase_id: @purchase.id,
          status: 'booked' } }
    # freeze
    assert_difference 'Freeze.count', 1 do
      post admin_freezes_path, params:
       { freeze:
          { purchase_id: @purchase.id,
            start_date: @freeze_start_date,
            end_date: @freeze_end_date } }
    end
    follow_redirect!
    # client attends booked class during freeze, attendance updated to attended
    @attendance = Attendance.applicable_to(@tomorrows_class_early, @client)
    assert_difference '@client.attendances.confirmed.no_amnesty.size', 1 do
      patch admin_attendance_path(@attendance), params: { attendance: { id: @attendance.id, status: 'attended' } }
    end
    assert_equal Date.parse('23 Jun 2022'), @purchase.reload.expiry_date_calc
    assert_equal 3, @purchase.freezes.last.duration
  end

  test 'update booking to cancelled while frozen has no affect on freeze' do
    log_in_as(@admin)
    # book class
    post admin_attendances_path, params:
     { attendance:
        { wkclass_id: @tomorrows_class_early.id,
          purchase_id: @purchase.id,
          status: 'booked' } }
    # freeze
    assert_difference 'Freeze.count', 1 do
      post admin_freezes_path, params:
       { freeze:
          { purchase_id: @purchase.id,
            start_date: @freeze_start_date,
            end_date: @freeze_end_date } }
    end
    follow_redirect!
    # cancel class during freeze
    @attendance = Attendance.applicable_to(@tomorrows_class_early, @client)
    assert_difference '@client.attendances.no_amnesty.size', -1 do
      patch admin_attendance_path(@attendance), params: { attendance: { id: @attendance.id, status: 'cancelled early' } }
    end
    assert_equal Date.parse('30 Jun 2022'), @purchase.reload.expiry_date_calc
    assert_equal 10, @purchase.freezes.last.duration
  end
end

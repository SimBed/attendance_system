require 'test_helper'
require 'attendances_helper'

class MalevolentBookingsTest < ActionDispatch::IntegrationTest
  # https://stackoverflow.com/questions/32029654/how-to-make-helper-methods-available-in-a-rails-integration-test
  include AttendancesHelper
  setup do
    @admin = accounts(:admin)
    @account_client = accounts(:client_for_pilates)
    @client = @account_client.clients.first
    # purchase is 8c5w, 6 classes attended, expiry_date 25/3/2022
    @purchase = purchases(:tina8c5wong)
  end

  test 'attempt by client to book class with provisonally expired package should fail' do
    # create 3 new classes
    log_in_as @admin
    assert_difference 'Wkclass.count', 3 do
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-19 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-20 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-21 10:30:00', instructor_id: 3, max_capacity: 6 } }
    end

    travel_to(Date.parse('March 17 2022').beginning_of_day)
    # provisionally expire purchase by booking 2 classes
    assert_difference '@purchase.attendances.count', 2 do
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[0].id,
                                                           purchase_id: @purchase.id } }
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[1].id,
                                                           purchase_id: @purchase.id } }
    end
    assert_equal 'provisionally expired', @purchase.reload.status

    # client attempts to book another class
    log_in_as @account_client
    assert_difference '@purchase.attendances.count', 0 do
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[2].id,
                                                           purchase_id: @purchase.id } }
    end
    assert_redirected_to client_book_path @client
    assert_equal flash[:warning],
                 ['The maximum number of classes has already been booked.',
                  'Renew you Package if you wish to attend this class']
  end

  test 'attempt by client to update class from cancelled early with provisonally expired package should fail' do
    log_in_as @admin
    assert_difference 'Wkclass.count', 3 do
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-19 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-20 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-21 10:30:00', instructor_id: 3, max_capacity: 6 } }
    end

    travel_to(Date.parse('March 17 2022').beginning_of_day)
    # provisionally expire purchase by booking 2 classes
    assert_difference '@purchase.attendances.count', 2 do
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[0].id,
                                                           purchase_id: @purchase.id } }
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[1].id,
                                                           purchase_id: @purchase.id } }
    end

    # cancel last booking
    @attendance = @client.attendances.where(wkclass_id: Wkclass.last(3)[1].id).first
    patch admin_attendance_path(@attendance), params: { attendance: { status: 'cancelled early' } }
    assert_equal 'ongoing', @purchase.reload.status
    # book another one instead
    post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[2].id,
                                                         purchase_id: @purchase.id } }
    assert_equal 'provisionally expired', @purchase.reload.status

    # client attempts to rebook previously cancelled class
    log_in_as @account_client
    @attendance = @client.attendances.where(wkclass_id: Wkclass.last(3)[1].id).first
    assert_difference '@purchase.attendances.count', 0 do
      patch admin_attendance_path(@attendance)
    end
    assert_redirected_to client_book_path @client
    assert_equal flash[:warning],
                 ['The maximum number of classes has already been booked.',
                  'Renew you Package if you wish to attend this class']
  end

  test 'attempt by admin to book class with provisonally expired package should fail' do
    # create 3 new classes
    log_in_as @admin
    assert_difference 'Wkclass.count', 3 do
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-19 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-20 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-21 10:30:00', instructor_id: 3, max_capacity: 6 } }
    end

    travel_to(Date.parse('March 17 2022').beginning_of_day)
    # provisionally expire purchase by booking 2 classes
    assert_difference '@purchase.attendances.count', 2 do
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[0].id,
                                                           purchase_id: @purchase.id } }
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[1].id,
                                                           purchase_id: @purchase.id } }
    end
    assert_equal 'provisionally expired', @purchase.reload.status

    # admin attempts to book another class
    assert_difference '@purchase.attendances.count', 0 do
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[2].id,
                                                           purchase_id: @purchase.id } }
    end
    assert_redirected_to admin_wkclass_path(Wkclass.last(3)[2], no_scroll: true)
    assert_equal flash[:warning], 'The maximum number of classes has already been booked'
  end

  test 'admin should be able to make amendment to booking for provisonally expired package when change wont improve package terms' do
    # create 3 new classes
    log_in_as @admin
    assert_difference 'Wkclass.count', 3 do
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-19 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-20 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-21 10:30:00', instructor_id: 3, max_capacity: 6 } }
    end

    travel_to(Date.parse('March 17 2022').beginning_of_day)
    # provisionally expire purchase by booking 2 classes
    assert_difference '@purchase.attendances.count', 2 do
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[0].id,
                                                           purchase_id: @purchase.id } }
      post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[1].id,
                                                           purchase_id: @purchase.id } }
    end
    # cancel last booking
    @attendance = @client.attendances.where(wkclass_id: Wkclass.last(3)[1].id).first
    patch admin_attendance_path(@attendance), params: { attendance: { status: 'cancelled early' } }
    assert_equal 'ongoing', @purchase.reload.status
    # book another one instead
    post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[2].id,
                                                         purchase_id: @purchase.id } }
    assert_equal 'provisionally expired', @purchase.reload.status

    # admin corrects class incorrecly logged as 'cancelled early' to 'cancelled late' (for which there is amnesty)
    assert_difference '@attendance.reload.amendment_count', 1 do
      patch admin_attendance_path(@attendance), params: { attendance: { status: 'cancelled late' } }
    end
    # assert_redirected_to admin_wkclass_path @attendance.wkclass, {no_scroll: true}
    assert_redirected_to admin_wkclasses_path
    assert_equal flash[:success], 'Attendance was successfully updated'
  end

  test 'admin should not be able to make amendment to booking for provisonally expired package when change will improve package terms' do
    # create 3 new classes
    log_in_as @admin
    assert_difference 'Wkclass.count', 3 do
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-19 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-20 10:30:00', instructor_id: 3, max_capacity: 6 } }
      post admin_wkclasses_path,
           params: { wkclass: { workout_id: 3, start_time: '2022-03-21 10:30:00', instructor_id: 3, max_capacity: 6 } }
    end

    # remove late_cancellation amnesty from purchase
    @purchase.update(late_cancels: amnesty_limit[:cancel_late][@purchase.product_type])

    travel_to(Date.parse('March 17 2022').beginning_of_day)
    # provisionally expire purchase by booking 2 classes
    post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[0].id,
                                                         purchase_id: @purchase.id } }
    post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[1].id,
                                                         purchase_id: @purchase.id } }

    # last booking cancelled late (but incorrectly set to cancelled early)
    @attendance = @client.attendances.where(wkclass_id: Wkclass.last(3)[1].id).first
    patch admin_attendance_path(@attendance), params: { attendance: { status: 'cancelled early' } }
    assert_equal 'ongoing', @purchase.reload.status
    # book another one instead (wouldn't be allowed if previous cancellation logged correctly)
    post admin_attendances_path, params: { attendance: { wkclass_id: Wkclass.last(3)[2].id,
                                                         purchase_id: @purchase.id } }
    assert_equal 'provisionally expired', @purchase.reload.status

    # admin attempts to correct class incorrecly logged as 'cancelled early' to 'cancelled late' (for which there is no amnesty)
    assert_difference '@attendance.reload.amendment_count', 0 do
      patch admin_attendance_path(@attendance), params: { attendance: { status: 'cancelled late' } }
    end
    assert_redirected_to admin_wkclass_path @attendance.wkclass, { no_scroll: true }
    assert_equal flash[:warning],
                 ['The purchase has provisionally expired.',
                  'This change may not be possible without first cancelling a booking']
  end
end

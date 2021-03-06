class AppointmentsController < ApplicationController
  require 'set'

  def create
    return ok_response("Error scheduling an appointment, time slot is unavailable") if unavailable?

    @appointment = Appointment.create!(clean_params)
    success_response("Successfully created appointment", :created)
  rescue StandardError => err
    logger.error("Create apointment failed: #{err}")
    render json: { error: "Appointment not created" }, status: :internal_server_error
  end


  private

  def appointment_params
    params.require(:appointment).permit(:email, :date, :time)
  end

  def success_response(message, status)
    render json: { data: { message: message, appointment: @appointment } }, status: status
  end

  def ok_response(message)
    render json: { data: { message: message } }, status: :ok
  end

  def clean_params
    time_hour, time_minute = time_parse(appointment_params[:time])
    time_slot = date_parse(appointment_params[:date])
    time_slot = time_slot + time_hour.hours
    time_slot = time_slot + time_minute.minutes

    {
      email: appointment_params[:email],
      time_slot: time_slot,
      user_id: appointment_params.fetch(:user_id, nil)
    }
  end

  def date_parse(date)
    # TODO: this can be handled better, but we'll _trust_ our users for now
    Time.parse(date).utc
  rescue StandardError => err
    logger.error("Invalid date format #{err}")
    false
  end

  def time_parse(time)
    # TODO: we would probably want to do better validation than this
    # but this is simple and will get the job done
    hour, minute = time.split(':')

    hour_increment = 0

    if minute.to_i.between?(31, 59)
      hour_increment = 1
      minute = 0
    elsif minute.to_i.between?(1, 29)
      minute = 30
    end

    [hour.to_i + hour_increment, minute.to_i]
  rescue StandardError => err
    logger.error("Invalid time format passed in: #{err}")
    false
  end

  def existing_appointments(email)
    Appointment.where(email: email)
  end

  def unavailable_times(appointments)
    return Set.new if appointments.length.zero?

    Set.new(appointments.map { |appointment| appointment.time_slot.strftime('%Y-%m-%d') } )
  end

  def unavailable?
    appointments = existing_appointments(clean_params[:email])
    target_day = clean_params[:time_slot].strftime('%Y-%m-%d')

    unavailable_times(appointments).include?(target_day)
  end
end

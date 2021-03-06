class AppointmentsController < ApplicationController
  
  def index
      @appointment_list = current_user.future_appointment_list.paginate(:page => params[:page], :per_page => 15) 
  end

  def new
      @appointment = current_user.patient_appointments.build
      @doctors_list = User.get_doctors_list
      @slots = Appointment.get_booked_slots(User.doctor.first.id,(Time.now+1.day).strftime("%Y-%m-%d"))
      authorize! :new, @appointment 
  end

  def create
      @appointment = current_user.patient_appointments.new(appointment_params)
      authorize! :create, @appointment
      @appointment.initialize_note(current_user.id,@appointment.note)
      duration = @appointment.get_appointment_duration(params[:appointment][:start_time])
    
      if @appointment.save
          ExpiredDateWorker.perform_in(@appointment.date + (duration.strftime("%H").to_i + params[:appointment][:start_time].to_i)*60*60,@appointment.id)
          @appointment.image = Image.new(image: params[:appointment][:image])
          flash[:success] = "Appointment Created!"
          redirect_to appointments_path
      else
          time = @appointment.date.present? ? @appointment.date : Time.now+1.day  
          @slots = Appointment.get_booked_slots(@appointment.doctor.id,time.strftime("%Y-%m-%d"))
          @doctors_list = User.get_doctors_list
          render 'new'
      end  
  end

  def update
      @appointment = Appointment.find_by_id params[:id] 
      if @appointment.nil?
        redirect_to root_path
      else 
        authorize! :update, @appointment
        duration = @appointment.get_appointment_duration(params[:appointment][:start_time])
        @appointment.image = Image.new(image:params[:appointment][:image]) 
        new_date = Appointment.get_new_date(params.require(:appointment).permit(:date))

        if params[:appointment][:start_time].nil?
           if @appointment.date.strftime("%Y-%m-%d").to_date != new_date
              @appointment.errors.add('appointment','Select a Appointment Time')
              @slots = Appointment.get_booked_slots(@appointment.doctor.id,@appointment.date)
              render "edit" and return            
           end   
        else
           @appointment.update_attributes(appointment_update_params)
           @appointment.update_worker(params[:appointment][:start_time],duration)
        end
        flash[:success] = "Appointment Updated!"
        redirect_to appointments_path 
      end  
  end

  def destroy
      @appointment = Appointment.find_by_id params[:id]
      if @appointment.nil?
        redirect_to root_path
      else
        authorize! :destroy, @appointment
         if @appointment.cancelled!
           render json: {status:"cancelled"}
         else
           render json: {status: "Apointment not cancelled"}
         end 
      end   
  end

  def show
      @appointment = Appointment.find_by_id params[:id]
      if @appointment.nil?
        redirect_to root_path
      else  
        authorize! :show, @appointment
        @patient = @appointment.patient
        @note = Note.new(user_id: current_user.id,appointment_id: params[:id])
        @notes = @appointment.notes
      end  
  end

  def edit
      @appointment = Appointment.find_by_id params[:id]
      if @appointment.nil?
        redirect_to root_path
      else
        authorize! :edit, @appointment    
        @slots = Appointment.get_booked_slots(@appointment.doctor.id,@appointment.date) 
      end
  end

  def recent
      @appointments = current_user.past_appointment_list.paginate(:page => params[:page], :per_page => 5)
  end

  def get_available_slots
      formatted_date = params[:date]
      if formatted_date.to_date > Date.today
          slots = Appointment.get_booked_slots(params[:doctor_id],formatted_date)
          render json: {status: "success",slots: slots}
      else
          render json: {status: "Select a Future Date"} 
      end    
  end

end

  private

  def appointment_params
      params.require(:appointment).permit(:doctor_id,:date,:note,:start_time)
  end

  def appointment_update_params
      params.require(:appointment).permit(:date,:start_time)
  end


  

require_dependency 'sort_order'

class PatientDataController < ApplicationController
  page_title 'Laika Test Library'
  before_filter :set_patient_data, :except => %w[ index create autoCreate ]

  include SortOrder
  self.valid_sort_fields = %w[ name created_at updated_at ]

  def index
    @patients = PatientData.find(:all,
      :conditions => {:vendor_test_plan_id => nil},
      :order => sort_order || "name ASC")

    @vendors = current_user.vendors + Vendor.unclaimed

    @previous_vendor = last_selected_vendor
    @previous_kind   = last_selected_kind
  end
  
  def autoCreate
    @patient = PatientData.new    
    @patient.registration_information = RegistrationInformation.new
    @patient.randomize()
    @patient.user = current_user
    @patient.save!
    redirect_to :controller => 'patient_data', :action => 'show', :id => @patient.id
  end

  def create
    @patient = PatientData.new(params[:patient_data])
    @patient.user = current_user
    @patient.save!
    redirect_to :controller => 'patient_data', :action => 'show', :id => @patient.id
  rescue ActiveRecord::RecordInvalid => e
    flash[:notice] = e.to_s
    redirect_to patient_data_url
  end
  
  def checklist
    respond_to do |format|
      format.xml  
    end
  end

  def show
    if @patient.vendor_test_plan_id 
      @show_dashboard = true
    else
      @show_dashboard = false
    end
    respond_to do |format|
      format.html 
      format.xml  do
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!
        send_data @patient.to_c32(xml),
          :filename => "#{@patient.id}.xml",
          :type => 'application/x-download'
      end
    end
  end

  def set_no_known_allergies
    @patient.update_attribute(:no_known_allergies, true)
    render :partial => '/allergies/no_known_allergies'
  end
  
  def set_pregnant
    @patient.update_attribute(:pregnant, true)
  end
  
  def set_not_pregnant
    @patient.update_attribute(:pregnant, false)
  end
  
  def destroy
    @patient.destroy
    redirect_to :controller => 'patient_data', :action => 'index'
  end

  def edit_template_info
    render :layout => false
  end

  def update
    if @patient.update_attributes(params[:patient_data])
      render :partial => 'template_info'
    else
      render :action => 'edit_template_info', :layout => false
    end
  end

  def set_patient_data
    @patient = PatientData.find(params[:id])
  end

end

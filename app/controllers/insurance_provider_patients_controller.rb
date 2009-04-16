class InsuranceProviderPatientsController < PatientDataChildController

  def update
    insurance_provider_patient = @patient.insurance_provider_patients.find(params[:id])
    insurance_provider_patient.update_attributes(params[:insurance_provider_patient])
    insurance_provider_patient.update_person_attributes(params)

    render :partial  => 'show', :locals => {
      :insurance_provider_patient => insurance_provider_patient,
      :patient_data               => @patient
    }
  end

end

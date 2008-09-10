require 'faker'

class Support < ActiveRecord::Base

  strip_attributes!

  belongs_to :patient_data
  belongs_to :contact_type
  belongs_to :relationship

  include PersonLike
  include MatchHelper

  #Reimplementing from MatchHelper
  def section_name
    "Supports Module"
  end

  def validate_c32(document)
    errors = []
    begin
      support = REXML::XPath.first(document, "/cda:ClinicalDocument/cda:participant/cda:associatedEntity[cda:associatedPerson/cda:name/cda:given/text() = $first_name ] | /cda:ClinicalDocument/cda:recordTarget/cda:patientRole/cda:patient/cda:guardian[cda:guardianPerson/cda:name/cda:given/text() = $first_name]",
         {'cda' => 'urn:hl7-org:v3'}, {"first_name" => person_name.first_name})
      if support
        time_element = REXML::XPath.first(support, "../cda:time", {'cda' => 'urn:hl7-org:v3'})
        if time_element
          if self.start_support
            errors << match_value(time_element, "cda:low/@value", "start_support", self.start_support.to_formatted_s(:hl7_ts))
          end
          if self.end_support
            errors << match_value(time_element, "cda:high/@value", "end_support", self.end_support.to_formatted_s(:hl7_ts))
          end
        else
          errors <<  ContentError.new(:section => "Support", 
                                      :subsection => "date",
                                      :error_message => "No time element found in the support",
                                      :location => support.xpath)
        end
        if self.address
          add =  REXML::XPath.first(support,"cda:addr",{'cda' => 'urn:hl7-org:v3'})
          if add
             errors.concat   self.address.validate_c32(add)  
          else                                 
             errors <<  ContentError.new(:section => "Support", 
                                         :subsection => "address",
                                         :error_message => "Address not found in the support section #{support.xpath}",
                                         :location => support.xpath)          
          end
        end
        if self.telecom
          errors.concat self.telecom.validate_c32(support)
        end
        # classcode
        errors << match_value(support, "@classCode", "contact_type", contact_type.andand.code)
        errors << match_value(support, "cda:code[@codeSystem='2.16.840.1.113883.5.111']/@code", "relationship", relationship.andand.code)
      else
        # add the error for no support object being there 
        errors <<  ContentError.new(:section=> "Support", 
                                    :error_message=> "Support element does not exist")          
      end
    rescue
      errors << ContentError.new(:section => 'Support', 
                                 :error_message => 'Invalid, non-parsable XML for supports data',
                                 :type=>'error',
                                 :location => document.xpath)
    end
    errors.compact
  end

  def to_c32(xml)
    if contact_type && contact_type.code == "GUARD"
      xml.guardian("classCode" => contact_type.code) do
        xml.templateId("root" => "2.16.840.1.113883.3.88.11.32.3")
        if relationship
          xml.code("code" => relationship.code, 
                   "displayName" => relationship.name,
                   "codeSystem" => "2.16.840.1.113883.5.111",
                   "codeSystemName" => "RoleCode")
        end
        address.andand.to_c32(xml)
        telecom.andand.to_c32(xml)
        xml.guardianPerson do
          person_name.to_c32(xml)
        end
      end
    else
      xml.participant("typeCode" => "IND") do
        xml.templateId("root" => "2.16.840.1.113883.3.88.11.32.3")
        xml.time do
          if start_support 
            xml.low('value'=> start_support.strftime("%Y%m%d"))
          end
          if end_support
            xml.high('value'=> end_support.strftime("%Y%m%d"))
          end
        end
        xml.associatedEntity("classCode" => contact_type.code) do
          xml.code("code" => relationship.code, 
                   "displayName" => relationship.name,
                   "codeSystem" => "2.16.840.1.113883.5.111",
                   "codeSystemName" => "RoleCode")
          address.andand.to_c32(xml)
          telecom.andand.to_c32(xml) 
          xml.associatedPerson do
            person_name.andand.to_c32(xml)
          end
        end
      end
    end            
  end

  def randomize(birth_date)
    self.start_support = DateTime.new(birth_date.year + rand(DateTime.now.year - birth_date.year), rand(12) + 1, rand(28) +1)
    self.end_support = DateTime.new(start_support.year + rand(DateTime.now.year - start_support.year), rand(12) + 1, rand(28) +1)
    self.person_name = PersonName.new
    self.person_name.first_name = Faker::Name.first_name
    self.person_name.last_name = Faker::Name.last_name
    self.address = Address.new
    self.address.randomize()
    self.telecom = Telecom.new
    self.telecom.randomize()
    self.contact_type = ContactType.find(:all).sort_by{rand}.first
    self.relationship = Relationship.find(:all).sort_by{rand}.first
  end

end
SET @OLD_SQL_MODE=@@SQL_MODE $$
SET SQL_MODE='' $$
DROP PROCEDURE IF EXISTS sp_update_etl_patient_demographics $$
CREATE PROCEDURE sp_update_etl_patient_demographics(IN last_update_time DATETIME)

BEGIN
-- update etl_patient_demographics table
insert into kenyaemr_etl.etl_patient_demographics(
patient_id,
given_name,
middle_name,
family_name,
Gender,
DOB,
dead,
date_created,
date_last_modified,
voided,
death_date
)
select 
p.person_id,
p.given_name,
p.middle_name,
p.family_name,
p.gender,
p.birthdate,
p.dead,
p.date_created,
if((p.date_last_modified='0000-00-00 00:00:00' or p.date_last_modified=p.date_created),NULL,p.date_last_modified) as date_last_modified,
p.voided,
p.death_date
FROM (
select 
p.person_id,
pn.given_name,
pn.middle_name,
pn.family_name,
p.gender,
p.birthdate,
p.dead,
p.date_created,
greatest(ifnull(p.date_changed,'0000-00-00 00:00:00'),ifnull(pn.date_changed,'0000-00-00 00:00:00')) as date_last_modified,
p.voided,
p.death_date
from person p 
left join patient pa on pa.patient_id=p.person_id and pa.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
where pn.date_created >= last_update_time
or pn.date_changed >= last_update_time
or pn.date_voided >= last_update_time
or p.date_created >= last_update_time
or p.date_changed >= last_update_time
or p.date_voided >= last_update_time
GROUP BY p.person_id
) p
ON DUPLICATE KEY UPDATE 
given_name = p.given_name, 
middle_name=p.middle_name, 
family_name=p.family_name, 
DOB=p.birthdate, 
dead=p.dead, voided=p.voided, death_date=p.death_date;

-- update etl_patient_demographics with patient attributes: birthplace, citizenship, mother_name, phone number and kin's details
update kenyaemr_etl.etl_patient_demographics d 
inner join 
(
select 
pa.person_id,  
max(if(pat.uuid='8d8718c2-c2cc-11de-8d13-0010c6dffd0f', pa.value, null)) as birthplace,
max(if(pat.uuid='8d871afc-c2cc-11de-8d13-0010c6dffd0f', pa.value, null)) as citizenship,
max(if(pat.uuid='8d871d18-c2cc-11de-8d13-0010c6dffd0f', pa.value, null)) as Mother_name,
max(if(pat.uuid='b2c38640-2603-4629-aebd-3b54f33f1e3a', pa.value, null)) as phone_number,
max(if(pat.uuid='342a1d39-c541-4b29-8818-930916f4c2dc', pa.value, null)) as next_of_kin_contact,
max(if(pat.uuid='d0aa9fd1-2ac5-45d8-9c5e-4317c622c8f5', pa.value, null)) as next_of_kin_relationship,
max(if(pat.uuid='7cf22bec-d90a-46ad-9f48-035952261294', pa.value, null)) as next_of_kin_address,
max(if(pat.uuid='830bef6d-b01f-449d-9f8d-ac0fede8dbd3', pa.value, null)) as next_of_kin_name,
max(if(pat.uuid='b8d0b331-1d2d-4a9a-b741-1816f498bdb6', pa.value, null)) as email_address,
max(if(pat.uuid='848f5688-41c6-464c-b078-ea6524a3e971', pa.value, null)) as unit,
max(if(pat.uuid='96a99acd-2f11-45bb-89f7-648dbcac5ddf', pa.value, null)) as cadre,
max(if(pat.uuid='9f1f8254-20ea-4be4-a14d-19201fe217bf', pa.value, null)) as rank,
greatest(ifnull(pa.date_changed,'0000-00-00'),pa.date_created) as latest_date
from person_attribute pa
inner join
(
select 
pat.person_attribute_type_id,
pat.name,
pat.uuid
from person_attribute_type pat
where pat.retired=0
) pat on pat.person_attribute_type_id = pa.person_attribute_type_id 
and pat.uuid in (
	'8d8718c2-c2cc-11de-8d13-0010c6dffd0f', -- birthplace
	'8d871afc-c2cc-11de-8d13-0010c6dffd0f', -- citizenship
	'8d871d18-c2cc-11de-8d13-0010c6dffd0f', -- mother's name
	'b2c38640-2603-4629-aebd-3b54f33f1e3a', -- telephone contact
	'342a1d39-c541-4b29-8818-930916f4c2dc', -- next of kin's contact
	'd0aa9fd1-2ac5-45d8-9c5e-4317c622c8f5', -- next of kin's relationship
	'7cf22bec-d90a-46ad-9f48-035952261294', -- next of kin's address
	'830bef6d-b01f-449d-9f8d-ac0fede8dbd3', -- next of kin's name
	'848f5688-41c6-464c-b078-ea6524a3e971', -- unit
	'96a99acd-2f11-45bb-89f7-648dbcac5ddf', -- cadre
	'9f1f8254-20ea-4be4-a14d-19201fe217bf' -- rank

	)
where pa.date_created >= last_update_time
or pa.date_changed >= last_update_time
or pa.date_voided >= last_update_time
group by pa.person_id
) att on att.person_id = d.patient_id
set d.phone_number=att.phone_number, 
	d.next_of_kin=att.next_of_kin_name,
	d.next_of_kin_relationship=att.next_of_kin_relationship,
	d.next_of_kin_phone=att.next_of_kin_contact,
	d.phone_number=att.phone_number,
	d.birth_place = att.birthplace,
	d.citizenship = att.citizenship,
	d.email_address=att.email_address,
	d.unit=att.unit,
	d.cadre=att.cadre,
	d.rank=att.rank,
	d.date_last_modified=if(att.latest_date > ifnull(d.date_last_modified,'0000-00-00'),att.latest_date,d.date_last_modified);


update kenyaemr_etl.etl_patient_demographics d
inner join (select pi.patient_id,
max(if(pit.uuid='05ee9cf4-7242-4a17-b4d4-00f707265c8a',pi.identifier,null)) as upn,
max(if(pit.uuid='d8ee3b8c-a8fc-4d6b-af6a-9423be5f8906',pi.identifier,null)) district_reg_number,
max(if(pit.uuid='c4e3caca-2dcc-4dc4-a8d9-513b6e63af91',pi.identifier,null)) Tb_treatment_number,
max(if(pit.uuid='b4d66522-11fc-45c7-83e3-39a1af21ae0d',pi.identifier,null)) Patient_clinic_number,
max(if(pit.uuid='49af6cdc-7968-4abb-bf46-de10d7f4859f',pi.identifier,null)) National_id,
max(if(pit.uuid='6428800b-5a8c-4f77-a285-8d5f6174e5fb',pi.identifier,null)) Huduma_number,
max(if(pit.uuid='be9beef6-aacc-4e1f-ac4e-5babeaa1e303',pi.identifier,null)) Passport_number,
max(if(pit.uuid='68449e5a-8829-44dd-bfef-c9c8cf2cb9b2',pi.identifier,null)) Birth_cert_number,
max(if(pit.uuid='0691f522-dd67-4eeb-92c8-af5083baf338',pi.identifier,null)) Hei_id,
max(if(pit.uuid='1dc8b419-35f2-4316-8d68-135f0689859b',pi.identifier,null)) cwc_number,
max(if(pit.uuid='f2b0c94f-7b2b-4ab0-aded-0d970f88c063',pi.identifier,null)) kdod_service_number,
max(if(pit.uuid='5065ae70-0b61-11ea-8d71-362b9e155667',pi.identifier,null)) CPIMS_unique_identifier,
max(if(pit.uuid='dfacd928-0370-4315-99d7-6ec1c9f7ae76',pi.identifier,null)) openmrs_id,
max(if(pit.uuid='ac64e5cb-e3e2-4efa-9060-0dd715a843a1',pi.identifier,null)) unique_prep_number,
max(if(pit.uuid='1c7d0e5b-2068-4816-a643-8de83ab65fbf',pi.identifier,null)) alien_no,
max(if(pit.uuid='ca125004-e8af-445d-9436-a43684150f8b',pi.identifier,null)) driving_license_no,
max(if(pit.uuid='f85081e2-b4be-4e48-b3a4-7994b69bb101',pi.identifier,null)) national_unique_patient_identifier,
max(if(pit.uuid='fd52829a-75d2-4732-8e43-4bff8e5b4f1a',pi.identifier,null)) hts_recency_id,
greatest(ifnull(max(pi.date_changed),'0000-00-00'),max(pi.date_created)) as latest_date
from patient_identifier pi
join patient_identifier_type pit on pi.identifier_type=pit.patient_identifier_type_id
where voided=0 and
pi.date_created >= last_update_time
or pi.date_changed >= last_update_time
or pi.date_voided >= last_update_time
group by pi.patient_id) pid on pid.patient_id=d.patient_id
set d.unique_patient_no=pid.UPN, 
	d.national_id_no=pid.National_id,
  d.huduma_no=pid.Huduma_number,
  d.passport_no=pid.Passport_number,
  d.birth_certificate_no=pid.Birth_cert_number,
	d.patient_clinic_number=pid.Patient_clinic_number,
    d.hei_no=pid.Hei_id,
    d.cwc_number=pid.cwc_number,
    d.Tb_no=pid.Tb_treatment_number,
    d.district_reg_no=pid.district_reg_number,
    d.kdod_service_number=pid.kdod_service_number,
    d.CPIMS_unique_identifier=pid.CPIMS_unique_identifier,
    d.openmrs_id=pid.openmrs_id,
    d.unique_prep_number=pid.unique_prep_number,
    d.alien_no=pid.alien_no,
    d.driving_license_no=pid.driving_license_no,
    d.national_unique_patient_identifier=pid.national_unique_patient_identifier,
    d.hts_recency_id=pid.hts_recency_id,
    d.date_last_modified=if(pid.latest_date > ifnull(d.date_last_modified,'0000-00-00'),pid.latest_date,d.date_last_modified)
;

update kenyaemr_etl.etl_patient_demographics d
inner join (select o.person_id as patient_id,
max(if(o.concept_id in(1054),cn.name,null))  as marital_status,
max(if(o.concept_id in(1712),cn.name,null))  as education_level,
max(if(o.concept_id in(1542),cn.name,null))  as occupation,
max(o.date_created) as date_created
from obs o
join concept_name cn on cn.concept_id=o.value_coded and cn.concept_name_type='FULLY_SPECIFIED'
and cn.locale='en'
where o.concept_id in (1054,1712,1542) and o.voided=0 and
o.date_created >= last_update_time
or o.date_voided >= last_update_time
group by person_id) pstatus on pstatus.patient_id=d.patient_id
set d.marital_status=pstatus.marital_status,
d.education_level=pstatus.education_level,
d.occupation=pstatus.occupation,
d.date_last_modified=if(pstatus.date_created > d.date_last_modified,pstatus.date_created,d.date_last_modified);

END $$
-- DELIMITER ;



DROP PROCEDURE IF EXISTS sp_update_etl_hiv_enrollment $$
CREATE PROCEDURE sp_update_etl_hiv_enrollment(IN last_update_time DATETIME)
  BEGIN


    -- update patient_hiv_enrollment table
    -- uuid: de78a6be-bfc5-4634-adc3-5f1a280455cc

    insert into kenyaemr_etl.etl_hiv_enrollment (
      patient_id,
      uuid,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      patient_type,
      date_first_enrolled_in_care,
      entry_point,
      transfer_in_date,
      facility_transferred_from,
      district_transferred_from,
      previous_regimen,
      date_started_art_at_transferring_facility,
      date_confirmed_hiv_positive,
      facility_confirmed_hiv_positive,
      arv_status,
      ever_on_pmtct,
      ever_on_pep,
      ever_on_prep,
      ever_on_haart,
      name_of_treatment_supporter,
      relationship_of_treatment_supporter,
      treatment_supporter_telephone,
      treatment_supporter_address,
      in_school,
      orphan,
      date_of_discontinuation,
      discontinuation_reason,
      voided
    )
      select
        e.patient_id,
        e.uuid,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.creator,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id in (164932), o.value_coded, if(o.concept_id=160563 and o.value_coded=1065, 160563, null))) as patient_type ,
        max(if(o.concept_id=160555,o.value_datetime,null)) as date_first_enrolled_in_care ,
        max(if(o.concept_id=160540,o.value_coded,null)) as entry_point,
        max(if(o.concept_id=160534,o.value_datetime,null)) as transfer_in_date,
        max(if(o.concept_id=160535,left(trim(o.value_text),100),null)) as facility_transferred_from,
        max(if(o.concept_id=161551,left(trim(o.value_text),100),null)) as district_transferred_from,
        max(if(o.concept_id=164855,o.value_coded,null)) as previous_regimen,
        max(if(o.concept_id=159599,o.value_datetime,null)) as date_started_art_at_transferring_facility,
        max(if(o.concept_id=160554,o.value_datetime,null)) as date_confirmed_hiv_positive,
        max(if(o.concept_id=160632,left(trim(o.value_text),100),null)) as facility_confirmed_hiv_positive,
        max(if(o.concept_id=160533,o.value_coded,null)) as arv_status,
        max(if(o.concept_id=1148,o.value_coded,null)) as ever_on_pmtct,
        max(if(o.concept_id=1691,o.value_coded,null)) as ever_on_pep,
        max(if(o.concept_id=165269,o.value_coded,null)) as ever_on_prep,
        max(if(o.concept_id=1181,o.value_coded,null)) as ever_on_haart,
        max(if(o.concept_id=160638,left(trim(o.value_text),100),null)) as name_of_treatment_supporter,
        max(if(o.concept_id=160640,o.value_coded,null)) as relationship_of_treatment_supporter,
        max(if(o.concept_id=160642,left(trim(o.value_text),100),null)) as treatment_supporter_telephone ,
        max(if(o.concept_id=160641,left(trim(o.value_text),100),null)) as treatment_supporter_address,
        max(if(o.concept_id=5629,o.value_coded,null)) as in_school,
        max(if(o.concept_id=1174,o.value_coded,null)) as orphan,
        max(if(o.concept_id=164384, o.value_datetime, null)) as date_of_discontinuation,
        max(if(o.concept_id=161555, o.value_coded, null)) as discontinuation_reason,
        e.voided
      from encounter e
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid='de78a6be-bfc5-4634-adc3-5f1a280455cc'
        ) et on et.encounter_type_id=e.encounter_type
        join person p on p.person_id=e.patient_id and p.voided=0
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (160555,160540,160534,160535,161551,159599,160554,160632,160533,160638,160640,160642,160641,164932,160563,5629,1174,1088,161555,164855,164384,1148,1691,165269,1181)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider), patient_type=VALUES(patient_type), date_first_enrolled_in_care=VALUES(date_first_enrolled_in_care),entry_point=VALUES(entry_point),transfer_in_date=VALUES(transfer_in_date),
      facility_transferred_from=VALUES(facility_transferred_from),district_transferred_from=VALUES(district_transferred_from),previous_regimen=VALUES(previous_regimen),date_started_art_at_transferring_facility=VALUES(date_started_art_at_transferring_facility),date_confirmed_hiv_positive=VALUES(date_confirmed_hiv_positive),facility_confirmed_hiv_positive=VALUES(facility_confirmed_hiv_positive),
      arv_status=VALUES(arv_status),name_of_treatment_supporter=VALUES(name_of_treatment_supporter),relationship_of_treatment_supporter=VALUES(relationship_of_treatment_supporter),treatment_supporter_telephone=VALUES(treatment_supporter_telephone),treatment_supporter_address=VALUES(treatment_supporter_address),in_school=VALUES(in_school),orphan=VALUES(orphan),voided=VALUES(voided),
      date_of_discontinuation=VALUES(date_of_discontinuation),discontinuation_reason=(discontinuation_reason);

    END $$
-- DELIMITER ;

-- ------------- update etl_hiv_followup--------------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_hiv_followup $$
CREATE PROCEDURE sp_update_etl_hiv_followup(IN last_update_time DATETIME)
  BEGIN

    INSERT INTO kenyaemr_etl.etl_patient_hiv_followup(
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      visit_scheduled,
      person_present,
      weight,
      systolic_pressure,
      diastolic_pressure,
      height,
      temperature,
      pulse_rate,
      respiratory_rate,
      oxygen_saturation,
      muac,
      nutritional_status,
      population_type,
      key_population_type,
      who_stage,
      presenting_complaints,
      clinical_notes,
      on_anti_tb_drugs,
      on_ipt,
      ever_on_ipt,
      cough,
      fever,
      weight_loss_poor_gain,
      night_sweats,
      tb_case_contact,
      lethargy,
      screened_for_tb,
      spatum_smear_ordered,
      chest_xray_ordered,
      genexpert_ordered,
      spatum_smear_result,
      chest_xray_result,
      genexpert_result,
      referral,
      clinical_tb_diagnosis,
      contact_invitation,
      evaluated_for_ipt,
      has_known_allergies,
      has_chronic_illnesses_cormobidities,
      has_adverse_drug_reaction,
      pregnancy_status,
      breastfeeding,
      wants_pregnancy,
      pregnancy_outcome,
      anc_number,
      expected_delivery_date,
      ever_had_menses,
      last_menstrual_period,
      menopausal,
      gravida,
      parity,
      full_term_pregnancies,
      abortion_miscarriages,
      family_planning_status,
      family_planning_method,
      reason_not_using_family_planning,
      tb_status,
      started_anti_TB,
      tb_rx_date,
      tb_treatment_no,
      general_examination,
      system_examination,
      skin_findings,
      eyes_findings,
      ent_findings,
      chest_findings,
      cvs_findings,
      abdomen_findings,
      cns_findings,
      genitourinary_findings,
      prophylaxis_given,
      ctx_adherence,
      ctx_dispensed,
      dapsone_adherence,
      dapsone_dispensed,
      inh_dispensed,
      arv_adherence,
      poor_arv_adherence_reason,
      poor_arv_adherence_reason_other,
      pwp_disclosure,
      pwp_pead_disclosure,
      pwp_partner_tested,
      condom_provided,
      substance_abuse_screening,
      screened_for_sti,
      cacx_screening,
      sti_partner_notification,
      at_risk_population,
      system_review_finding,
      next_appointment_date,
      next_appointment_reason,
      refill_date,
      appointment_consent,
      stability,
      differentiated_care,
      voided
    )
      select
        e.patient_id,
        e.visit_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=1246,o.value_coded,null)) as visit_scheduled ,
        max(if(o.concept_id=161643,o.value_coded,null)) as person_present,
        max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
        max(if(o.concept_id=5085,o.value_numeric,null)) as systolic_pressure,
        max(if(o.concept_id=5086,o.value_numeric,null)) as diastolic_pressure,
        max(if(o.concept_id=5090,o.value_numeric,null)) as height,
        max(if(o.concept_id=5088,o.value_numeric,null)) as temperature,
        max(if(o.concept_id=5087,o.value_numeric,null)) as pulse_rate,
        max(if(o.concept_id=5242,o.value_numeric,null)) as respiratory_rate,
        max(if(o.concept_id=5092,o.value_numeric,null)) as oxygen_saturation,
        max(if(o.concept_id=1343,o.value_numeric,null)) as muac,
        max(if(o.concept_id=163300,o.value_coded,null)) as nutritional_status,
        max(if(o.concept_id=164930,o.value_coded,null)) as population_type,
        max(if(o.concept_id=160581,o.value_coded,null)) as key_population_type,
        max(if(o.concept_id=5356,o.value_coded,null)) as who_stage ,
        max(if(o.concept_id=1154,o.value_coded,null)) as presenting_complaints ,
        null as clinical_notes, -- max(if(o.concept_id=160430,left(trim(o.value_text),600),null)) as clinical_notes ,
        max(if(o.concept_id=164948,o.value_coded,null)) as on_anti_tb_drugs ,
        max(if(o.concept_id=164949,o.value_coded,null)) as on_ipt ,
        max(if(o.concept_id=164950,o.value_coded,null)) as ever_on_ipt ,
        max(if(o.concept_id=1729 and o.value_coded =159799,o.value_coded,null)) as cough,
        max(if(o.concept_id=1729 and o.value_coded =1494,o.value_coded,null)) as fever,
        max(if(o.concept_id=1729 and o.value_coded =832,o.value_coded,null)) as weight_loss_poor_gain,
        max(if(o.concept_id=1729 and o.value_coded =133027,o.value_coded,null)) as night_sweats,
        max(if(o.concept_id=1729 and o.value_coded =124068,o.value_coded,null)) as tb_case_contact,
        max(if(o.concept_id=1729 and o.value_coded =116334,o.value_coded,null)) as lethargy,
        max(if(o.concept_id=1729 and o.value_coded in(159799,1494,832,133027,124068,116334,1066),'Yes','No'))as screened_for_tb,
        max(if(o.concept_id=1271 and o.value_coded= 307,o.value_coded,null)) as spatum_smear_ordered ,
        max(if(o.concept_id=1271 and o.value_coded= 12,o.value_coded,null)) as chest_xray_ordered ,
        max(if(o.concept_id=1271 and o.value_coded= 162202,o.value_coded,null)) as genexpert_ordered ,
        max(if(o.concept_id=307,o.value_coded,null)) as spatum_smear_result ,
        max(if(o.concept_id=12,o.value_coded,null)) as chest_xray_result ,
        max(if(o.concept_id=162202,o.value_coded,null)) as genexpert_result ,
        max(if(o.concept_id=1272,o.value_coded,null)) as referral ,
        max(if(o.concept_id=163752,o.value_coded,null)) as clinical_tb_diagnosis ,
        max(if(o.concept_id=163414,o.value_coded,null)) as contact_invitation ,
        max(if(o.concept_id=162275,o.value_coded,null)) as evaluated_for_ipt ,
        max(if(o.concept_id=160557,o.value_coded,null)) as has_known_allergies ,
        max(if(o.concept_id=162747,o.value_coded,null)) as has_chronic_illnesses_cormobidities ,
        max(if(o.concept_id=121764,o.value_coded,null)) as has_adverse_drug_reaction ,
        max(if(o.concept_id=5272,o.value_coded,null)) as pregnancy_status,
        max(if(o.concept_id=5632,o.value_coded,null)) as breastfeeding,
        max(if(o.concept_id=164933,o.value_coded,null)) as wants_pregnancy,
        max(if(o.concept_id=161033,o.value_coded,null)) as pregnancy_outcome,
        max(if(o.concept_id=163530,o.value_text,null)) as anc_number,
        max(if(o.concept_id=5596,date(o.value_datetime),null)) as expected_delivery_date,
        max(if(o.concept_id=162877,o.value_coded,null)) as ever_had_menses,
        max(if(o.concept_id=1427,date(o.value_datetime),null)) as last_menstrual_period,
        max(if(o.concept_id=160596,o.value_coded,null)) as menopausal,
        max(if(o.concept_id=5624,o.value_numeric,null)) as gravida,
        max(if(o.concept_id=1053,o.value_numeric,null)) as parity ,
        max(if(o.concept_id=160080,o.value_numeric,null)) as full_term_pregnancies,
        max(if(o.concept_id=1823,o.value_numeric,null)) as abortion_miscarriages ,
        max(if(o.concept_id=160653,o.value_coded,null)) as family_planning_status,
        max(if(o.concept_id=374,o.value_coded,null)) as family_planning_method,
        max(if(o.concept_id=160575,o.value_coded,null)) as reason_not_using_family_planning ,
        max(if(o.concept_id=1659,o.value_coded,null)) as tb_status,
        max(if(o.concept_id=162309,o.value_coded,null)) as started_anti_TB,
        max(if(o.concept_id=1113,o.value_datetime,null)) as tb_rx_date,
        max(if(o.concept_id=161654,trim(o.value_text),null)) as tb_treatment_no,
        concat_ws(',',nullif(max(if(o.concept_id=162737 and o.value_coded =1107 ,'None','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded =136443,'Jaundice','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded =460,'Oedema','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 5334,'Oral Thrush','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 5245,'Pallor','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 140125,'Finger Clubbing','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 126952,'Lymph Node Axillary','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 143050,'Cyanosis','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 126939,'Lymph Nodes Inguinal','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 823,'Wasting','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 142630,'Dehydration','')),''),
                 nullif(max(if(o.concept_id=162737 and o.value_coded = 116334,'Lethargic','')),'')) as general_examination,
        max(if(o.concept_id=159615,o.value_coded,null)) as system_examination,
        max(if(o.concept_id=1120,o.value_coded,null)) as skin_findings,
        max(if(o.concept_id=163309,o.value_coded,null)) as eyes_findings,
        max(if(o.concept_id=164936,o.value_coded,null)) as ent_findings,
        max(if(o.concept_id=1123,o.value_coded,null)) as chest_findings,
        max(if(o.concept_id=1124,o.value_coded,null)) as cvs_findings,
        max(if(o.concept_id=1125,o.value_coded,null)) as abdomen_findings,
        max(if(o.concept_id=164937,o.value_coded,null)) as cns_findings,
        max(if(o.concept_id=1126,o.value_coded,null)) as genitourinary_findings,
        max(if(o.concept_id=1109,o.value_coded,null)) as prophylaxis_given,
        max(if(o.concept_id=161652,o.value_coded,null)) as ctx_adherence,
        max(if(o.concept_id=162229 or (o.concept_id=1282 and o.value_coded = 105281),o.value_coded,null)) as ctx_dispensed,
        max(if(o.concept_id=164941,o.value_coded,null)) as dapsone_adherence,
        max(if(o.concept_id=164940 or (o.concept_id=1282 and o.value_coded = 74250),o.value_coded,null)) as dapsone_dispensed,
        max(if(o.concept_id=162230,o.value_coded,null)) as inh_dispensed,
        max(if(o.concept_id=1658,o.value_coded,null)) as arv_adherence,
        max(if(o.concept_id=160582,o.value_coded,null)) as poor_arv_adherence_reason,
        max(if(o.concept_id=160632,trim(o.value_text),null)) as poor_arv_adherence_reason_other,
        max(if(o.concept_id=159423,o.value_coded,null)) as pwp_disclosure,
        max(if(o.concept_id=5616,o.value_coded,null)) as pwp_pead_disclosure,
        max(if(o.concept_id=161557,o.value_coded,null)) as pwp_partner_tested,
        max(if(o.concept_id=159777,o.value_coded,null)) as condom_provided ,
        max(if(o.concept_id=112603,o.value_coded,null)) as substance_abuse_screening,
        max(if(o.concept_id=161558,o.value_coded,null)) as screened_for_sti,
        max(if(o.concept_id=164934,o.value_coded,null)) as cacx_screening,
        max(if(o.concept_id=164935,o.value_coded,null)) as sti_partner_notification,
        max(if(o.concept_id=160581,o.value_coded,null)) as at_risk_population,
        max(if(o.concept_id=159615,o.value_coded,null)) as system_review_finding,
        max(if(o.concept_id=5096,o.value_datetime,null)) as next_appointment_date,
        max(if(o.concept_id=162549,o.value_datetime,null)) as refill_date,
        max(if(o.concept_id=166607,o.value_coded,null)) as appointment_consent,
        max(if(o.concept_id=160288,o.value_coded,null)) as next_appointment_reason,
        max(if(o.concept_id=1855,o.value_coded,null)) as stability,
        max(if(o.concept_id=164947,o.value_coded,null)) as differentiated_care,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid ='a0034eee-1940-4e35-847f-97537a35d05e'
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (1282,1246,161643,5089,5085,5086,5090,5088,5087,5242,5092,1343,5356,5272,5632,161033,163530,5596,1427,5624,1053,160653,374,160575,
                                 1659,161654,161652,162229,162230,1658,160582,160632,159423,5616,161557,159777,112603,161558,160581,5096,163300, 164930, 160581, 1154, 160430, 164948,
                                 164949, 164950, 1271, 307, 12, 162202, 1272, 163752, 163414, 162275, 160557, 162747,
                                 121764, 164933, 160080, 1823, 164940, 164934, 164935, 159615, 160288,1855, 164947, 162549,162877,160596,1109,162309,1113,1729,162737,159615,1120,163309,164936,1123,1124,1125,164937,1126,166607)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),visit_scheduled=VALUES(visit_scheduled),
      person_present=VALUES(person_present),weight=VALUES(weight),systolic_pressure=VALUES(systolic_pressure),diastolic_pressure=VALUES(diastolic_pressure),height=VALUES(height),temperature=VALUES(temperature),pulse_rate=VALUES(pulse_rate),respiratory_rate=VALUES(respiratory_rate),
      oxygen_saturation=VALUES(oxygen_saturation),muac=VALUES(muac), nutritional_status=VALUES(nutritional_status), population_type=VALUES(population_type), key_population_type=VALUES(key_population_type), who_stage=VALUES(who_stage),presenting_complaints = VALUES(presenting_complaints),
      clinical_notes = VALUES(clinical_notes),on_anti_tb_drugs=VALUES(on_anti_tb_drugs),on_ipt=VALUES(on_ipt),ever_on_ipt=VALUES(ever_on_ipt),cough=VALUES(cough),fever=VALUES(fever),weight_loss_poor_gain=VALUES(weight_loss_poor_gain),night_sweats=VALUES(night_sweats),tb_case_contact=VALUES(tb_case_contact),lethargy=VALUES(lethargy),screened_for_tb=VALUES(screened_for_tb),
      spatum_smear_ordered=VALUES(spatum_smear_ordered),chest_xray_ordered=VALUES(chest_xray_ordered),genexpert_ordered=VALUES(genexpert_ordered),
      spatum_smear_result=VALUES(spatum_smear_result), chest_xray_result=VALUES(chest_xray_result),genexpert_result=VALUES(genexpert_result),referral=VALUES(referral),clinical_tb_diagnosis=VALUES(clinical_tb_diagnosis),contact_invitation=VALUES(contact_invitation),
      evaluated_for_ipt=VALUES(evaluated_for_ipt),has_known_allergies=VALUES(has_known_allergies),has_chronic_illnesses_cormobidities=VALUES(has_chronic_illnesses_cormobidities),
      has_adverse_drug_reaction=VALUES(has_adverse_drug_reaction),pregnancy_status=VALUES(pregnancy_status),breastfeeding=VALUES(breastfeeding),wants_pregnancy=VALUES(wants_pregnancy), pregnancy_outcome=VALUES(pregnancy_outcome),anc_number=VALUES(anc_number),expected_delivery_date=VALUES(expected_delivery_date),
      last_menstrual_period=VALUES(last_menstrual_period),gravida=VALUES(gravida),parity=VALUES(parity),full_term_pregnancies=VALUES(full_term_pregnancies), abortion_miscarriages=VALUES(abortion_miscarriages),family_planning_status=VALUES(family_planning_status),family_planning_method=VALUES(family_planning_method),reason_not_using_family_planning=VALUES(reason_not_using_family_planning),
      tb_status=VALUES(tb_status),tb_treatment_no=VALUES(tb_treatment_no),general_examination=VALUES(general_examination),system_examination=VALUES(system_examination),skin_findings=VALUES(skin_findings),eyes_findings=VALUES(eyes_findings),ent_findings=VALUES(ent_findings),chest_findings=VALUES(chest_findings),
      cvs_findings=VALUES(cvs_findings),abdomen_findings=VALUES(abdomen_findings),cns_findings=VALUES(cns_findings),genitourinary_findings=VALUES(genitourinary_findings),ctx_adherence=VALUES(ctx_adherence),ctx_dispensed=VALUES(ctx_dispensed),dapsone_adherence=VALUES(dapsone_adherence),dapsone_dispensed=VALUES(dapsone_dispensed),inh_dispensed=VALUES(inh_dispensed),arv_adherence=VALUES(arv_adherence),poor_arv_adherence_reason=VALUES(poor_arv_adherence_reason),
      poor_arv_adherence_reason_other=VALUES(poor_arv_adherence_reason_other),pwp_disclosure=VALUES(pwp_disclosure),pwp_pead_disclosure=VALUES(pwp_pead_disclosure),pwp_partner_tested=VALUES(pwp_partner_tested),condom_provided=VALUES(condom_provided),substance_abuse_screening=VALUES(substance_abuse_screening),screened_for_sti=VALUES(screened_for_sti),cacx_screening=VALUES(cacx_screening), sti_partner_notification=VALUES(sti_partner_notification),at_risk_population=VALUES(at_risk_population),
      system_review_finding=VALUES(system_review_finding), next_appointment_date=VALUES(next_appointment_date), refill_date=VALUES(refill_date),appointment_consent=VALUES(appointment_consent), next_appointment_reason=VALUES(next_appointment_reason), differentiated_care=VALUES(differentiated_care),ever_had_menses=VALUES(ever_had_menses),menopausal=VALUES(menopausal),prophylaxis_given=VALUES(prophylaxis_given),started_anti_TB=VALUES(started_anti_TB),tb_rx_date=VALUES(tb_rx_date), voided=VALUES(voided)
    ;

    END $$
-- DELIMITER ;


-- ------------ create table etl_patient_treatment_event----------------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_program_discontinuation $$
CREATE PROCEDURE sp_update_etl_program_discontinuation(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_patient_program_discontinuation(
      patient_id,
      uuid,
      visit_id,
      visit_date,
      program_uuid,
      program_name,
      encounter_id,
      discontinuation_reason,
      effective_discontinuation_date,
      trf_out_verified,
      trf_out_verification_date,
      date_died,
      transfer_facility,
      transfer_date,
      death_reason,
      specific_death_cause,
      natural_causes,
      non_natural_cause,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.visit_id,
        e.encounter_datetime,
        et.uuid,
        (case et.uuid
         when '2bdada65-4c72-4a48-8730-859890e25cee' then 'HIV'
         when 'd3e3d723-7458-4b4e-8998-408e8a551a84' then 'TB'
         when '01894f88-dc73-42d4-97a3-0929118403fb' then 'MCH Child HEI'
         when '5feee3f1-aa16-4513-8bd0-5d9b27ef1208' then 'MCH Child'
         when '7c426cfc-3b47-4481-b55f-89860c21c7de' then 'MCH Mother'
         when '162382b8-0464-11ea-9a9f-362b9e155667' then 'OTZ'
         when '5cf00d9e-09da-11ea-8d71-362b9e155667' then 'OVC'
         when 'd7142400-2495-11e9-ab14-d663bd873d93' then 'KP'
         end) as program_name,
        e.encounter_id,
        max(if(o.concept_id=161555, o.value_coded, null)) as reason_discontinued,
        max(if(o.concept_id=164384, o.value_datetime, null)) as effective_discontinuation_date,
        max(if(o.concept_id=1285, o.value_coded, null)) as trf_out_verified,
        max(if(o.concept_id=164133, o.value_datetime, null)) as trf_out_verification_date,
        max(if(o.concept_id=1543, o.value_datetime, null)) as date_died,
        max(if(o.concept_id=159495, left(trim(o.value_text),100), null)) as to_facility,
        max(if(o.concept_id=160649, o.value_datetime, null)) as to_date,
        max(if(o.concept_id=1599, o.value_coded, null)) as death_reason,
        max(if(o.concept_id=1748, o.value_coded, null)) as specific_death_cause,
        max(if(o.concept_id=162580, left(trim(o.value_text),200), null)) as natural_causes,
        max(if(o.concept_id=160218, left(trim(o.value_text),200), null)) as non_natural_cause,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on o.encounter_id=e.encounter_id and o.voided=0 and o.concept_id in (161555,164384,1543,159495,160649,165380,1285,164133,1599,1748,162580,160218)
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('2bdada65-4c72-4a48-8730-859890e25cee','d3e3d723-7458-4b4e-8998-408e8a551a84','5feee3f1-aa16-4513-8bd0-5d9b27ef1208',
                    '7c426cfc-3b47-4481-b55f-89860c21c7de','01894f88-dc73-42d4-97a3-0929118403fb','162382b8-0464-11ea-9a9f-362b9e155667','5cf00d9e-09da-11ea-8d71-362b9e155667','d7142400-2495-11e9-ab14-d663bd873d93')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),discontinuation_reason=VALUES(discontinuation_reason),
      date_died=VALUES(date_died),transfer_facility=VALUES(transfer_facility),transfer_date=VALUES(transfer_date),
      trf_out_verified=VALUES(trf_out_verified),trf_out_verification_date=VALUES(trf_out_verification_date),
      death_reason=VALUES(death_reason),specific_death_cause=VALUES(specific_death_cause)
    ;

    END $$
-- DELIMITER ;

-- ------------- update etl_mch_enrollment------------------------- TO BE CHECKED AGAIN

DROP PROCEDURE IF EXISTS sp_update_etl_mch_enrollment $$
CREATE PROCEDURE sp_update_etl_mch_enrollment(IN last_update_time DATETIME)
  BEGIN

    insert into kenyaemr_etl.etl_mch_enrollment(
      patient_id,
      uuid,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      service_type,
      anc_number,
      first_anc_visit_date,
      gravida,
      parity,
      parity_abortion,
      age_at_menarche,
      lmp,
      lmp_estimated,
      edd_ultrasound,
      blood_group,
      serology,
      tb_screening,
      bs_for_mps,
      hiv_status,
      hiv_test_date,
      partner_hiv_status,
      partner_hiv_test_date,
      ti_date_started_art,
      ti_curent_regimen,
      ti_care_facility,
      urine_microscopy,
      urinary_albumin,
      glucose_measurement,
      urine_ph,
      urine_gravity,
      urine_nitrite_test,
      urine_leukocyte_esterace_test,
      urinary_ketone,
      urine_bile_salt_test,
      urine_bile_pigment_test,
      urine_colour,
      urine_turbidity,
      urine_dipstick_for_blood,
      -- date_of_discontinuation,
      discontinuation_reason,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        max(if(o.concept_id=160478,o.value_coded,null)) as service_type,
        max(if(o.concept_id=163530,o.value_text,null)) as anc_number,
        max(if(o.concept_id=163547,o.value_datetime,null)) as first_anc_visit_date,
        max(if(o.concept_id=5624,o.value_numeric,null)) as gravida,
        max(if(o.concept_id=160080,o.value_numeric,null)) as parity,
        max(if(o.concept_id=1823,o.value_numeric,null)) as parity_abortion,
        max(if(o.concept_id=160598,o.value_numeric,null)) as age_at_menarche,
        max(if(o.concept_id=1427,o.value_datetime,null)) as lmp,
        max(if(o.concept_id=162095,o.value_datetime,null)) as lmp_estimated,
        max(if(o.concept_id=5596,o.value_datetime,null)) as edd_ultrasound,
        max(if(o.concept_id=300,o.value_coded,null)) as blood_group,
        max(if(o.concept_id=299,o.value_coded,null)) as serology,
        max(if(o.concept_id=160108,o.value_coded,null)) as tb_screening,
        max(if(o.concept_id=32,o.value_coded,null)) as bs_for_mps,
        max(if(o.concept_id=159427,o.value_coded,null)) as hiv_status,
        max(if(o.concept_id=160554,o.value_datetime,null)) as hiv_test_date,
        max(if(o.concept_id=1436,o.value_coded,null)) as partner_hiv_status,
        max(if(o.concept_id=160082,o.value_datetime,null)) as partner_hiv_test_date,
        max(if(o.concept_id=159599,o.value_datetime,null)) as ti_date_started_art,
        max(if(o.concept_id = 164855,o.value_coded,null)) as ti_curent_regimen,
        max(if(o.concept_id=162724,o.value_text,null)) as ti_care_facility,
        max(if(o.concept_id=56,o.value_text,null)) as urine_microscopy,
        max(if(o.concept_id=1875,o.value_coded,null)) as urinary_albumin,
        max(if(o.concept_id=159734,o.value_coded,null)) as glucose_measurement,
        max(if(o.concept_id=161438,o.value_numeric,null)) as urine_ph,
        max(if(o.concept_id=161439,o.value_numeric,null)) as urine_gravity,
        max(if(o.concept_id=161440,o.value_coded,null)) as urine_nitrite_test,
        max(if(o.concept_id=161441,o.value_coded,null)) as urine_leukocyte_esterace_test,
        max(if(o.concept_id=161442,o.value_coded,null)) as urinary_ketone,
        max(if(o.concept_id=161444,o.value_coded,null)) as urine_bile_salt_test,
        max(if(o.concept_id=161443,o.value_coded,null)) as urine_bile_pigment_test,
        max(if(o.concept_id=162106,o.value_coded,null)) as urine_colour,
        max(if(o.concept_id=162101,o.value_coded,null)) as urine_turbidity,
        max(if(o.concept_id=162096,o.value_coded,null)) as urine_dipstick_for_blood,
        -- max(if(o.concept_id=161655,o.value_text,null)) as date_of_discontinuation,
        max(if(o.concept_id=161555,o.value_coded,null)) as discontinuation_reason,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(163530,163547,5624,160080,1823,160598,1427,162095,5596,300,299,160108,32,159427,160554,1436,160082,159599,164855,162724,56,1875,159734,161438,161439,161440,161441,161442,161444,161443,162106,162101,162096,161555,160478)
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('3ee036d8-7c13-4393-b5d6-036f2fe45126')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),service_type=VALUES(service_type),anc_number=VALUES(anc_number),first_anc_visit_date=VALUES(first_anc_visit_date),gravida=VALUES(gravida),parity=VALUES(parity),parity_abortion=VALUES(parity_abortion),age_at_menarche=VALUES(age_at_menarche),lmp=VALUES(lmp),lmp_estimated=VALUES(lmp_estimated),
      edd_ultrasound=VALUES(edd_ultrasound),blood_group=VALUES(blood_group),serology=VALUES(serology),tb_screening=VALUES(tb_screening),bs_for_mps=VALUES(bs_for_mps),hiv_status=VALUES(hiv_status),hiv_test_date=VALUES(hiv_status),partner_hiv_status=VALUES(partner_hiv_status),partner_hiv_test_date=VALUES(partner_hiv_test_date),
      ti_date_started_art=VALUES(ti_date_started_art),ti_curent_regimen=VALUES(ti_curent_regimen),ti_care_facility=VALUES(ti_care_facility),
      urine_microscopy=VALUES(urine_microscopy),urinary_albumin=VALUES(urinary_albumin),glucose_measurement=VALUES(glucose_measurement),urine_ph=VALUES(urine_ph),urine_gravity=VALUES(urine_gravity),urine_nitrite_test=VALUES(urine_nitrite_test),urine_leukocyte_esterace_test=VALUES(urine_leukocyte_esterace_test),urinary_ketone=VALUES(urinary_ketone),
      urine_bile_salt_test=VALUES(urine_bile_salt_test),urine_bile_pigment_test=VALUES(urine_bile_pigment_test),urine_colour=VALUES(urine_colour),urine_turbidity=VALUES(urine_turbidity),urine_dipstick_for_blood=VALUES(urine_dipstick_for_blood),discontinuation_reason=VALUES(discontinuation_reason)
    ;

    END $$

-- ------------- update etl_mch_antenatal_visit-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_mch_antenatal_visit $$
CREATE PROCEDURE sp_update_etl_mch_antenatal_visit(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_mch_antenatal_visit(
      patient_id,
      uuid,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      provider,
      anc_visit_number,
      temperature,
      pulse_rate,
      systolic_bp,
      diastolic_bp,
      respiratory_rate,
      oxygen_saturation,
      weight,
      height,
      muac,
      hemoglobin,
      breast_exam_done,
      pallor,
      maturity,
      fundal_height,
      fetal_presentation,
      lie,
      fetal_heart_rate,
      fetal_movement,
      who_stage,
      cd4,
      vl_sample_taken,
      viral_load,
      ldl,
      arv_status,
      final_test_result,
      patient_given_result,
      partner_hiv_tested,
      partner_hiv_status,
      prophylaxis_given,
      haart_given,
      date_given_haart,
      baby_azt_dispensed,
      baby_nvp_dispensed,
      deworming_done_anc,
      IPT_dose_given_anc,
      TTT,
      IPT_malaria,
      iron_supplement,
      deworming,
      bed_nets,
      urine_microscopy,
      urinary_albumin,
      glucose_measurement,
      urine_ph,
      urine_gravity,
      urine_nitrite_test,
      urine_leukocyte_esterace_test,
      urinary_ketone,
      urine_bile_salt_test,
      urine_bile_pigment_test,
      urine_colour,
      urine_turbidity,
      urine_dipstick_for_blood,
      syphilis_test_status,
      syphilis_treated_status,
      bs_mps,
      diabetes_test,
      fgm_done,
      fgm_complications,
      fp_method_postpartum,
      anc_exercises,
      tb_screening,
      cacx_screening,
      cacx_screening_method,
      hepatitis_b_screening,
      hepatitis_b_treatment,
      has_other_illnes,
      counselled,
      counselled_on_birth_plans,
      counselled_on_danger_signs,
      counselled_on_family_planning,
      counselled_on_hiv,
      counselled_on_supplimental_feeding,
      counselled_on_breast_care,
      counselled_on_infant_feeding,
      counselled_on_treated_nets,
      minimum_care_package,
      risk_reduction,
      partner_testing,
      sti_screening,
      condom_provision,
      prep_adherence,
      anc_visits_emphasis,
      pnc_fp_counseling,
      referral_vmmc,
      referral_dreams,
      referred_from,
      referred_to,
      next_appointment_date,
      clinical_notes,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.visit_id,
        date(e.encounter_datetime) visit_date,
        e.location_id,
        e.encounter_id,
        e.creator,
        max(if(o.concept_id=1425,o.value_numeric,null)) as anc_visit_number,
        max(if(o.concept_id=5088,o.value_numeric,null)) as temperature,
        max(if(o.concept_id=5087,o.value_numeric,null)) as pulse_rate,
        max(if(o.concept_id=5085,o.value_numeric,null)) as systolic_bp,
        max(if(o.concept_id=5086,o.value_numeric,null)) as diastolic_bp,
        max(if(o.concept_id=5242,o.value_numeric,null)) as respiratory_rate,
        max(if(o.concept_id=5092,o.value_numeric,null)) as oxygen_saturation,
        max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
        max(if(o.concept_id=5090,o.value_numeric,null)) as height,
        max(if(o.concept_id=1343,o.value_numeric,null)) as muac,
        max(if(o.concept_id=21,o.value_numeric,null)) as hemoglobin,
        max(if(o.concept_id=163590,o.value_coded,null)) as breast_exam_done,
        max(if(o.concept_id=5245,o.value_coded,null)) as pallor,
        max(if(o.concept_id=1438,o.value_numeric,null)) as maturity,
        max(if(o.concept_id=1439,o.value_numeric,null)) as fundal_height,
        max(if(o.concept_id=160090,o.value_coded,null)) as fetal_presentation,
        max(if(o.concept_id=162089,o.value_coded,null)) as lie,
        max(if(o.concept_id=1440,o.value_numeric,null)) as fetal_heart_rate,
        max(if(o.concept_id=162107,o.value_coded,null)) as fetal_movement,
        max(if(o.concept_id=5356,o.value_coded,null)) as who_stage,
        max(if(o.concept_id=5497,o.value_numeric,null)) as cd4,
        max(if(o.concept_id=1271,o.value_coded,null)) as vl_sample_taken,
        max(if(o.concept_id=856,o.value_numeric,null)) as viral_load,
        max(if(o.concept_id=1305,o.value_coded,null)) as ldl,
        max(if(o.concept_id=1147,o.value_coded,null)) as arv_status,
        max(if(o.concept_id=159427,(case o.value_coded when 703 then "Positive" when 664 then "Negative" when 1138 then "Inconclusive" else "" end),null)) as final_test_result,
        max(if(o.concept_id=164848,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as patient_given_result,
        max(if(o.concept_id=161557,o.value_coded,null)) as partner_hiv_tested,
        max(if(o.concept_id=1436,o.value_coded,null)) as partner_hiv_status,
        max(if(o.concept_id=1109,o.value_coded,null)) as prophylaxis_given,
        max(if(o.concept_id=5576,o.value_coded,null)) as haart_given,
        max(if(o.concept_id=163784,o.value_datetime,null)) as date_given_haart,
        max(if(o.concept_id=1282 and o.value_coded = 160123,o.value_coded,null)) as baby_azt_dispensed,
        max(if(o.concept_id=1282 and o.value_coded = 80586,o.value_coded,null)) as baby_nvp_dispensed,
        max(if(o.concept_id=159922,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as deworming_done_anc,
        max(if(concept_id=1418, value_numeric, null)) as IPT_dose_given_anc,
        max(if(o.concept_id=984,(case o.value_coded when 84879 then "Yes" else "" end),null)) as TTT,
        max(if(o.concept_id=984,(case o.value_coded when 159610 then "Yes" else "" end),null)) as IPT_malaria,
        max(if(o.concept_id=984,(case o.value_coded when 104677 then "Yes" else "" end),null)) as iron_supplement,
        max(if(o.concept_id=984,(case o.value_coded when 79413 then "Yes"  else "" end),null)) as deworming,
        max(if(o.concept_id=984,(case o.value_coded when 160428 then "Yes" else "" end),null)) as bed_nets,
        max(if(o.concept_id=56,o.value_text,null)) as urine_microscopy,
        max(if(o.concept_id=1875,o.value_coded,null)) as urinary_albumin,
        max(if(o.concept_id=159734,o.value_coded,null)) as glucose_measurement,
        max(if(o.concept_id=161438,o.value_numeric,null)) as urine_ph,
        max(if(o.concept_id=161439,o.value_numeric,null)) as urine_gravity,
        max(if(o.concept_id=161440,o.value_coded,null)) as urine_nitrite_test,
        max(if(o.concept_id=161441,o.value_coded,null)) as urine_leukocyte_esterace_test,
        max(if(o.concept_id=161442,o.value_coded,null)) as urinary_ketone,
        max(if(o.concept_id=161444,o.value_coded,null)) as urine_bile_salt_test,
        max(if(o.concept_id=161443,o.value_coded,null)) as urine_bile_pigment_test,
        max(if(o.concept_id=162106,o.value_coded,null)) as urine_colour,
        max(if(o.concept_id=162101,o.value_coded,null)) as urine_turbidity,
        max(if(o.concept_id=162096,o.value_coded,null)) as urine_dipstick_for_blood,
        max(if(o.concept_id=299,o.value_coded,null)) as syphilis_test_status,
        max(if(o.concept_id=159918,o.value_coded,null)) as syphilis_treated_status,
        max(if(o.concept_id=32,o.value_coded,null)) as bs_mps,
        max(if(o.concept_id=119481,o.value_coded,null)) as diabetes_test,
        max(if(o.concept_id=165099,o.value_coded,null)) as fgm_done,
        max(if(o.concept_id=120198,o.value_coded,null)) as fgm_complications,
        max(if(o.concept_id=374,o.value_coded,null)) as fp_method_postpartum,
        max(if(o.concept_id=161074,o.value_coded,null)) as anc_exercises,
        max(if(o.concept_id=1659,o.value_coded,null)) as tb_screening,
        max(if(o.concept_id=164934,o.value_coded,null)) as cacx_screening,
        max(if(o.concept_id=163589,o.value_coded,null)) as cacx_screening_method,
        max(if(o.concept_id=165040,o.value_coded,null)) as hepatitis_b_screening,
        max(if(o.concept_id=166665,o.value_coded,null)) as hepatitis_b_treatment,
        max(if(o.concept_id=162747,o.value_coded,null)) as has_other_illnes,
        max(if(o.concept_id=1912,o.value_coded,null)) as counselled,
        max(if(o.concept_id=159853 and o.value_coded=159758,o.value_coded,null)) counselled_on_birth_plans,
        max(if(o.concept_id=159853 and o.value_coded=159857,o.value_coded,null)) counselled_on_danger_signs,
        max(if(o.concept_id=159853 and o.value_coded=156277,o.value_coded,null)) counselled_on_family_planning,
        max(if(o.concept_id=159853 and o.value_coded=1914,o.value_coded,null)) counselled_on_hiv,
        max(if(o.concept_id=159853 and o.value_coded=159854,o.value_coded,null)) counselled_on_supplimental_feeding,
        max(if(o.concept_id=159853 and o.value_coded=159856,o.value_coded,null)) counselled_on_breast_care,
        max(if(o.concept_id=159853 and o.value_coded=161651,o.value_coded,null)) counselled_on_infant_feeding,
        max(if(o.concept_id=159853 and o.value_coded=1381,o.value_coded,null)) counselled_on_treated_nets,
        max(if(o.concept_id=165302,o.value_coded,null)) as minimum_care_package,
        max(if(o.concept_id=1592 and o.value_coded=165275,o.value_coded,null)) risk_reduction,
        max(if(o.concept_id=1592 and o.value_coded=161557,o.value_coded,null)) partner_testing,
        max(if(o.concept_id=1592 and o.value_coded=165190,o.value_coded,null)) sti_screening,
        max(if(o.concept_id=1592 and o.value_coded=159777,o.value_coded,null)) condom_provision,
        max(if(o.concept_id=1592 and o.value_coded=165203,o.value_coded,null)) prep_adherence,
        max(if(o.concept_id=1592 and o.value_coded=165475,o.value_coded,null)) anc_visits_emphasis,
        max(if(o.concept_id=1592 and o.value_coded=1382,o.value_coded,null)) pnc_fp_counseling,
        max(if(o.concept_id=1592 and o.value_coded=162223,o.value_coded,null)) referral_vmmc,
        max(if(o.concept_id=1592 and o.value_coded=165368,o.value_coded,null)) referral_dreams,
        max(if(o.concept_id=160481,o.value_coded,null)) as referred_from,
        max(if(o.concept_id=163145,o.value_coded,null)) as referred_to,
        max(if(o.concept_id=5096,o.value_datetime,null)) as next_appointment_date,
        max(if(o.concept_id=159395,o.value_text,null)) as clinical_notes,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(1282,159922,984,1418,1425,5088,5087,5085,5086,5242,5092,5089,5090,1343,21,163590,5245,1438,1439,160090,162089,1440,162107,5356,5497,856,1305,1147,159427,164848,161557,1436,1109,5576,128256,1875,159734,161438,161439,161440,161441,161442,161444,161443,162106,162101,162096,299,159918,32,119481,165099,120198,374,161074,1659,164934,163589,165040,166665,162747,1912,160481,163145,5096,159395,163784,1271,159853,165302,1592)
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('e8f98494-af35-4bb8-9fc7-c409c8fed843','d3ea25c7-a3e8-4f57-a6a9-e802c3565a30')
        ) f on f.form_id=e.form_id
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time

      group by e.patient_id,visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),provider=VALUES(provider),anc_visit_number=VALUES(anc_visit_number),temperature=VALUES(temperature),pulse_rate=VALUES(pulse_rate),systolic_bp=VALUES(systolic_bp),diastolic_bp=VALUES(diastolic_bp),respiratory_rate=VALUES(respiratory_rate),
      oxygen_saturation=VALUES(oxygen_saturation),
      weight=VALUES(weight),height=VALUES(height),muac=VALUES(muac),hemoglobin=VALUES(hemoglobin),breast_exam_done=VALUES(breast_exam_done),pallor=VALUES(pallor),maturity=VALUES(maturity),fundal_height=VALUES(fundal_height),fetal_presentation=VALUES(fetal_presentation),lie=VALUES(lie),
      fetal_heart_rate=VALUES(fetal_heart_rate),fetal_movement=VALUES(fetal_movement),
      who_stage=VALUES(who_stage),cd4=VALUES(cd4),vl_sample_taken=VALUES(vl_sample_taken),viral_load=VALUES(viral_load),ldl=VALUES(ldl),arv_status=VALUES(arv_status),final_test_result=VALUES(final_test_result),
      patient_given_result=VALUES(patient_given_result),
      partner_hiv_tested=VALUES(partner_hiv_tested),partner_hiv_status=VALUES(partner_hiv_status),prophylaxis_given=VALUES(prophylaxis_given),haart_given=VALUES(haart_given),date_given_haart=VALUES(date_given_haart),baby_azt_dispensed=VALUES(baby_azt_dispensed),baby_nvp_dispensed=VALUES(baby_nvp_dispensed),deworming_done_anc=VALUES(deworming_done_anc),
      TTT=VALUES(TTT),IPT_dose_given_anc=VALUES(IPT_dose_given_anc),IPT_malaria=VALUES(IPT_malaria),
      iron_supplement=VALUES(iron_supplement),deworming=VALUES(deworming),bed_nets=VALUES(bed_nets),urine_microscopy=VALUES(urine_microscopy),urinary_albumin=VALUES(urinary_albumin),glucose_measurement=VALUES(glucose_measurement),urine_ph=VALUES(urine_ph),urine_gravity=VALUES(urine_gravity),
      urine_nitrite_test=VALUES(urine_nitrite_test),
      urine_leukocyte_esterace_test=VALUES(urine_leukocyte_esterace_test),urinary_ketone=VALUES(urinary_ketone),urine_bile_salt_test=VALUES(urine_bile_salt_test),
      urine_bile_pigment_test=VALUES(urine_bile_pigment_test),urine_colour=VALUES(urine_colour),urine_turbidity=VALUES(urine_turbidity),urine_dipstick_for_blood=VALUES(urine_dipstick_for_blood),syphilis_test_status=VALUES(syphilis_test_status),syphilis_treated_status=VALUES(syphilis_treated_status),
      bs_mps=VALUES(bs_mps),diabetes_test=VALUES(diabetes_test),fgm_done=VALUES(fgm_done),fgm_complications=VALUES(fgm_complications),fp_method_postpartum=VALUES(fp_method_postpartum),anc_exercises=VALUES(anc_exercises),tb_screening=VALUES(tb_screening),
      cacx_screening=VALUES(cacx_screening),cacx_screening_method=VALUES(cacx_screening_method),hepatitis_b_screening=VALUES(hepatitis_b_screening),hepatitis_b_treatment=VALUES(hepatitis_b_treatment),has_other_illnes=VALUES(has_other_illnes),counselled=VALUES(counselled),
      counselled_on_birth_plans=VALUES(counselled_on_birth_plans),counselled_on_danger_signs=VALUES(counselled_on_danger_signs),counselled_on_family_planning=VALUES(counselled_on_family_planning),counselled_on_hiv=VALUES(counselled_on_hiv),counselled_on_supplimental_feeding=VALUES(counselled_on_supplimental_feeding),
      counselled_on_breast_care=VALUES(counselled_on_breast_care),counselled_on_infant_feeding=VALUES(counselled_on_infant_feeding),counselled_on_treated_nets=VALUES(counselled_on_treated_nets),referred_from=VALUES(referred_from),
      minimum_care_package=VALUES(minimum_care_package),risk_reduction=VALUES(risk_reduction),partner_testing=VALUES(partner_testing),sti_screening=VALUES(sti_screening),condom_provision=VALUES(condom_provision),prep_adherence=VALUES(prep_adherence),anc_visits_emphasis=VALUES(anc_visits_emphasis),pnc_fp_counseling=VALUES(pnc_fp_counseling),
      referral_vmmc=VALUES(referral_vmmc),referral_dreams=VALUES(referral_dreams),referred_to=VALUES(referred_to),next_appointment_date=VALUES(next_appointment_date),clinical_notes=VALUES(clinical_notes)
    ;

    END $$

-- ------------- update etl_mchs_delivery-------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_mch_delivery $$
CREATE PROCEDURE sp_update_etl_mch_delivery(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_mchs_delivery(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      number_of_anc_visits,
      vaginal_examination,
      uterotonic_given,
      chlohexidine_applied_on_code_stump,
      vitamin_K_given,
      kangaroo_mother_care_given,
      testing_done_in_the_maternity_hiv_status,
      infant_provided_with_arv_prophylaxis,
      mother_on_haart_during_anc,
      mother_started_haart_at_maternity,
      vdrl_rpr_results,
      date_of_last_menstrual_period,
      estimated_date_of_delivery,
      reason_for_referral,
      admission_number,
      duration_of_pregnancy,
      mode_of_delivery,
      date_of_delivery,
      blood_loss,
      condition_of_mother,
      delivery_outcome,
      apgar_score_1min,
      apgar_score_5min,
      apgar_score_10min,
      resuscitation_done,
      place_of_delivery,
      delivery_assistant,
      counseling_on_infant_feeding ,
      counseling_on_exclusive_breastfeeding,
      counseling_on_infant_feeding_for_hiv_infected,
      mother_decision,
      placenta_complete,
      maternal_death_audited,
      cadre,
      delivery_complications,
      coded_delivery_complications,
      other_delivery_complications,
      duration_of_labor,
      baby_sex,
      baby_condition,
      teo_given,
      birth_weight,
      bf_within_one_hour,
      birth_with_deformity,
      final_test_result,
      patient_given_result,
      partner_hiv_tested,
      partner_hiv_status,
      prophylaxis_given,
      baby_azt_dispensed,
      baby_nvp_dispensed,
      clinical_notes
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=1590,o.value_numeric,null)) as number_of_anc_visits,
        max(if(o.concept_id=160704,o.value_coded,null)) as vaginal_examination,
        max(if(o.concept_id=1282 and o.value_coded in (81369,104590,1107),o.value_coded,null)) as uterotonic_given,
        max(if(o.concept_id=159369,o.value_coded,null)) as chlohexidine_applied_on_code_stump,
        max(if(o.concept_id=984,o.value_coded,null)) as vitamin_K_given,
        max(if(o.concept_id=161094,o.value_coded,null)) as kangaroo_mother_care_given,
        max(if(o.concept_id=1396,o.value_coded,null)) as testing_done_in_the_maternity_hiv_status,
        max(if(o.concept_id=161930,o.value_coded,null)) as infant_provided_with_arv_prophylaxis,
        max(if(o.concept_id=163783,o.value_coded,null)) as mother_on_haart_during_anc,
        max(if(o.concept_id=166665,o.value_coded,null)) as mother_started_haart_at_maternity,
        max(if(o.concept_id=299,o.value_coded,null)) as vdrl_rpr_results,
        max(if(o.concept_id=1427,o.value_datetime,null)) as date_of_last_menstrual_period,
        max(if(o.concept_id=5596,o.value_datetime,null)) as estimated_date_of_delivery,
        max(if(o.concept_id=164359,o.value_text,null)) as reason_for_referral,
        max(if(o.concept_id=162054,o.value_text,null)) as admission_number,
        max(if(o.concept_id=1789,o.value_numeric,null)) as duration_of_pregnancy,
        max(if(o.concept_id=5630,o.value_coded,null)) as mode_of_delivery,
        max(if(o.concept_id=5599,o.value_datetime,null)) as date_of_delivery,
        max(if(o.concept_id=162092,o.value_coded,null)) as blood_loss,
        max(if(o.concept_id=1856,o.value_coded,null)) as condition_of_mother,
        max(if(o.concept_id=159949,o.value_coded,null)) as delivery_outcome,
        max(if(o.concept_id=159603,o.value_numeric,null)) as apgar_score_1min,
        max(if(o.concept_id=159604,o.value_numeric,null)) as apgar_score_5min,
        max(if(o.concept_id=159605,o.value_numeric,null)) as apgar_score_10min,
        max(if(o.concept_id=162131,o.value_coded,null)) as resuscitation_done,
        max(if(o.concept_id=1572,o.value_coded,null)) as place_of_delivery,
        max(if(o.concept_id=1473,o.value_text,null)) as delivery_assistant,
        max(if(o.concept_id=1379 and o.value_coded=161651,o.value_coded,null)) as counseling_on_infant_feeding,
        max(if(o.concept_id=1379 and o.value_coded=161096,o.value_coded,null)) as counseling_on_exclusive_breastfeeding,
        max(if(o.concept_id=1379 and o.value_coded=162091,o.value_coded,null)) as counseling_on_infant_feeding_for_hiv_infected,
        max(if(o.concept_id=1151,o.value_coded,null)) as mother_decision,
        max(if(o.concept_id=163454,o.value_coded,null)) as placenta_complete,
        max(if(o.concept_id=1602,o.value_coded,null)) as maternal_death_audited,
        max(if(o.concept_id=1573,o.value_coded,null)) as cadre,
        max(if(o.concept_id=120216,o.value_coded,null)) as delivery_complications,
        max(if(o.concept_id=1576,o.value_coded,null)) as coded_delivery_complications,
        max(if(o.concept_id=162093,o.value_text,null)) as other_delivery_complications,
        max(if(o.concept_id=159616,o.value_numeric,null)) as duration_of_labor,
        max(if(o.concept_id=1587,o.value_coded,null)) as baby_sex,
        max(if(o.concept_id=159917,o.value_coded,null)) as baby_condition,
        max(if(o.concept_id=1282 and o.value_coded = 84893,1,0)) as teo_given,
        max(if(o.concept_id=5916,o.value_numeric,null)) as birth_weight,
        max(if(o.concept_id=161543,o.value_coded,null)) as bf_within_one_hour,
        max(if(o.concept_id=164122,o.value_coded,null)) as birth_with_deformity,
        max(if(o.concept_id=159427,(case o.value_coded when 703 then "Positive" when 664 then "Negative" when 1138 then "Inconclusive" else "" end),null)) as final_test_result,
        max(if(o.concept_id=164848,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as patient_given_result,
        max(if(o.concept_id=161557,o.value_coded,null)) as partner_hiv_tested,
        max(if(o.concept_id=1436,o.value_coded,null)) as partner_hiv_status,
        max(if(o.concept_id=1109,o.value_coded,null)) as prophylaxis_given,
        max(if(o.concept_id = 1282 and o.value_coded = 160123,1,0)) as baby_azt_dispensed,
        max(if(o.concept_id = 1282 and o.value_coded = 80586,1,0)) as baby_nvp_dispensed,
        max(if(o.concept_id=159395,o.value_text,null)) as clinical_notes

      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(162054,1590,160704,1282,159369,984,161094,1396,161930,163783,166665,299,1427,5596,164359,1789,5630,5599,162092,1856,159603,159604,159605,162131,1572,1473,1379,1151,163454,1602,1573,162093,1576,120216,159616,1587,159917,1282,5916,161543,164122,159427,164848,161557,1436,1109,5576,159595,163784,159395,159949)
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('496c7cc3-0eea-4e84-a04c-2292949e2f7f')
        ) f on f.form_id=e.form_id

      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE provider=VALUES(provider),visit_id=VALUES(visit_id),visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),number_of_anc_visits=VALUES(number_of_anc_visits),vaginal_examination=VALUES(vaginal_examination),uterotonic_given=VALUES(uterotonic_given),chlohexidine_applied_on_code_stump=VALUES(chlohexidine_applied_on_code_stump),vitamin_K_given=VALUES(vitamin_K_given),
       kangaroo_mother_care_given=VALUES(kangaroo_mother_care_given),testing_done_in_the_maternity_hiv_status=VALUES(testing_done_in_the_maternity_hiv_status),infant_provided_with_arv_prophylaxis=VALUES(infant_provided_with_arv_prophylaxis),mother_on_haart_during_anc=VALUES(mother_on_haart_during_anc),mother_started_haart_at_maternity=VALUES(mother_started_haart_at_maternity),vdrl_rpr_results=VALUES(vdrl_rpr_results),date_of_last_menstrual_period=VALUES(date_of_last_menstrual_period),estimated_date_of_delivery=VALUES(estimated_date_of_delivery),
       reason_for_referral=VALUES(reason_for_referral),date_created=VALUES(date_created),admission_number=VALUES(admission_number),duration_of_pregnancy=VALUES(duration_of_pregnancy),mode_of_delivery=VALUES(mode_of_delivery),date_of_delivery=VALUES(date_of_delivery),blood_loss=VALUES(blood_loss),condition_of_mother=VALUES(condition_of_mother),
      apgar_score_1min=VALUES(apgar_score_1min),apgar_score_5min=VALUES(apgar_score_5min),apgar_score_10min=VALUES(apgar_score_10min),resuscitation_done=VALUES(resuscitation_done),place_of_delivery=VALUES(place_of_delivery),delivery_assistant=VALUES(delivery_assistant),counseling_on_infant_feeding=VALUES(counseling_on_infant_feeding) ,counseling_on_exclusive_breastfeeding=VALUES(counseling_on_exclusive_breastfeeding),
      counseling_on_infant_feeding_for_hiv_infected=VALUES(counseling_on_infant_feeding_for_hiv_infected),mother_decision=VALUES(mother_decision),placenta_complete=VALUES(placenta_complete),maternal_death_audited=VALUES(maternal_death_audited),cadre=VALUES(cadre),delivery_complications=VALUES(delivery_complications),coded_delivery_complications=VALUES(coded_delivery_complications),other_delivery_complications=VALUES(other_delivery_complications),duration_of_labor=VALUES(duration_of_labor),baby_sex=VALUES(baby_sex),
      baby_condition=VALUES(baby_condition),teo_given=VALUES(teo_given),birth_weight=VALUES(birth_weight),bf_within_one_hour=VALUES(bf_within_one_hour),birth_with_deformity=VALUES(birth_with_deformity),
      final_test_result=VALUES(final_test_result),patient_given_result=VALUES(patient_given_result),partner_hiv_tested=VALUES(partner_hiv_tested),partner_hiv_status=VALUES(partner_hiv_status),prophylaxis_given=VALUES(prophylaxis_given)
      ,baby_azt_dispensed=VALUES(baby_azt_dispensed),baby_nvp_dispensed=VALUES(baby_nvp_dispensed),clinical_notes=VALUES(clinical_notes),delivery_outcome=VALUES(delivery_outcome)

    ;

    END $$
-- ------------- populate etl_mchs_discharge-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_mch_discharge $$
CREATE PROCEDURE sp_update_etl_mch_discharge(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing MCH Discharge ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_mchs_discharge(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      counselled_on_feeding,
      baby_status,
      vitamin_A_dispensed,
      birth_notification_number,
      condition_of_mother,
      discharge_date,
      referred_from,
      referred_to,
      clinical_notes
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=161651,o.value_coded,null)) as counselled_on_feeding,
        max(if(o.concept_id=159926,o.value_coded,null)) as baby_status,
        max(if(o.concept_id=161534,o.value_coded,null)) as vitamin_A_dispensed,
        max(if(o.concept_id=162051,o.value_text,null)) as birth_notification_number,
        max(if(o.concept_id=162093,o.value_text,null)) as condition_of_mother,
        max(if(o.concept_id=1641,o.value_datetime,null)) as discharge_date,
        max(if(o.concept_id=160481,o.value_coded,null)) as referred_from,
        max(if(o.concept_id=163145,o.value_coded,null)) as referred_to,
        max(if(o.concept_id=159395,o.value_text,null)) as clinical_notes
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(161651,159926,161534,162051,162093,1641,160481,163145,159395)
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('af273344-a5f9-11e8-98d0-529269fb1459')
        ) f on f.form_id=e.form_id

      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time

      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),provider=VALUES(provider),counselled_on_feeding=VALUES(counselled_on_feeding),baby_status=VALUES(baby_status),vitamin_A_dispensed=VALUES(vitamin_A_dispensed),birth_notification_number=VALUES(birth_notification_number),
      condition_of_mother=VALUES(condition_of_mother),discharge_date=VALUES(discharge_date),referred_from=VALUES(referred_from),referred_to=VALUES(referred_to), clinical_notes=VALUES(clinical_notes)
    ;

    SELECT "Completed processing MCH Discharge visits", CONCAT("Time: ", NOW());
    END $$

-- ------------- update etl_mch_postnatal_visit-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_mch_postnatal_visit $$
CREATE PROCEDURE sp_update_etl_mch_postnatal_visit(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_mch_postnatal_visit(
      patient_id,
      uuid,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      provider,
      pnc_register_no,
      pnc_visit_no,
      delivery_date,
      mode_of_delivery,
      place_of_delivery,
      visit_timing_mother,
      visit_timing_baby,
      delivery_outcome,
      temperature,
      pulse_rate,
      systolic_bp,
      diastolic_bp,
      respiratory_rate,
      oxygen_saturation,
      weight,
      height,
      muac,
      hemoglobin,
      arv_status,
      general_condition,
      breast,
      cs_scar,
      gravid_uterus,
      episiotomy,
      lochia,
      counselled_on_infant_feeding,
      pallor,
      pallor_severity,
      pph,
      mother_hiv_status,
      condition_of_baby,
      baby_feeding_method,
      umblical_cord,
      baby_immunization_started,
      family_planning_counseling,
      uterus_examination,
      uterus_cervix_examination,
      vaginal_examination,
      parametrial_examination,
      external_genitalia_examination,
      ovarian_examination,
      pelvic_lymph_node_exam,
      final_test_result,
      patient_given_result,
      couple_counselled,
      partner_hiv_tested,
      partner_hiv_status,
      mother_haart_given,
      prophylaxis_given,
      infant_prophylaxis_timing,
      baby_azt_dispensed,
      baby_nvp_dispensed,
      pnc_exercises,
      maternal_condition,
      iron_supplementation,
      fistula_screening,
      cacx_screening,
      cacx_screening_method,
      family_planning_status,
      family_planning_method,
      referred_from,
      referred_to,
      clinical_notes,
      appointment_date,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.creator,
        max(if(o.concept_id=1646,o.value_text,null)) as pnc_register_no,
        max(if(o.concept_id=159893,o.value_numeric,null)) as pnc_visit_no,
        max(if(o.concept_id=5599,o.value_datetime,null)) as delivery_date,
        max(if(o.concept_id=5630,o.value_coded,null)) as mode_of_delivery,
        max(if(o.concept_id=1572,o.value_coded,null)) as place_of_delivery,
        max(if(o.concept_id=1724,o.value_coded,null)) as visit_timing_mother,
        max(if(o.concept_id=167017,o.value_coded,null)) as visit_timing_baby,
        max(if(o.concept_id=159949,o.value_coded,null)) as delivery_outcome,
        max(if(o.concept_id=5088,o.value_numeric,null)) as temperature,
        max(if(o.concept_id=5087,o.value_numeric,null)) as pulse_rate,
        max(if(o.concept_id=5085,o.value_numeric,null)) as systolic_bp,
        max(if(o.concept_id=5086,o.value_numeric,null)) as diastolic_bp,
        max(if(o.concept_id=5242,o.value_numeric,null)) as respiratory_rate,
        max(if(o.concept_id=5092,o.value_numeric,null)) as oxygen_saturation,
        max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
        max(if(o.concept_id=5090,o.value_numeric,null)) as height,
        max(if(o.concept_id=1343,o.value_numeric,null)) as muac,
        max(if(o.concept_id=21,o.value_numeric,null)) as hemoglobin,
        max(if(o.concept_id=1147,o.value_coded,null)) as arv_status,
        max(if(o.concept_id=1856,o.value_coded,null)) as general_condition,
        max(if(o.concept_id=159780,o.value_coded,null)) as breast,
        max(if(o.concept_id=162128,o.value_coded,null)) as cs_scar,
        max(if(o.concept_id=162110,o.value_coded,null)) as gravid_uterus,
        max(if(o.concept_id=159840,o.value_coded,null)) as episiotomy,
        max(if(o.concept_id=159844,o.value_coded,null)) as lochia,
        max(if(o.concept_id=161651,o.value_coded,null)) as counselled_on_infant_feeding,
        max(if(o.concept_id=5245,o.value_coded,null)) as pallor,
        max(if(o.concept_id=162642,o.value_coded,null)) as pallor_severity,
        max(if(o.concept_id=230,o.value_coded,null)) as pph,
        max(if(o.concept_id=1396,o.value_coded,null)) as mother_hiv_status,
        max(if(o.concept_id=162134,o.value_coded,null)) as condition_of_baby,
        max(if(o.concept_id=1151,o.value_coded,null)) as baby_feeding_method,
        max(if(o.concept_id=162121,o.value_coded,null)) as umblical_cord,
        max(if(o.concept_id=162127,o.value_coded,null)) as baby_immunization_started,
        max(if(o.concept_id=1382,o.value_coded,null)) as family_planning_counseling,
        max(if(o.concept_id=163742,o.value_coded,null)) as uterus_examination,
        max(if(o.concept_id=160968,o.value_text,null)) as uterus_cervix_examination,
        max(if(o.concept_id=160969,o.value_text,null)) as vaginal_examination,
        max(if(o.concept_id=160970,o.value_text,null)) as parametrial_examination,
        max(if(o.concept_id=160971,o.value_text,null)) as external_genitalia_examination,
        max(if(o.concept_id=160975,o.value_text,null)) as ovarian_examination,
        max(if(o.concept_id=160972,o.value_text,null)) as pelvic_lymph_node_exam,
        max(if(o.concept_id=159427,(case o.value_coded when 703 then "Positive" when 664 then "Negative" when 1138 then "Inconclusive" else "" end),null)) as final_test_result,
        max(if(o.concept_id=164848,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as patient_given_result,
        max(if(o.concept_id=165070,o.value_coded,null)) as couple_counselled,
        max(if(o.concept_id=161557,o.value_coded,null)) as partner_hiv_tested,
        max(if(o.concept_id=1436,o.value_coded,null)) as partner_hiv_status,
        max(if(o.concept_id=163783,o.value_coded,null)) as mother_haart_given,
        max(if(o.concept_id=1109,o.value_coded,null)) as prophylaxis_given,
        max(if(o.concept_id=166665,o.value_coded,null)) as infant_prophylaxis_timing,
        max(if(o.concept_id=1282,o.value_coded,null)) as baby_azt_dispensed,
        max(if(o.concept_id=1282,o.value_coded,null)) as baby_nvp_dispensed,
        max(if(o.concept_id=161074,o.value_coded,null)) as pnc_exercises,
        max(if(o.concept_id=160085,o.value_coded,null)) as maternal_condition,
        max(if(o.concept_id=161004,o.value_coded,null)) as iron_supplementation,
        max(if(o.concept_id=159921,o.value_coded,null)) as fistula_screening,
        max(if(o.concept_id=164934,o.value_coded,null)) as cacx_screening,
        max(if(o.concept_id=163589,o.value_coded,null)) as cacx_screening_method,
        max(if(o.concept_id=160653,o.value_coded,null)) as family_planning_status,
        max(if(o.concept_id=374,o.value_coded,null)) as family_planning_method,
        max(if(o.concept_id=160481,o.value_coded,null)) as referred_from,
        max(if(o.concept_id=163145,o.value_coded,null)) as referred_to,
        max(if(o.concept_id=159395,o.value_text,null)) as clinical_notes,
        max(if(o.concept_id=5096,o.value_datetime,null)) as appointment_date,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(1646,159893,5599,5630,1572,5088,5087,5085,5086,5242,5092,5089,5090,1343,21,1147,1856,159780,162128,162110,159840,159844,5245,230,1396,162134,1151,162121,162127,1382,163742,160968,160969,160970,160971,160975,160972,159427,164848,161557,1436,1109,5576,159595,163784,1282,161074,160085,161004,159921,164934,163589,160653,374,160481,163145,159395,159949,5096,161651,165070,
                                                1724,167017,163783,162642,166665)
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('72aa78e0-ee4b-47c3-9073-26f3b9ecc4a7')
        ) f on f.form_id= e.form_id
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time

      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),provider=VALUES(provider),pnc_register_no=VALUES(pnc_register_no),pnc_visit_no=VALUES(pnc_visit_no),delivery_date=VALUES(delivery_date),mode_of_delivery=VALUES(mode_of_delivery),place_of_delivery=VALUES(place_of_delivery),visit_timing_mother=VALUES(visit_timing_mother),visit_timing_baby=VALUES(visit_timing_baby),
      delivery_outcome=VALUES(delivery_outcome),temperature=VALUES(temperature),pulse_rate=VALUES(pulse_rate),systolic_bp=VALUES(systolic_bp),diastolic_bp=VALUES(diastolic_bp),respiratory_rate=VALUES(respiratory_rate),
      oxygen_saturation=VALUES(oxygen_saturation),weight=VALUES(weight),height=VALUES(height),muac=VALUES(muac),hemoglobin=VALUES(hemoglobin),arv_status=VALUES(arv_status),general_condition=VALUES(general_condition),breast=VALUES(breast),cs_scar=VALUES(cs_scar),gravid_uterus=VALUES(gravid_uterus),episiotomy=VALUES(episiotomy),
      lochia=VALUES(lochia),pallor=VALUES(pallor),pph=VALUES(pph),mother_hiv_status=VALUES(mother_hiv_status),condition_of_baby=VALUES(condition_of_baby),baby_feeding_method=VALUES(baby_feeding_method),umblical_cord=VALUES(umblical_cord),baby_immunization_started=VALUES(baby_immunization_started),family_planning_counseling=VALUES(family_planning_counseling),uterus_examination=VALUES(uterus_examination),
      uterus_cervix_examination=VALUES(uterus_cervix_examination),vaginal_examination=VALUES(vaginal_examination),parametrial_examination=VALUES(parametrial_examination),external_genitalia_examination=VALUES(external_genitalia_examination),ovarian_examination=VALUES(ovarian_examination),pelvic_lymph_node_exam=VALUES(pelvic_lymph_node_exam),
      final_test_result=VALUES(final_test_result),
      patient_given_result=VALUES(patient_given_result),couple_counselled=VALUES(couple_counselled),partner_hiv_tested=VALUES(partner_hiv_tested),partner_hiv_status=VALUES(partner_hiv_status),mother_haart_given=VALUES(mother_haart_given),prophylaxis_given=VALUES(prophylaxis_given),infant_prophylaxis_timing=VALUES(infant_prophylaxis_timing),baby_azt_dispensed=VALUES(baby_azt_dispensed),baby_nvp_dispensed=VALUES(baby_nvp_dispensed)
      ,maternal_condition=VALUES(maternal_condition),iron_supplementation=VALUES(iron_supplementation),fistula_screening=VALUES(fistula_screening),cacx_screening=VALUES(cacx_screening),cacx_screening_method=VALUES(cacx_screening_method),family_planning_status=VALUES(family_planning_status),family_planning_method=VALUES(family_planning_method)
      ,referred_from=VALUES(referred_from),referred_to=VALUES(referred_to), clinical_notes=VALUES(clinical_notes),appointment_date=VALUES(appointment_date),counselled_on_infant_feeding=VALUES(counselled_on_infant_feeding)
    ;

    END $$

-- ------------- update etl_hei_enrollment-------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_hei_enrolment $$
CREATE PROCEDURE sp_update_etl_hei_enrolment(IN last_update_time DATETIME)
  BEGIN

    insert into kenyaemr_etl.etl_hei_enrollment(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      child_exposed,
      -- hei_id_number,
      spd_number,
      birth_weight,
      gestation_at_birth,
      birth_type,
      date_first_seen,
      birth_notification_number,
      birth_certificate_number,
      need_for_special_care,
      reason_for_special_care,
      referral_source ,
      transfer_in,
      transfer_in_date,
      facility_transferred_from,
      district_transferred_from,
      date_first_enrolled_in_hei_care,
      -- arv_prophylaxis,
      mother_breastfeeding,
      -- mother_on_NVP_during_breastfeeding,
      TB_contact_history_in_household,
      -- infant_mother_link,
      mother_alive,
      mother_on_pmtct_drugs,
      mother_on_drug,
      mother_on_art_at_infant_enrollment,
      mother_drug_regimen,
      infant_prophylaxis,
      parent_ccc_number,
      mode_of_delivery,
      place_of_delivery,
      birth_length,
      birth_order,
      health_facility_name,
      date_of_birth_notification,
      date_of_birth_registration,
      birth_registration_place,
      permanent_registration_serial,
      mother_facility_registered,
      exit_date,
      exit_reason,
      hiv_status_at_exit,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.visit_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id,
        max(if(o.concept_id=5303,o.value_coded,null)) as child_exposed,
        -- max(if(o.concept_id=5087,o.value_numeric,null)) as hei_id_number,
        max(if(o.concept_id=162054,o.value_text,null)) as spd_number,
        max(if(o.concept_id=5916,o.value_numeric,null)) as birth_weight,
        max(if(o.concept_id=1409,o.value_numeric,null)) as gestation_at_birth,
        max(if(o.concept_id=159949,o.value_coded,null)) as birth_type,
        max(if(o.concept_id=162140,o.value_datetime,null)) as date_first_seen,
        max(if(o.concept_id=162051,o.value_text,null)) as birth_notification_number,
        max(if(o.concept_id=162052,o.value_text,null)) as birth_certificate_number,
        max(if(o.concept_id=161630,o.value_coded,null)) as need_for_special_care,
        max(if(o.concept_id=161601,o.value_coded,null)) as reason_for_special_care,
        max(if(o.concept_id=160540,o.value_coded,null)) as referral_source,
        max(if(o.concept_id=160563,o.value_coded,null)) as transfer_in,
        max(if(o.concept_id=160534,o.value_datetime,null)) as transfer_in_date,
        max(if(o.concept_id=160535,o.value_text,null)) as facility_transferred_from,
        max(if(o.concept_id=161551,o.value_text,null)) as district_transferred_from,
        max(if(o.concept_id=160555,o.value_datetime,null)) as date_first_enrolled_in_hei_care,
        -- max(if(o.concept_id=1282,o.value_coded,null)) as arv_prophylaxis,
        max(if(o.concept_id=159941,o.value_coded,null)) as mother_breastfeeding,
        -- max(if(o.concept_id=1282,o.value_coded,null)) as mother_on_NVP_during_breastfeeding,
        max(if(o.concept_id=152460,o.value_coded,null)) as TB_contact_history_in_household,
        -- max(if(o.concept_id=162121,o.value_coded,null)) as infant_mother_link,
        max(if(o.concept_id=160429,o.value_coded,null)) as mother_alive,
        max(if(o.concept_id=1148,o.value_coded,null)) as mother_on_pmtct_drugs,
        max(if(o.concept_id=1086,o.value_coded,null)) as mother_on_drug,
        max(if(o.concept_id=162055,o.value_coded,null)) as mother_on_art_at_infant_enrollment,
        max(if(o.concept_id=1088,o.value_coded,null)) as mother_drug_regimen,
        max(if(o.concept_id=1282,o.value_coded,null)) as infant_prophylaxis,
        max(if(o.concept_id=162053,o.value_numeric,null)) as parent_ccc_number,
        max(if(o.concept_id=5630,o.value_coded,null)) as mode_of_delivery,
        max(if(o.concept_id=1572,o.value_coded,null)) as place_of_delivery,
        max(if(o.concept_id=1503,o.value_numeric,null)) as birth_length,
        max(if(o.concept_id=163460,o.value_numeric,null)) as birth_order,
        max(if(o.concept_id=162724,o.value_text,null)) as health_facility_name,
        max(if(o.concept_id=164130,o.value_datetime,null)) as date_of_birth_notification,
        max(if(o.concept_id=164129,o.value_datetime,null)) as date_of_birth_registration,
        max(if(o.concept_id=164140,o.value_text,null)) as birth_registration_place,
        max(if(o.concept_id=1646,o.value_text,null)) as permanent_registration_serial,
        max(if(o.concept_id=162724,o.value_text,null)) as mother_facility_registered,
        max(if(o.concept_id=160753,o.value_datetime,null)) as exit_date,
        max(if(o.concept_id=161555,o.value_coded,null)) as exit_reason,
        max(if(o.concept_id=159427,(case o.value_coded when 703 then "Positive" when 664 then "Negative" when 1138 then "Inconclusive" else "" end),null)) as hiv_status_at_exit,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(5303,162054,5916,1409,162140,162051,162052,161630,161601,160540,160563,160534,160535,161551,160555,1282,159941,1282,152460,160429,1148,1086,162055,1088,1282,162053,5630,1572,161555,159427,1503,163460,162724,164130,164129,164140,1646,160753,161555,159427,159949)
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('415f5136-ca4a-49a8-8db3-f994187c3af6','01894f88-dc73-42d4-97a3-0929118403fb')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id,visit_date
    ON DUPLICATE KEY UPDATE provider=VALUES(provider),visit_id=VALUES(visit_id),visit_date=VALUES(visit_date),child_exposed=VALUES(child_exposed),spd_number=VALUES(spd_number),birth_weight=VALUES(birth_weight),gestation_at_birth=VALUES(gestation_at_birth),date_first_seen=VALUES(date_first_seen),
      birth_notification_number=VALUES(birth_notification_number),birth_certificate_number=VALUES(birth_certificate_number),need_for_special_care=VALUES(need_for_special_care),reason_for_special_care=VALUES(reason_for_special_care),referral_source=VALUES(referral_source),transfer_in=VALUES(transfer_in),transfer_in_date=VALUES(transfer_in_date),facility_transferred_from=VALUES(facility_transferred_from),
      district_transferred_from=VALUES(district_transferred_from),date_first_enrolled_in_hei_care=VALUES(date_first_enrolled_in_hei_care),mother_breastfeeding=VALUES(mother_breastfeeding),TB_contact_history_in_household=VALUES(TB_contact_history_in_household),mother_alive=VALUES(mother_alive),mother_on_pmtct_drugs=VALUES(mother_on_pmtct_drugs),
      mother_on_drug=VALUES(mother_on_drug),mother_on_art_at_infant_enrollment=VALUES(mother_on_art_at_infant_enrollment),mother_drug_regimen=VALUES(mother_drug_regimen),infant_prophylaxis=VALUES(infant_prophylaxis),parent_ccc_number=VALUES(parent_ccc_number),mode_of_delivery=VALUES(mode_of_delivery),place_of_delivery=VALUES(place_of_delivery),birth_length=VALUES(birth_length),birth_order=VALUES(birth_order),health_facility_name=VALUES(health_facility_name),
      date_of_birth_notification=VALUES(date_of_birth_notification),date_of_birth_registration=VALUES(date_of_birth_registration),birth_registration_place=VALUES(birth_registration_place),permanent_registration_serial=VALUES(permanent_registration_serial),mother_facility_registered=VALUES(mother_facility_registered),exit_date=VALUES(exit_date),exit_reason=VALUES(exit_reason),hiv_status_at_exit=VALUES(hiv_status_at_exit),birth_type=VALUES(birth_type)
    ;

    END $$

-- ------------- update etl_hei_follow_up_visit-------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_hei_follow_up $$
CREATE PROCEDURE sp_update_etl_hei_follow_up(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_hei_follow_up_visit(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      weight,
      height,
      muac,
      primary_caregiver,
      infant_feeding,
      stunted,
      tb_assessment_outcome,
      social_smile_milestone,
      head_control_milestone,
      response_to_sound_milestone,
      hand_extension_milestone,
      sitting_milestone,
      walking_milestone,
      standing_milestone,
      talking_milestone,
      review_of_systems_developmental,
      weight_category,
      followup_type,
      dna_pcr_sample_date,
      dna_pcr_contextual_status,
      dna_pcr_result,
      azt_given,
      nvp_given,
      ctx_given,
      multi_vitamin_given,
      -- dna_pcr_dbs_sample_code,
      -- dna_pcr_results_date,
      -- first_antibody_sample_date,
      first_antibody_result,
      -- first_antibody_dbs_sample_code,
      -- first_antibody_result_date,
      -- final_antibody_sample_date,
      final_antibody_result,
      -- final_antibody_dbs_sample_code,
      -- final_antibody_result_date,
      tetracycline_ointment_given,
      pupil_examination,
      sight_examination,
      squint,
      deworming_drug,
      dosage,
      unit,
      vitaminA_given,
      disability,
      referred_from,
      referred_to,
      counselled_on,
      MNPS_Supplementation,
      LLIN,
      comments,
      next_appointment_date,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.visit_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id,
        max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
        max(if(o.concept_id=5090,o.value_numeric,null)) as height,
        max(if(o.concept_id=160908,o.value_coded,null)) as muac,
        max(if(o.concept_id=160640,o.value_coded,null)) as primary_caregiver,
        max(if(o.concept_id=1151,o.value_coded,null)) as infant_feeding,
        max(if(o.concept_id=164088,o.value_coded,null)) as stunted,
        max(if(o.concept_id=1659,o.value_coded,null)) as tb_assessment_outcome,
        max(if(o.concept_id=162069 and o.value_coded=162056,o.value_coded,null)) as social_smile_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162057,o.value_coded,null)) as head_control_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162058,o.value_coded,null)) as response_to_sound_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162059,o.value_coded,null)) as hand_extension_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162061,o.value_coded,null)) as sitting_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162063,o.value_coded,null)) as walking_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162062,o.value_coded,null)) as standing_milestone,
        max(if(o.concept_id=162069 and o.value_coded=162060,o.value_coded,null)) as talking_milestone,
        max(if(o.concept_id=1189,o.value_coded,null)) as review_of_systems_developmental,
        max(if(o.concept_id=1854,o.value_coded,null)) as weight_category,
        max(if(o.concept_id=159402,o.value_coded,null)) as followup_type,
        max(if(o.concept_id=159951,o.value_datetime,null)) as dna_pcr_sample_date,
        max(if(o.concept_id=162084,o.value_coded,null)) as dna_pcr_contextual_status,
        max(if(o.concept_id=1030,o.value_coded,null)) as dna_pcr_result,
        max(if(o.concept_id=966 and o.value_coded=86663,o.value_coded,null)) as azt_given,
        max(if(o.concept_id=966 and o.value_coded=80586,o.value_coded,null)) as nvp_given,
        max(if(o.concept_id=1109,o.value_coded,null)) as ctx_given,
        max(if(o.concept_id=1193,o.value_coded,null)) as multi_vitamin_given,
        -- max(if(o.concept_id=162086,o.value_text,null)) as dna_pcr_dbs_sample_code,
        -- max(if(o.concept_id=160082,o.value_datetime,null)) as dna_pcr_results_date,
        -- max(if(o.concept_id=159951,o.value_datetime,null)) as first_antibody_sample_date,
        max(if(o.concept_id=1040,o.value_coded,null)) as first_antibody_result,
        -- max(if(o.concept_id=162086,o.value_text,null)) as first_antibody_dbs_sample_code,
        -- max(if(o.concept_id=160082,o.value_datetime,null)) as first_antibody_result_date,
        -- max(if(o.concept_id=159951,o.value_datetime,null)) as final_antibody_sample_date,
        max(if(o.concept_id=1326,o.value_coded,null)) as final_antibody_result,
        -- max(if(o.concept_id=162086,o.value_text,null)) as final_antibody_dbs_sample_code,
        -- max(if(o.concept_id=160082,o.value_datetime,null)) as final_antibody_result_date,
        max(if(o.concept_id=162077,o.value_coded,null)) as tetracycline_ointment_given,
        max(if(o.concept_id=162064,o.value_coded,null)) as pupil_examination,
        max(if(o.concept_id=162067,o.value_coded,null)) as sight_examination,
        max(if(o.concept_id=162066,o.value_coded,null)) as squint,
        max(if(o.concept_id=1282,o.value_coded,null)) as deworming_drug,
        max(if(o.concept_id=1443,o.value_numeric,null)) as dosage,
        max(if(o.concept_id=1621,o.value_text,null)) as unit,
        max(if(o.concept_id=161534,o.value_coded,null)) as vitaminA_given,
        max(if(o.concept_id=162558,o.value_coded,null)) as disablity,
        max(if(o.concept_id=163145,o.value_coded,null)) as referred_from,
				max(if(o.concept_id=160481,o.value_coded,null)) as referred_to,
				max(if(o.concept_id=1379,o.value_coded,null)) as counselled_on,
				max(if(o.concept_id=5484,o.value_coded,null)) as MNPS_Supplementation,
        max(if(o.concept_id=159855,o.value_coded,null)) as LLIN,
        max(if(o.concept_id=159395,o.value_text,null)) as comments,
        max(if(o.concept_id=5096,o.value_datetime,null)) as next_appointment_date,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(844,5089,5090,160640,1151,1659,5096,162069,162069,162069,162069,162069,162069,162069,162069,1189,159951,966,1109,162084,1030,162086,160082,159951,1040,162086,160082,159951,1326,162086,160082,162077,162064,162067,162066,1282,1443,1621,159395,5096,160908,1854,164088,1193,161534,162558,160481,163145,1379,5484,159855,159402)
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('bcc6da85-72f2-4291-b206-789b8186a021','c6d09e05-1f25-4164-8860-9f32c5a02df0')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id,visit_date
    ON DUPLICATE KEY UPDATE provider=VALUES(provider),visit_id=VALUES(visit_id),visit_date=VALUES(visit_date),weight=VALUES(weight),height=VALUES(height),primary_caregiver=VALUES(primary_caregiver),infant_feeding=VALUES(infant_feeding),tb_assessment_outcome=VALUES(tb_assessment_outcome),social_smile_milestone=VALUES(social_smile_milestone),head_control_milestone=VALUES(head_control_milestone),
      response_to_sound_milestone=VALUES(response_to_sound_milestone),hand_extension_milestone=VALUES(hand_extension_milestone),sitting_milestone=VALUES(sitting_milestone),walking_milestone=VALUES(walking_milestone),standing_milestone=VALUES(standing_milestone),talking_milestone=VALUES(talking_milestone),review_of_systems_developmental=VALUES(review_of_systems_developmental),
      dna_pcr_result=VALUES(dna_pcr_result),first_antibody_result=VALUES(first_antibody_result),final_antibody_result=VALUES(final_antibody_result),
      tetracycline_ointment_given=VALUES(tetracycline_ointment_given),pupil_examination=VALUES(pupil_examination),sight_examination=VALUES(sight_examination),squint=VALUES(squint),deworming_drug=VALUES(deworming_drug),dosage=VALUES(dosage),unit=VALUES(unit),comments=VALUES(comments),next_appointment_date=VALUES(next_appointment_date)
      ,nvp_given=VALUES(nvp_given),ctx_given=VALUES(ctx_given),muac=VALUES(muac),weight_category=VALUES(weight_category),stunted=VALUES(stunted),multi_vitamin_given=VALUES(multi_vitamin_given),vitaminA_given=VALUES(vitaminA_given),disability=VALUES(disability),referred_from=VALUES(referred_from),
      referred_to=VALUES(referred_to),counselled_on=VALUES(counselled_on),MNPS_Supplementation=VALUES(MNPS_Supplementation),LLIN=VALUES(LLIN),followup_type=VALUES(followup_type)
    ;

    END $$
-- ------------- update etl_hei_immunization-------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_hei_immunization $$
CREATE PROCEDURE sp_update_etl_hei_immunization(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing hei_immunization data ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_hei_immunization(
      patient_id,
      visit_date,
      created_by,
      date_created,
      date_last_modified,
      encounter_id,
      BCG,
      OPV_birth,
      OPV_1,
      OPV_2,
      OPV_3,
      IPV,
      DPT_Hep_B_Hib_1,
      DPT_Hep_B_Hib_2,
      DPT_Hep_B_Hib_3,
      PCV_10_1,
      PCV_10_2,
      PCV_10_3,
      ROTA_1,
      ROTA_2,
      Measles_rubella_1,
      Measles_rubella_2,
      Yellow_fever,
      Measles_6_months,
      VitaminA_6_months,
      VitaminA_1_yr,
      VitaminA_1_and_half_yr,
      VitaminA_2_yr ,
      VitaminA_2_to_5_yr,
      fully_immunized
    )
      select
        patient_id,
        visit_date,
        y.creator,
        y.date_created,
        y.date_last_modified,
        y.encounter_id,
        max(if(vaccine="BCG", date_given, "")) as BCG,
        max(if(vaccine="OPV" and sequence=0, date_given, "")) as OPV_birth,
        max(if(vaccine="OPV" and sequence=1, date_given, "")) as OPV_1,
        max(if(vaccine="OPV" and sequence=2, date_given, "")) as OPV_2,
        max(if(vaccine="OPV" and sequence=3, date_given, "")) as OPV_3,
        max(if(vaccine="IPV", date_given, ""))  as IPV,
        max(if(vaccine="DPT" and sequence=1, date_given, "")) as DPT_Hep_B_Hib_1,
        max(if(vaccine="DPT" and sequence=2, date_given, "")) as DPT_Hep_B_Hib_2,
        max(if(vaccine="DPT" and sequence=3, date_given, "")) as DPT_Hep_B_Hib_3,
        max(if(vaccine="PCV" and sequence=1, date_given, "")) as PCV_10_1,
        max(if(vaccine="PCV" and sequence=2, date_given, "")) as PCV_10_2,
        max(if(vaccine="PCV" and sequence=3, date_given, "")) as PCV_10_3,
        max(if(vaccine="ROTA" and sequence=1, date_given, "")) as ROTA_1,
        max(if(vaccine="ROTA" and sequence=2, date_given, "")) as ROTA_2,
        max(if(vaccine="measles_rubella" and sequence=1, date_given, "")) as Measles_rubella_1,
        max(if(vaccine="measles_rubella" and sequence=2, date_given, "")) as Measles_rubella_2,
        max(if(vaccine="yellow_fever", date_given, "")) as Yellow_fever,
        max(if(vaccine="measles", date_given, "")) as Measles_6_months,
        max(if(vaccine="Vitamin A" and sequence=1, date_given, "")) as VitaminA_6_months,
        max(if(vaccine="Vitamin A" and sequence=2, date_given, "")) as VitaminA_1_yr,
        max(if(vaccine="Vitamin A" and sequence=3, date_given, "")) as VitaminA_1_and_half_yr,
        max(if(vaccine="Vitamin A" and sequence=4, date_given, "")) as VitaminA_2_yr,
        max(if(vaccine="Vitamin A" and sequence=5, date_given, "")) as VitaminA_2_to_5_yr,
        max(date(o.value_datetime)) as fully_immunized
      from (
             (select
                person_id as patient_id,
                date(encounter_datetime) as visit_date,
                creator,
                date(date_created) as date_created,
                date_last_modified,
                encounter_id,
                name as encounter_type,
                max(if(concept_id=1282 , "Vitamin A", "")) as vaccine,
                max(if(concept_id=1418, value_numeric, "")) as sequence,
                max(if(concept_id=1282 , date(obs_datetime), "")) as date_given,
                obs_group_id
              from (
                     select o.person_id, e.encounter_datetime, e.creator, e.date_created,if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified, o.concept_id, o.value_coded, o.value_numeric, date(o.value_datetime) date_given, o.obs_group_id, o.encounter_id, et.uuid, et.name, o.obs_datetime
                     from obs o
                       inner join encounter e on e.encounter_id=o.encounter_id
                       inner join person p on p.person_id=o.person_id and p.voided=0
                       inner join
                       (
                         select encounter_type_id, uuid, name from encounter_type where
                           uuid = '82169b8d-c945-4c41-be62-433dfd9d6c86'
                       ) et on et.encounter_type_id=e.encounter_type
                     where concept_id in(1282,1418) and (e.date_created >= last_update_time
                                                         or e.date_changed >= last_update_time
                                                         or e.date_voided >= last_update_time
                                                         or o.date_created >= last_update_time
                                                         or o.date_voided >= last_update_time)
                   ) t
              group by obs_group_id
              having vaccine != ""
             )
             union
             (
               select
                 person_id as patient_id,
                 date(encounter_datetime) as visit_date,
                 creator,
                 date(date_created) as date_created,
                 date_last_modified,
                 encounter_id,
                 name as encounter_type,
                 max(if(concept_id=984 , (case when value_coded=886 then "BCG" when value_coded=783 then "OPV" when value_coded=1422 then "IPV"
                                          when value_coded=781 then "DPT" when value_coded=162342 then "PCV" when value_coded=83531 then "ROTA"
                                          when value_coded=162586 then "measles_rubella"  when value_coded=5864 then "yellow_fever" when value_coded=36 then "measles" when value_coded=84879 then "TETANUS TOXOID"  end), "")) as vaccine,
                 max(if(concept_id=1418, value_numeric, "")) as sequence,
                 max(if(concept_id=1410, date_given, "")) as date_given,
                 obs_group_id
               from (
                      select o.person_id, e.encounter_datetime, e.creator, e.date_created,if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified, o.concept_id, o.value_coded, o.value_numeric, date(o.value_datetime) date_given, o.obs_group_id, o.encounter_id, et.uuid, et.name
                      from obs o
                        inner join encounter e on e.encounter_id=o.encounter_id
                        inner join person p on p.person_id=o.person_id and p.voided=0
                        inner join
                        (
                          select encounter_type_id, uuid, name from encounter_type where
                            uuid = '82169b8d-c945-4c41-be62-433dfd9d6c86'
                        ) et on et.encounter_type_id=e.encounter_type
                      where concept_id in(984,1418,1410) and (e.date_created >= last_update_time
                                                              or e.date_changed >= last_update_time
                                                              or e.date_voided >= last_update_time
                                                              or o.date_created >= last_update_time
                                                              or o.date_voided >= last_update_time)
                    ) t
               group by obs_group_id
               having vaccine != ""
             )
           ) y
        left join obs o on y.encounter_id = o.encounter_id and o.voided=0
      group by patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),BCG=VALUES(BCG),OPV_birth=VALUES(OPV_birth),OPV_1=VALUES(OPV_1),OPV_2=VALUES(OPV_2),OPV_3=VALUES(OPV_3),IPV=VALUES(IPV),
      DPT_Hep_B_Hib_1=VALUES(DPT_Hep_B_Hib_1),DPT_Hep_B_Hib_2=VALUES(DPT_Hep_B_Hib_2),DPT_Hep_B_Hib_3=VALUES(DPT_Hep_B_Hib_3),PCV_10_1=VALUES(PCV_10_1),PCV_10_2=VALUES(PCV_10_2),PCV_10_3=VALUES(PCV_10_3),
      ROTA_1=VALUES(ROTA_1),ROTA_2=VALUES(ROTA_2),Measles_rubella_1=VALUES(Measles_rubella_1),Measles_rubella_2=VALUES(Measles_rubella_2), Yellow_fever=VALUES(Yellow_fever),
      Measles_6_months=VALUES(Measles_6_months), VitaminA_6_months=VALUES(VitaminA_6_months),VitaminA_1_yr=VALUES(VitaminA_1_yr),
      VitaminA_1_and_half_yr=VALUES(VitaminA_1_and_half_yr),VitaminA_2_yr=VALUES(VitaminA_2_yr),VitaminA_2_to_5_yr=VALUES(VitaminA_2_to_5_yr)
    ;
    END $$


-- ------------- update etl_tb_enrollment-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_tb_enrollment $$
CREATE PROCEDURE sp_update_etl_tb_enrollment(IN last_update_time DATETIME)
  BEGIN



    insert into kenyaemr_etl.etl_tb_enrollment(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_treatment_started,
      district,
      -- district_registration_number,
      referred_by,
      referral_date,
      date_transferred_in,
      facility_transferred_from,
      district_transferred_from,
      date_first_enrolled_in_tb_care,
      weight,
      height,
      treatment_supporter,
      relation_to_patient,
      treatment_supporter_address,
      treatment_supporter_phone_contact,
      disease_classification,
      patient_classification,
      pulmonary_smear_result,
      has_extra_pulmonary_pleurial_effusion,
      has_extra_pulmonary_milliary,
      has_extra_pulmonary_lymph_node,
      has_extra_pulmonary_menengitis,
      has_extra_pulmonary_skeleton,
      has_extra_pulmonary_abdominal,
      date_created,
      date_last_modified
      -- has_extra_pulmonary_other,
      -- treatment_outcome,
      -- treatment_outcome_date
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        max(if(o.concept_id=1113,o.value_datetime,null)) as date_treatment_started,
        max(if(o.concept_id=161564,left(trim(o.value_text),100),null)) as district,
        -- max(if(o.concept_id=5085,o.value_numeric,null)) as district_registration_number,
        max(if(o.concept_id=160540,o.value_coded,null)) as referred_by,
        max(if(o.concept_id=161561,o.value_datetime,null)) as referral_date,
        max(if(o.concept_id=160534,o.value_datetime,null)) as date_transferred_in,
        max(if(o.concept_id=160535,left(trim(o.value_text),100),null)) as facility_transferred_from,
        max(if(o.concept_id=161551,left(trim(o.value_text),100),null)) as district_transferred_from,
        max(if(o.concept_id=161552,o.value_datetime,null)) as date_first_enrolled_in_tb_care,
        max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
        max(if(o.concept_id=5090,o.value_numeric,null)) as height,
        max(if(o.concept_id=160638,left(trim(o.value_text),100),null)) as treatment_supporter,
        max(if(o.concept_id=160640,o.value_coded,null)) as relation_to_patient,
        max(if(o.concept_id=160641,left(trim(o.value_text),100),null)) as treatment_supporter_address,
        max(if(o.concept_id=160642,left(trim(o.value_text),100),null)) as treatment_supporter_phone_contact,
        max(if(o.concept_id=160040,o.value_coded,null)) as disease_classification,
        max(if(o.concept_id=159871,o.value_coded,null)) as patient_classification,
        max(if(o.concept_id=159982,o.value_coded,null)) as pulmonary_smear_result,
        max(if(o.concept_id=161356 and o.value_coded=130059,o.value_coded,null)) as has_extra_pulmonary_pleurial_effusion,
        max(if(o.concept_id=161356 and o.value_coded=115753,o.value_coded,null)) as has_extra_pulmonary_milliary,
        max(if(o.concept_id=161356 and o.value_coded=111953,o.value_coded,null)) as has_extra_pulmonary_lymph_node,
        max(if(o.concept_id=161356 and o.value_coded=111967,o.value_coded,null)) as has_extra_pulmonary_menengitis,
        max(if(o.concept_id=161356 and o.value_coded=112116,o.value_coded,null)) as has_extra_pulmonary_skeleton,
        max(if(o.concept_id=161356 and o.value_coded=1350,o.value_coded,null)) as has_extra_pulmonary_abdominal,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      -- max(if(o.concept_id=161356,o.value_coded,null)) as has_extra_pulmonary_other
      -- max(if(o.concept_id=159786,o.value_coded,null)) as treatment_outcome,
      -- max(if(o.concept_id=159787,o.value_coded,null)) as treatment_outcome_date

      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(160540,161561,160534,160535,161551,161552,5089,5090,160638,160640,160641,160642,160040,159871,159982,161356)
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('9d8498a4-372d-4dc4-a809-513a2434621e')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE provider=VALUES(provider),visit_id=VALUES(visit_id),visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),date_treatment_started=VALUES(date_treatment_started),district=VALUES(district),referred_by=VALUES(referred_by),referral_date=VALUES(referral_date),
      date_transferred_in=VALUES(date_transferred_in),facility_transferred_from=VALUES(facility_transferred_from),district_transferred_from=VALUES(district_transferred_from),date_first_enrolled_in_tb_care=VALUES(date_first_enrolled_in_tb_care),weight=VALUES(weight),height=VALUES(height),treatment_supporter=VALUES(treatment_supporter),relation_to_patient=VALUES(relation_to_patient),
      treatment_supporter_address=VALUES(treatment_supporter_address),treatment_supporter_phone_contact=VALUES(treatment_supporter_phone_contact),disease_classification=VALUES(disease_classification),patient_classification=VALUES(patient_classification),pulmonary_smear_result=VALUES(pulmonary_smear_result),has_extra_pulmonary_pleurial_effusion=VALUES(has_extra_pulmonary_pleurial_effusion),
      has_extra_pulmonary_milliary=VALUES(has_extra_pulmonary_milliary),has_extra_pulmonary_lymph_node=VALUES(has_extra_pulmonary_lymph_node),has_extra_pulmonary_menengitis=VALUES(has_extra_pulmonary_menengitis),has_extra_pulmonary_skeleton=VALUES(has_extra_pulmonary_skeleton),has_extra_pulmonary_abdominal=VALUES(has_extra_pulmonary_abdominal)
    ;

    END $$
-- DELIMITER ;

-- ------------- update etl_tb_follow_up_visit-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_tb_follow_up_visit $$
CREATE PROCEDURE sp_update_etl_tb_follow_up_visit(IN last_update_time DATETIME)
  BEGIN



    insert into kenyaemr_etl.etl_tb_follow_up_visit(
      patient_id,
      uuid,
      provider,
      visit_id ,
      visit_date ,
      location_id,
      encounter_id,
      spatum_test,
      spatum_result,
      result_serial_number,
      quantity ,
      date_test_done,
      bacterial_colonie_growth,
      number_of_colonies,
      resistant_s,
      resistant_r,
      resistant_inh,
      resistant_e,
      sensitive_s,
      sensitive_r,
      sensitive_inh,
      sensitive_e,
      test_date,
      hiv_status,
      next_appointment_date,
      date_created,
      date_last_modified
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        max(if(o.concept_id=159961,o.value_coded,null)) as spatum_test,
        max(if(o.concept_id=307,o.value_coded,null)) as spatum_result,
        max(if(o.concept_id=159968,o.value_numeric,null)) as result_serial_number,
        max(if(o.concept_id=160023,o.value_numeric,null)) as quantity,
        max(if(o.concept_id=159964,o.value_datetime,null)) as date_test_done,
        max(if(o.concept_id=159982,o.value_coded,null)) as bacterial_colonie_growth,
        max(if(o.concept_id=159952,o.value_numeric,null)) as number_of_colonies,
        max(if(o.concept_id=159956 and o.value_coded=84360,o.value_numeric,null)) as resistant_s,
        max(if(o.concept_id=159956 and o.value_coded=767,trim(o.value_text),null)) as resistant_r,
        max(if(o.concept_id=159956 and o.value_coded=78280,o.value_coded,null)) as resistant_inh,
        max(if(o.concept_id=159956 and o.value_coded=75948,trim(o.value_text),null)) as resistant_e,
        max(if(o.concept_id=159958 and o.value_coded=84360,trim(o.value_text),null)) as sensitive_s,
        max(if(o.concept_id=159958 and o.value_coded=767,o.value_coded,null)) as sensitive_r,
        max(if(o.concept_id=159958 and o.value_coded=78280,o.value_coded,null)) as sensitive_inh,
        max(if(o.concept_id=159958 and o.value_coded=75948,o.value_coded,null)) as sensitive_e,
        max(if(o.concept_id=159964,o.value_datetime,null)) as test_date,
        max(if(o.concept_id=1169,o.value_coded,null)) as hiv_status,
        max(if(o.concept_id=5096,o.value_datetime,null)) as next_appointment_date,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(159961,307,159968,160023,159964,159982,159952,159956,159958,159964,1169,5096)
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('fbf0bfce-e9f4-45bb-935a-59195d8a0e35')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE provider=VALUES(provider),visit_id=VALUES(visit_id),visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),spatum_test=VALUES(spatum_test),spatum_result=VALUES(spatum_result),result_serial_number=VALUES(result_serial_number),quantity=VALUES(quantity) ,date_test_done=VALUES(date_test_done),bacterial_colonie_growth=VALUES(bacterial_colonie_growth),
      number_of_colonies=VALUES(number_of_colonies),resistant_s=VALUES(resistant_s),resistant_r=VALUES(resistant_r),resistant_inh=VALUES(resistant_inh),resistant_e=VALUES(resistant_e),sensitive_s=VALUES(sensitive_s),sensitive_r=VALUES(sensitive_r),sensitive_inh=VALUES(sensitive_inh),sensitive_e=VALUES(sensitive_e),test_date=VALUES(test_date),hiv_status=VALUES(hiv_status),next_appointment_date=VALUES(next_appointment_date)
    ;

    END $$
-- DELIMITER ;

-- ------------- update etl_tb_screening-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_tb_screening $$
CREATE PROCEDURE sp_update_etl_tb_screening(IN last_update_time DATETIME)
  BEGIN

    insert into kenyaemr_etl.etl_tb_screening(
        patient_id,
        uuid,
        provider,
        visit_id,
        visit_date,
        encounter_id,
        location_id,
        cough_for_2wks_or_more,
        confirmed_tb_contact,
        fever_for_2wks_or_more,
        noticeable_weight_loss,
        night_sweat_for_2wks_or_more,
        lethargy,
        spatum_smear_ordered,
        chest_xray_ordered,
        genexpert_ordered,
        spatum_smear_result,
        chest_xray_result,
        genexpert_result,
        referral,
        clinical_tb_diagnosis,
        resulting_tb_status ,
        contact_invitation,
        evaluated_for_ipt,
        started_anti_TB,
        tb_treatment_start_date,
        tb_prophylaxis,
        notes,
        person_present,
        date_created,
        date_last_modified
    )
      select
        e.patient_id, e.uuid, e.creator, e.visit_id, date(e.encounter_datetime) as visit_date, e.encounter_id, e.location_id,
        max(if(o.concept_id=1729 and o.value_coded =159799,o.value_coded,null)) as cough_for_2wks_or_more,
        max(if(o.concept_id=1729 and o.value_coded =124068,o.value_coded,null)) confirmed_tb_contact,
        max(if(o.concept_id=1729 and o.value_coded =1494,o.value_coded,null)) fever_for_2wks_or_more,
        max(if(o.concept_id=1729 and o.value_coded =832,o.value_coded,null)) as noticeable_weight_loss,
        max(if(o.concept_id=1729 and o.value_coded =133027,o.value_coded,null)) as night_sweat_for_2wks_or_more,
        max(if(o.concept_id=1729 and o.value_coded =116334,o.value_coded,null)) as lethargy,
        max(if(o.concept_id=1271 and o.value_coded =307,o.value_coded,null)) as spatum_smear_ordered,
        max(if(o.concept_id=1271 and o.value_coded =12,o.value_coded,null)) as chest_xray_ordered,
        max(if(o.concept_id=1271 and o.value_coded = 162202,o.value_coded,null)) as genexpert_ordered,
        max(if(o.concept_id=307,o.value_coded,null)) as spatum_smear_result,
        max(if(o.concept_id=12,o.value_coded,null)) as chest_xray_result,
        max(if(o.concept_id=162202,o.value_coded,null)) as genexpert_result,
        max(if(o.concept_id=1272,o.value_coded,null)) as referral,
        max(if(o.concept_id=163752,o.value_coded,null)) as clinical_tb_diagnosis,
        max(if(o.concept_id=1659,o.value_coded,null)) as resulting_tb_status,
        max(if(o.concept_id=163414,o.value_coded,null)) as contact_invitation,
        max(if(o.concept_id=162275,o.value_coded,null)) as evaluated_for_ipt,
        max(if(o.concept_id=162309,o.value_coded,null)) as started_anti_TB,
        max(if(o.concept_id=1113,date(o.value_datetime),null)) as tb_treatment_start_date,
        max(if(o.concept_id=1109,o.value_coded,null)) as tb_prophylaxis,
        max(if(o.concept_id=160632,o.value_text,null)) as notes,
        max(if(o.concept_id=161643,o.value_coded,null)) as person_present,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("22c68f86-bbf0-49ba-b2d1-23fa7ccf0259", "59ed8e62-7f1f-40ae-a2e3-eabe350277ce","23b4ebbd-29ad-455e-be0e-04aa6bc30798","72aa78e0-ee4b-47c3-9073-26f3b9ecc4a7")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (1659, 1113, 160632,161643,1729,1271,307,12,162202,1272,163752,163414,162275,162309,1109) and o.voided=0
      where e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id,visit_date
    ON DUPLICATE KEY UPDATE provider=VALUES(provider),visit_id=VALUES(visit_id),visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),cough_for_2wks_or_more=values(cough_for_2wks_or_more),confirmed_tb_contact=values(confirmed_tb_contact),
    fever_for_2wks_or_more=values(fever_for_2wks_or_more),noticeable_weight_loss=values(noticeable_weight_loss),night_sweat_for_2wks_or_more=values(night_sweat_for_2wks_or_more),lethargy=values(lethargy),spatum_smear_ordered=values(spatum_smear_ordered),
    chest_xray_ordered=values(chest_xray_ordered),genexpert_ordered=values(genexpert_ordered),spatum_smear_result=values(spatum_smear_result),
    chest_xray_result=values(chest_xray_result),genexpert_result=values(genexpert_result),referral=values(referral),clinical_tb_diagnosis=values(clinical_tb_diagnosis),
    resulting_tb_status=VALUES(resulting_tb_status), tb_treatment_start_date=VALUES(tb_treatment_start_date),contact_invitation=values(contact_invitation),evaluated_for_ipt=values(evaluated_for_ipt),started_anti_TB=values(started_anti_TB),
    tb_prophylaxis=values(tb_prophylaxis), notes=values(notes);


    END $$

-- ------------------------------ update drug event -------------------------------------


DROP PROCEDURE IF EXISTS sp_update_drug_event $$
CREATE PROCEDURE sp_update_drug_event(IN last_update_time DATETIME)
  BEGIN

    INSERT INTO kenyaemr_etl.etl_drug_event(
      uuid,
      patient_id,
      date_started,
      visit_date,
      provider,
      encounter_id,
      program,
      regimen,
      regimen_name,
      regimen_line,
      discontinued,
      regimen_stopped,
      regimen_discontinued,
      date_discontinued,
      reason_discontinued,
      reason_discontinued_other,
      date_created,
      date_last_modified
    )
      select
        e.uuid,
        e.patient_id,
        e.encounter_datetime,
        e.encounter_datetime,
        e.creator,
        e.encounter_id,
        max(if(o.concept_id=1255,'HIV',if(o.concept_id=1268, 'TB', null))) as program,
        max(if(o.concept_id=1193,(
          case o.value_coded
          when 162565 then "3TC/NVP/TDF"
          when 164505 then "TDF/3TC/EFV"
          when 1652 then "AZT/3TC/NVP"
          when 160124 then "AZT/3TC/EFV"
          when 792 then "D4T/3TC/NVP"
          when 160104 then "D4T/3TC/EFV"
          when 164971 then "TDF/3TC/AZT"
          when 164968 then "AZT/3TC/DTG"
          when 164969 then "TDF/3TC/DTG"
          when 164970 then "ABC/3TC/DTG"
          when 162561 then "AZT/3TC/LPV/r"
          when 164511 then "AZT/3TC/ATV/r"
          when 162201 then "TDF/3TC/LPV/r"
          when 164512 then "TDF/3TC/ATV/r"
          when 162560 then "D4T/3TC/LPV/r"
          when 164972 then "AZT/TDF/3TC/LPV/r"
          when 164973 then "ETR/RAL/DRV/RTV"
          when 164974 then "ETR/TDF/3TC/LPV/r"
          when 162200 then "ABC/3TC/LPV/r"
          when 162199 then "ABC/3TC/NVP"
          when 162563 then "ABC/3TC/EFV"
          when 817 then "AZT/3TC/ABC"
          when 164975 then "D4T/3TC/ABC"
          when 162562 then "TDF/ABC/LPV/r"
          when 162559 then "ABC/DDI/LPV/r"
          when 164976 then "ABC/TDF/3TC/LPV/r"
          when 165375 then "RAL+3TC+DRV+RTV"
          when 165376 then "RAL+3TC+DRV+RTV+AZT"
          when 165377 then "RAL+3TC+DRV+RTV+ABC"
          when 165378 then "ETV+3TC+DRV+RTV"
          when 165379 then "RAL+3TC+DRV+RTV+TDF"
          when 165369 then "TDF+3TC+DTG+DRV/r"
          when 165370 then "TDF+3TC+RAL+DRV/r"
          when 165371 then "TDF+3TC+DTG+EFV+DRV/r"
          when 165372 then "ABC+3TC+RAL"
          when 165373 then "AZT+3TC+RAL+DRV/r"
          when 165374 then "ABC+3TC+RAL+DRV/r"
          when 1675 then "RHZE"
          when 768 then "RHZ"
          when 1674 then "SRHZE"
          when 164978 then "RfbHZE"
          when 164979 then "RfbHZ"
          when 164980 then "SRfbHZE"
          when 84360 then "S (1 gm vial)"
          when 75948 then "E"
          when 1194 then "RH"
          when 159851 then "RHE"
          when 1108 then "EH"
          else ""
          end ),null)) as regimen,
        max(if(o.concept_id=1193,(
          case o.value_coded
          when 162565 then "3TC+NVP+TDF"
          when 164505 then "TDF+3TC+EFV"
          when 1652 then "AZT+3TC+NVP"
          when 160124 then "AZT+3TC+EFV"
          when 792 then "D4T+3TC+NVP"
          when 160104 then "D4T+3TC+EFV"
          when 164971 then "TDF+3TC+AZT"
          when 164968 then "AZT+3TC+DTG"
          when 164969 then "TDF+3TC+DTG"
          when 164970 then "ABC+3TC+DTG"
          when 162561 then "AZT+3TC+LPV/r"
          when 164511 then "AZT+3TC+ATV/r"
          when 162201 then "TDF+3TC+LPV/r"
          when 164512 then "TDF+3TC+ATV/r"
          when 162560 then "D4T+3TC+LPV/r"
          when 164972 then "AZT+TDF+3TC+LPV/r"
          when 164973 then "ETR+RAL+DRV+RTV"
          when 164974 then "ETR+TDF+3TC+LPV/r"
          when 162200 then "ABC+3TC+LPV/r"
          when 162199 then "ABC+3TC+NVP"
          when 162563 then "ABC+3TC+EFV"
          when 817 then "AZT+3TC+ABC"
          when 164975 then "D4T+3TC+ABC"
          when 162562 then "TDF+ABC+LPV/r"
          when 162559 then "ABC+DDI+LPV/r"
          when 164976 then "ABC+TDF+3TC+LPV/r"
          when 165375 then "RAL+3TC+DRV+RTV"
          when 165376 then "RAL+3TC+DRV+RTV+AZT"
          when 165377 then "RAL+3TC+DRV+RTV+ABC"
          when 165378 then "ETV+3TC+DRV+RTV"
          when 165379 then "RAL+3TC+DRV+RTV+TDF"
          when 165369 then "TDF+3TC+DTG+DRV/r"
          when 165370 then "TDF+3TC+RAL+DRV/r"
          when 165371 then "TDF+3TC+DTG+EFV+DRV/r"
          when 165372 then "ABC+3TC+RAL"
          when 165373 then "AZT+3TC+RAL+DRV/r"
          when 165374 then "ABC+3TC+RAL+DRV/r"
          when 1675 then "RHZE"
          when 768 then "RHZ"
          when 1674 then "SRHZE"
          when 164978 then "RfbHZE"
          when 164979 then "RfbHZ"
          when 164980 then "SRfbHZE"
          when 84360 then "S (1 gm vial)"
          when 75948 then "E"
          when 1194 then "RH"
          when 159851 then "RHE"
          when 1108 then "EH"
          else ""
          end ),null)) as regimen_name,
        max(if(o.concept_id=163104,(
          case o.value_text
          -- patient regimen line
          when "AF" then "First line"
          when "AS" then "Second line"
          when "AT" then "Third line"
          when "CF" then "First line"
          when "CS" then "Second line"
          when "CT" then "Third line"
          else ""
          end ),null)) as regimen_line,
        max(if(o.concept_id=1191,(case o.value_datetime when NULL then 0 else 1 end),null)) as discontinued,
        max(if(o.concept_id=1255 and o.value_coded=1260,o.value_coded,null)) as regimen_stopped,
        null as regimen_discontinued,
        max(if(o.concept_id=1191,o.value_datetime,null)) as date_discontinued,
        max(if(o.concept_id=1252,o.value_coded,null)) as reason_discontinued,
        max(if(o.concept_id=5622,o.value_text,null)) as reason_discontinued_other,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified

      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(1193,1252,5622,1191,1255,1268,163104)
        inner join
        (
          select encounter_type, uuid,name from form where
            uuid in('da687480-e197-11e8-9f32-f2801f1b9fd1') -- regimen editor form
        ) f on f.encounter_type=e.encounter_type

      where e.encounter_datetime >= last_update_time

      group by e.encounter_id
    ON DUPLICATE KEY UPDATE date_started=VALUES(date_started), regimen=VALUES(regimen), discontinued=VALUES(discontinued), regimen_discontinued=VALUES(regimen_discontinued),
      date_discontinued=VALUES(date_discontinued)
    ;

    END $$
-- DELIMITER ;

-- ------------- update etl_pharmacy_extract table--------------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_pharmacy_extract $$
CREATE PROCEDURE sp_update_etl_pharmacy_extract(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_pharmacy_extract(
      obs_group_id,
      patient_id,
      uuid,
      visit_date,
      visit_id,
      encounter_id,
      date_created,
      date_last_modified,
      encounter_name,
      location_id,
      drug,
      drug_name,
      is_arv,
      is_ctx,
      is_dapsone,
      frequency,
      duration,
      duration_units,
      voided,
      date_voided,
      dispensing_provider
    )
      select
        o.obs_group_id obs_group_id,
        o.person_id,
        max(if(o.concept_id=1282, o.uuid, null)),
        date(o.obs_datetime) as enc_date,
        e.visit_id,
        o.encounter_id,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        et.name as enc_name,
        e.location_id,
        max(if(o.concept_id = 1282 and o.value_coded is not null,o.value_coded, null)) as drug_dispensed,
        max(if(o.concept_id = 1282, left(cn.name,255), 0)) as drug_name, -- arv:1085
        max(if(o.concept_id = 1282 and cs.concept_set=1085, 1, 0)) as arv_drug, -- arv:1085
        max(if(o.concept_id = 1282 and o.value_coded = 105281,1, 0)) as is_ctx,
        max(if(o.concept_id = 1282 and o.value_coded = 74250,1, 0)) as is_dapsone,
        max(if(o.concept_id = 1443, o.value_numeric, null)) as dose,
        max(if(o.concept_id = 159368, if(o.value_numeric > 10000, 10000, o.value_numeric), null)) as duration,
        max(if(o.concept_id = 1732 and o.value_coded=1072,'Days',if(o.concept_id=1732 and o.value_coded=1073,'Weeks',if(o.concept_id=1732 and o.value_coded=1074,'Months',null)))) as duration_units,
        o.voided,
        o.date_voided,
        e.creator
      from obs o
        left outer join encounter e on e.encounter_id = o.encounter_id and e.voided=0
        inner join person p on p.person_id=e.patient_id and p.voided=0
        left outer join encounter_type et on et.encounter_type_id = e.encounter_type
        left outer join concept_name cn on o.value_coded = cn.concept_id and cn.locale='en' and cn.concept_name_type='FULLY_SPECIFIED' -- SHORT'
        left outer join concept_set cs on o.value_coded = cs.concept_id
      where o.voided=0 and o.concept_id in(1282,1732,159368,1443,1444)  and e.voided=0 and
            (
              o.date_created >= last_update_time
              or o.date_voided >= last_update_time
            )
      group by o.obs_group_id, o.person_id, encounter_id
      having drug_dispensed is not null and obs_group_id is not null
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date), encounter_name=VALUES(encounter_name), is_arv=VALUES(is_arv), is_ctx=VALUES(is_ctx), is_dapsone=VALUES(is_dapsone), frequency=VALUES(frequency),
      duration=VALUES(duration), duration_units=VALUES(duration_units), voided=VALUES(voided), date_voided=VALUES(date_voided)
    ;

    update kenyaemr_etl.etl_pharmacy_extract
    set duration_in_days = if(duration_units= 'Days', duration,if(duration_units='Weeks',duration * 7,if(duration_units='Months',duration * 31,null)))
    where (duration is not null or duration <> "") and (duration_units is not null or duration_units <> "");

    END $$

-- DELIMITER ;

-- ------------------------------------- laboratory updates ---------------------------


DROP PROCEDURE IF EXISTS sp_update_etl_laboratory_extract $$
CREATE PROCEDURE sp_update_etl_laboratory_extract(IN last_update_time DATETIME)
  BEGIN

    insert into kenyaemr_etl.etl_laboratory_extract(
      uuid,
      encounter_id,
      patient_id,
      location_id,
      visit_date,
      visit_id,
      order_id,
      lab_test,
      urgency,
      order_reason,
      test_result,
      date_test_requested,
      date_test_result_received,
      date_created,
      date_last_modified,
      created_by
    )
      select
        o.uuid,
        e.encounter_id,
        e.patient_id,
        e.location_id,
        coalesce(od.date_activated,o.obs_datetime) as visit_date,
        e.visit_id,
        o.order_id,
        o.concept_id,
        od.urgency,
        od.order_reason,
        (case when o.concept_id in(5497,730,654,790,856) then o.value_numeric
         when o.concept_id in(1030,1305,1325,159430,161472,1029,1031,1619,1032,162202,307,45,167718) then o.value_coded END) AS test_result,
        od.date_activated as date_test_requested,
        e.encounter_datetime as date_test_result_received,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.creator
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid in('17a381d1-7e29-406a-b782-aa903b963c28', 'a0034eee-1940-4e35-847f-97537a35d05e','e1406e88-e9a9-11e8-9f32-f2801f1b9fd1','de78a6be-bfc5-4634-adc3-5f1a280455cc')
        ) et on et.encounter_type_id=e.encounter_type
        inner join obs o on e.encounter_id=o.encounter_id and o.voided=0 and o.concept_id in (5497,730,654,790,856,1030,1305,1325,159430,161472,1029,1031,1619,1032,162202,307,45,167718)
        left join orders od on od.order_id = o.order_id and od.voided=0
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by o.obs_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date), lab_test=VALUES(lab_test), test_result=VALUES(test_result)

    ;
    END $$
-- DELIMITER ;

-- ---------------------------- Update HTS encounters ---------------------


DROP PROCEDURE IF EXISTS sp_update_hts_test $$
CREATE PROCEDURE sp_update_hts_test(IN last_update_time DATETIME)
  BEGIN
    INSERT INTO kenyaemr_etl.etl_hts_test (
      patient_id,
      visit_id,
      encounter_id,
      encounter_uuid,
      encounter_location,
      creator,
      date_created,
      date_last_modified,
      visit_date,
      test_type,
      population_type,
      key_population_type,
      priority_population_type,
      ever_tested_for_hiv,
      months_since_last_test,
      patient_disabled,
      disability_type,
      patient_consented,
      client_tested_as,
      setting,
      approach,
      test_strategy,
      hts_entry_point,
      hts_risk_category,
      hts_risk_score,
      test_1_kit_name,
      test_1_kit_lot_no,
      test_1_kit_expiry,
      test_1_result,
      test_2_kit_name,
      test_2_kit_lot_no,
      test_2_kit_expiry,
      test_2_result,
      final_test_result,
      syphillis_test_result,
      patient_given_result,
      couple_discordant,
      referral_for,
      referral_facility,
      other_referral_facility,
      neg_referral_for,
      neg_referral_specify,
      tb_screening,
      patient_had_hiv_self_test ,
      remarks,
      voided
    )
      select
        e.patient_id,
        e.visit_id,
        e.encounter_id,
        e.uuid,
        e.location_id,
        e.creator,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.encounter_datetime as visit_date,
        max(if((o.concept_id=162084 and o.value_coded=162082 and f.uuid = "402dc5d7-46da-42d4-b2be-f43ea4ad87b0") or (f.uuid = "b08471f6-0892-4bf7-ab2b-bf79797b8ea4"), 2, 1)) as test_type ,
        max(if(o.concept_id=164930,(case o.value_coded when 164928 then "General Population" when 164929 then "Key Population" when 138643 then "Priority Population"  else null end),null)) as population_type,
        max(if(o.concept_id=160581 and o.value_coded in(105,160578,160579,165100,162277,5622), (case o.value_coded when 105 then "People who inject drugs" when 160578 then "Men who have sex with men" when 160579 then "Female sex worker" when 165100 then "Transgender" when 162277 then "People in prison and other closed settings" when 5622 then "Other"  else null end),null)) as key_population_type,
        max(if(o.concept_id=160581 and o.value_coded in(159674,162198,160549,162277,1175,165192), (case o.value_coded when 159674 then "Fisher folk" when 162198 then "Truck driver" when 160549 then "Adolescent and young girls" when 162277 then "Prisoner" when 1175 then "Not applicable" when 165192 then "Military and other uniformed services" else null end),null)) as priority_population_type,
        max(if(o.concept_id=164401,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end),null)) as ever_tested_for_hiv,
        max(if(o.concept_id=159813,o.value_numeric,null)) as months_since_last_test,
        max(if(o.concept_id=164951,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end),null)) as patient_disabled,
        concat_ws(',',nullif(max(if(o.concept_id=162558 and o.value_coded = 120291,"Hearing impairment",'')),''),
                 nullif(max(if(o.concept_id=162558 and o.value_coded =147215,"Visual impairment",'')),''),
                 nullif(max(if(o.concept_id=162558 and o.value_coded =151342,"Mentally Challenged",'')),''),
                 nullif(max(if(o.concept_id=162558 and o.value_coded = 164538,"Physically Challenged",'')),''),
                 nullif(max(if(o.concept_id=162558 and o.value_coded = 5622,"Other",'')),''),
                 nullif(max(if(o.concept_id=160632,o.value_text,'')),'')) as disability_type,
        max(if(o.concept_id=1710,(case o.value_coded when 1 then "Yes" when 0 then "No" else null end),null)) as patient_consented,
        max(if(o.concept_id=164959,(case o.value_coded when 164957 then "Individual" when 164958 then "Couple" else null end),null)) as client_tested_as,
        max(if(o.concept_id=165215,(case o.value_coded when 1537 then "Facility" when 163488 then "Community" else "" end ),null)) as setting,
        max(if(o.concept_id=163556,(case o.value_coded when 164163 then "Provider Initiated Testing(PITC)" when 164953 then "Client Initiated Testing (CITC)" else "" end ),null)) as approach,
        max(if(o.concept_id=164956,o.value_coded,null)) as test_strategy,
        max(if(o.concept_id=160540,o.value_coded,null)) as hts_entry_point,
        max(if(o.concept_id=167163,(case o.value_coded when 1407 then "Low" when 1499 then "Moderate" when 1408 then "High" when 167164 then "Very high" else "" end),null)) as hts_risk_category,
        max(if(o.concept_id=167162,o.value_numeric,null)) as hts_risk_score,
        max(if(t.test_1_result is not null, t.kit_name, null)) as test_1_kit_name,
        max(if(t.test_1_result is not null, t.lot_no, null)) as test_1_kit_lot_no,
        max(if(t.test_1_result is not null, t.expiry_date, null)) as test_1_kit_expiry,
        max(if(t.test_1_result is not null, t.test_1_result, null)) as test_1_result,
        max(if(t.test_2_result is not null, t.kit_name, null)) as test_2_kit_name,
        max(if(t.test_2_result is not null, t.lot_no, null)) as test_2_kit_lot_no,
        max(if(t.test_2_result is not null, t.expiry_date, null)) as test_2_kit_expiry,
        max(if(t.test_2_result is not null, t.test_2_result, null)) as test_2_result,
        max(if(o.concept_id=159427,(case o.value_coded when 703 then "Positive" when 664 then "Negative" when 1138 then "Inconclusive" when 163611 then "Invalid" else null end),null)) as final_test_result,
        max(if(o.concept_id=299,(case o.value_coded when 1229 then "Positive" when 1228 then "Negative" else "" end),null)) as syphillis_test_result,
        max(if(o.concept_id=164848,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end),null)) as patient_given_result,
        max(if(o.concept_id=6096,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end),null)) as couple_discordant,
        max(if(o.concept_id=1887,(case o.value_coded when 162082 then "Confirmatory test" when 162050 then "Comprehensive care center" when 164461 then "DBS for PCR" else "" end),null)) as referral_for,
        max(if(o.concept_id=160481,(case o.value_coded when 163266 then "This health facility" when 164407 then "Other health facility" else "" end),null)) as referral_facility,
        max(if(o.concept_id=161550,trim(o.value_text),null)) as other_referral_facility,
        concat_ws(',', max(if(o.concept_id = 1272 and o.value_coded = 165276, 'Risk reduction counselling', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 159612, 'Safer sex practices', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 162223, 'VMMC', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 190, 'Condom use counselling', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 1691, 'Post-exposure prophylaxis', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 167125, 'Prevention and treatment of STIs', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 118855, 'Substance abuse and mental health treatment', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 141814, 'Prevention of GBV', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 1370, 'HIV testing and re-testing', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 166536, 'Pre-Exposure Prophylaxis', null)),
                  max(if(o.concept_id = 1272 and o.value_coded = 5622, 'Other', null))) as neg_referral_for,
        max(if(o.concept_id=164359,trim(o.value_text),null)) as neg_referral_specify,
        max(if(o.concept_id=1659,(case o.value_coded when 1660 then "No TB signs" when 142177 then "Presumed TB" when 1662 then "TB Confirmed" when 160737 then "Not done" when 1111 then "On TB Treatment"  else null end),null)) as tb_screening,
        max(if(o.concept_id=164952,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end),null)) as patient_had_hiv_self_test,
        max(if(o.concept_id=163042,trim(o.value_text),null)) as remarks,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("402dc5d7-46da-42d4-b2be-f43ea4ad87b0","b08471f6-0892-4bf7-ab2b-bf79797b8ea4")
        inner join obs o on o.encounter_id = e.encounter_id and o.voided=0 and o.concept_id in (162084, 164930, 160581, 164401, 164951, 162558,160632, 1710, 164959, 164956,
                                                                                                        159427, 164848, 6096, 1659, 164952, 163042, 159813,165215,163556,161550,1887,1272,164359,160481,299,167163,167162)
        inner join (
                     select
                       o.person_id,
                       o.encounter_id,
                       o.obs_group_id,
                       max(if(o.concept_id=1040, (case o.value_coded when 703 then "Positive" when 664 then "Negative" when 163611 then "Invalid"  else null end),null)) as test_1_result ,
                       max(if(o.concept_id=1326, (case o.value_coded when 703 then "Positive" when 664 then "Negative" when 1175 then "N/A"  else null end),null)) as test_2_result ,
                       max(if(o.concept_id=164962, (case o.value_coded when 164960 then "Determine" when 164961 then "First Response" when 165351 then "Dual Kit" else null end),null)) as kit_name ,
                       max(if(o.concept_id=164964,trim(o.value_text),null)) as lot_no,
                       max(if(o.concept_id=162502,date(o.value_datetime),null)) as expiry_date
                     from obs o inner join encounter e on e.encounter_id = o.encounter_id
                       inner join person p on p.person_id=o.person_id and p.voided=0
                       inner join
                       (
                         select form_id, uuid, name from form where uuid in ("402dc5d7-46da-42d4-b2be-f43ea4ad87b0","b08471f6-0892-4bf7-ab2b-bf79797b8ea4")
                       ) ef on ef.form_id=e.form_id
                     where o.concept_id in (1040, 1326, 164962, 164964, 162502)
                     group by e.encounter_id, o.obs_group_id
                   ) t on e.encounter_id = t.encounter_id
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),creator=VALUES(creator), test_type=VALUES(test_type), population_type=VALUES(population_type),
      key_population_type=VALUES(key_population_type),priority_population_type=VALUES(priority_population_type), ever_tested_for_hiv=VALUES(ever_tested_for_hiv), patient_disabled=VALUES(patient_disabled),
      disability_type=VALUES(disability_type), patient_consented=VALUES(patient_consented), client_tested_as=VALUES(client_tested_as),
      test_strategy=VALUES(test_strategy),hts_entry_point=VALUES(hts_entry_point),hts_risk_category=VALUES(hts_risk_category),hts_risk_score=VALUES(hts_risk_score),setting=VALUES(setting),approach=VALUES(approach),
      test_1_kit_name=VALUES(test_1_kit_name), test_1_kit_lot_no=VALUES(test_1_kit_lot_no),
      test_1_kit_expiry=VALUES(test_1_kit_expiry), test_1_result=VALUES(test_1_result), test_2_kit_name=VALUES(test_2_kit_name),
      test_2_kit_lot_no=VALUES(test_2_kit_lot_no), test_2_kit_expiry=VALUES(test_2_kit_expiry), test_2_result=VALUES(test_2_result),
      final_test_result=VALUES(final_test_result), patient_given_result=VALUES(patient_given_result), couple_discordant=VALUES(couple_discordant),
      tb_screening=VALUES(tb_screening), neg_referral_for=VALUES(neg_referral_for), patient_had_hiv_self_test=VALUES(patient_had_hiv_self_test),
      remarks=VALUES(remarks), voided=VALUES(voided)
    ;

    END $$
-- DELIMITER ;

-- ------------------------------------ POPULATE HTS LINKAGES AND REFERRALS -------------------------------

DROP PROCEDURE IF EXISTS sp_update_hts_linkage_and_referral $$
CREATE PROCEDURE sp_update_hts_linkage_and_referral(IN last_update_time DATETIME)
  BEGIN

    INSERT INTO kenyaemr_etl.etl_hts_referral_and_linkage (
      patient_id,
      visit_id,
      encounter_id,
      encounter_uuid,
      encounter_location,
      creator,
      date_created,
      date_last_modified,
      visit_date,
      tracing_type,
      tracing_status,
      referral_facility,
      facility_linked_to,
      enrollment_date,
      art_start_date,
      ccc_number,
      provider_handed_to,
      cadre,
      voided
    )
      select
        e.patient_id,
        e.visit_id,
        e.encounter_id,
        e.uuid,
        e.location_id,
        e.creator,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.encounter_datetime as visit_date,
        max(if(o.concept_id=164966,(case o.value_coded when 1650 then "Phone" when 164965 then "Physical" else "" end),null)) as tracing_type ,
        max(if(o.concept_id=159811,(case o.value_coded when 1065 then "Contacted and linked" when 1066 then "Contacted but not linked" else "" end),null)) as tracing_status,
        max(if(o.concept_id=160481,(case o.value_coded when 163266 then "This health facility" when 164407 then "Other health facility" else "" end),null)) as referral_facility,
        max(if(o.concept_id=162724,trim(o.value_text),null)) as facility_linked_to,
        max(if(o.concept_id=160555,o.value_datetime,null)) as enrollment_date,
        max(if(o.concept_id=159599,o.value_datetime,null)) as art_start_date,
        max(if(o.concept_id=162053,o.value_numeric,null)) as ccc_number,
        max(if(o.concept_id=1473,trim(o.value_text),null)) as provider_handed_to,
        max(if(o.concept_id=162577,(case o.value_coded when 1577 then "Nurse"
                                    when 1574 then "Clinical Officer/Doctor"
                                    when 1555 then "Community Health Worker"
                                    when 1540 then "Employee"
                                    when 5488 then "Adherence counsellor"
                                    when 5622 then "Other" else "" end),null)) as cadre,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id = e.form_id and f.uuid in ("050a7f12-5c52-4cad-8834-863695af335d","15ed03d2-c972-11e9-a32f-2a2ae2dbcce4")
        left outer join obs o on o.encounter_id = e.encounter_id and o.concept_id in (164966, 159811, 162724, 160555, 159599, 162053, 1473,162577,160481) and o.voided=0
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id,e.visit_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),creator=VALUES(creator), tracing_type=VALUES(tracing_type), tracing_status=VALUES(tracing_status),
      facility_linked_to=VALUES(facility_linked_to), ccc_number=VALUES(ccc_number), provider_handed_to=VALUES(provider_handed_to), cadre=VALUES(cadre)
    ;

    -- fetch locally enrolled clients who had gone through HTS
    /*
  INSERT INTO kenyaemr_etl.etl_hts_referral_and_linkage (
  patient_id,
  visit_id,
  encounter_id,
  encounter_uuid,
  encounter_location,
  creator,
  date_created,
  visit_date,
  tracing_status,
  facility_linked_to,
  ccc_number,
  voided
)
select
    e.patient_id,
    e.visit_id,
    e.encounter_id,
    e.uuid,
    e.location_id,
    e.creator,
    e.date_created,
    e.encounter_datetime as visit_date,
    "Enrolled" as contact_status,
    (select name from location
        where location_id in (select property_value
        from global_property
        where property='kenyaemr.defaultLocation'))  as facility_linked_to,
    pi.identifier as ccc_number,
    e.voided
 from encounter e
 inner join encounter_type et on e.encounter_type = et.encounter_type_id and et.uuid = "de78a6be-bfc5-4634-adc3-5f1a280455cc"
 inner join form f on f.form_id = e.form_id and f.uuid in ("402dc5d7-46da-42d4-b2be-f43ea4ad87b0","b08471f6-0892-4bf7-ab2b-bf79797b8ea4")
 left outer join patient_identifier pi on pi.patient_id = e.patient_id
 left join patient_identifier_type pit on pi.identifier_type=pit.patient_identifier_type_id and pit.uuid = '05ee9cf4-7242-4a17-b4d4-00f707265c8a'
where e.date_created >= last_update_time
or e.date_changed >= last_update_time
or e.date_voided >= last_update_time
group by e.patient_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date), ccc_number=VALUES(ccc_number)
;*/
    END $$
-- DELIMITER ;

-- ------------------------ update hts referrals ------------------------------------

DROP PROCEDURE IF EXISTS sp_update_hts_referral $$
CREATE PROCEDURE sp_update_hts_referral(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing hts referrals";
    INSERT INTO kenyaemr_etl.etl_hts_referral (
      patient_id,
      visit_id,
      encounter_id,
      encounter_uuid,
      encounter_location,
      creator,
      date_created,
      date_last_modified,
      visit_date,
      facility_referred_to,
      date_to_enrol,
      remarks,
      voided
    )
      select
        e.patient_id,
        e.visit_id,
        e.encounter_id,
        e.uuid,
        e.location_id,
        e.creator,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.encounter_datetime as visit_date,
        max(if(o.concept_id=161550,o.value_text,null)) as facility_referred_to ,
        max(if(o.concept_id=161561,o.value_datetime,null)) as date_to_enrol,
        max(if(o.concept_id=163042,o.value_text,null)) as remarks,
        e.voided voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id = e.form_id and f.uuid = "9284828e-ce55-11e9-a32f-2a2ae2dbcce4"
        left outer join obs o on o.encounter_id = e.encounter_id and o.concept_id in (161550, 161561, 163042) and o.voided=0
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),creator=VALUES(creator), facility_referred_to=VALUES(facility_referred_to), date_to_enrol=VALUES(date_to_enrol),
      remarks=VALUES(remarks), voided=VALUES(voided);
    SELECT "Completed processing hts referrals", CONCAT("Time: ", NOW());

    END $$

-- ------------- populate etl_ipt_screening-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_ipt_screening $$
CREATE PROCEDURE sp_update_etl_ipt_screening(IN last_update_time DATETIME)
  BEGIN

    insert into kenyaemr_etl.etl_ipt_screening(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      encounter_id,
      location_id,
      ipt_started,
      date_created,
      date_last_modified
    )
      select
        e.patient_id, e.uuid, e.creator, e.visit_id, e.encounter_datetime, e.encounter_id, e.location_id,
        max(o.value_coded) as ipt_started,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("22c68f86-bbf0-49ba-b2d1-23fa7ccf0259", "59ed8e62-7f1f-40ae-a2e3-eabe350277ce")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id=1265 and o.voided=0
      where e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date), ipt_started=values(ipt_started);
    SELECT "Completed processing TPT screening forms", CONCAT("Time: ", NOW());
    END $$
-- DELIMITER ;


-- ------------- populate etl_ipt_followup-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_ipt_follow_up $$
CREATE PROCEDURE sp_update_etl_ipt_follow_up(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing TPT followup forms", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_ipt_follow_up(
      patient_id,
      uuid,
      provider,
      visit_id,
      visit_date,
      encounter_id,
      location_id,
      ipt_due_date,
      date_collected_ipt,
      hepatotoxity,
      peripheral_neuropathy,
      rash,
      adherence,
      action_taken,
      date_created,
      date_last_modified,
      voided
    )
      select
        e.patient_id, e.uuid, e.creator, e.visit_id, e.encounter_datetime, e.encounter_id, e.location_id,
        max(if(o.concept_id = 164073, o.value_datetime, null )) as ipt_due_date,
        max(if(o.concept_id = 164074, o.value_datetime, null )) as date_collected_ipt,
        max(if(o.concept_id = 159098, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end), null )) as hepatotoxity,
        max(if(o.concept_id = 118983, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end), null )) as peripheral_neuropathy,
        max(if(o.concept_id = 512, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else null end), null )) as rash,
        max(if(o.concept_id = 164075, (case o.value_coded when 159407 then "Poor" when 159405 then "Good" when 159406 then "Fair" when 164077 then "Very Good" when 164076 then "Excellent" when 1067 then "Unknown" else null end), null )) as adherence,
        max(if(o.concept_id = 160632, trim(o.value_text), null )) as action_taken,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid in('aadeafbe-a3b1-4c57-bc76-8461b778ebd6')
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (164073,164074,159098,118983,512,164075,160632)
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      ipt_due_date=VALUES(ipt_due_date),
      date_collected_ipt=VALUES(date_collected_ipt),
      hepatotoxity=VALUES(hepatotoxity),
      peripheral_neuropathy=VALUES(peripheral_neuropathy),
      rash=VALUES(rash),
      adherence=VALUES(adherence),
      action_taken=VALUES(action_taken),voided=VALUES(voided);

    END $$
-- DELIMITER ;

DROP PROCEDURE IF EXISTS sp_update_etl_ccc_defaulter_tracing $$
CREATE PROCEDURE sp_update_etl_ccc_defaulter_tracing(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing ccc defaulter tracing form", CONCAT("Time: ", NOW());

    insert into kenyaemr_etl.etl_ccc_defaulter_tracing(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      tracing_type,
      missed_appointment_date,
      reason_for_missed_appointment,
      non_coded_missed_appointment_reason,
      tracing_outcome,
      attempt_number,
      is_final_trace,
      true_status,
      cause_of_death,
      comments,
      booking_date,
      date_created,
      date_last_modified
    )
      select
        e.uuid, e.creator, e.patient_id, e.visit_id, e.encounter_datetime, e.location_id, e.encounter_id,
        max(if(o.concept_id = 164966, o.value_coded, null )) as tracing_type,
        max(if(o.concept_id=164093,date(o.value_datetime),null)) as missed_appointment_date,
        max(if(o.concept_id = 1801, o.value_coded, null )) as reason_for_missed_appointment,
        max(if(o.concept_id = 163513, o.value_text, "" )) as non_coded_missed_appointment_reason,
        max(if(o.concept_id = 160721, o.value_coded, null )) as tracing_outcome,
        max(if(o.concept_id = 1639, value_numeric, "" )) as attempt_number,
        max(if(o.concept_id = 163725, o.value_coded, "" )) as is_final_trace,
        max(if(o.concept_id = 160433, o.value_coded, "" )) as true_status,
        max(if(o.concept_id = 1599, o.value_coded, "" )) as cause_of_death,
        max(if(o.concept_id = 160716, o.value_text, "" )) as comments,
        max(if(o.concept_id=163526,date(o.value_datetime),null)) as booking_date,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("a1a62d1e-2def-11e9-b210-d663bd873d93")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (164966,164093, 1801, 163513, 160721, 1639, 163725, 160433, 1599, 160716,163526) and o.voided=0
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      tracing_type=VALUES(tracing_type),
      missed_appointment_date=VALUES(missed_appointment_date),
      reason_for_missed_appointment=VALUES(reason_for_missed_appointment),
      tracing_outcome=VALUES(tracing_outcome),
      attempt_number=VALUES(attempt_number),
      is_final_trace=VALUES(is_final_trace),
      true_status=VALUES(true_status),
      cause_of_death=VALUES(cause_of_death),
      comments=VALUES(comments),
      booking_date=VALUES(booking_date);

    END $$
-- ------------- Update etl_ART_preparation-------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_ART_preparation $$
CREATE PROCEDURE sp_update_etl_ART_preparation(IN last_update_time DATETIME)
  BEGIN
    insert into kenyaemr_etl.etl_ART_preparation(
      uuid,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      provider,
      understands_hiv_art_benefits,
      screened_negative_substance_abuse,
      screened_negative_psychiatric_illness,
      HIV_status_disclosure,
      trained_drug_admin,
      informed_drug_side_effects,
      caregiver_committed,
      adherance_barriers_identified,
      caregiver_location_contacts_known,
      ready_to_start_art,
      identified_drug_time,
      treatment_supporter_engaged,
      support_grp_meeting_awareness,
      enrolled_in_reminder_system,
      other_support_systems,
      date_created,
      date_last_modified
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.creator,
        max(if(o.concept_id=1729,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as understands_hiv_art_benefits,
        max(if(o.concept_id=160246,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as screened_negative_substance_abuse,
        max(if(o.concept_id=159891,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as screened_negative_psychiatric_illness,
        max(if(o.concept_id=1048,(case o.value_coded when 1 then "Yes" when 0 then "No" else "" end), "" )) as HIV_status_disclosure,
        max(if(o.concept_id=164425,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as trained_drug_admin,
        max(if(o.concept_id=121764,(case o.value_coded when 1 then "Yes" when 0 then "No" else "" end), "" )) as informed_drug_side_effects,
        max(if(o.concept_id=5619,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as caregiver_committed,
        max(if(o.concept_id=159707,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as adherance_barriers_identified,
        max(if(o.concept_id=163089,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as caregiver_location_contacts_known,
        max(if(o.concept_id=162695,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as ready_to_start_art,
        max(if(o.concept_id=160119,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as identified_drug_time,
        max(if(o.concept_id=164886,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as treatment_supporter_engaged,
        max(if(o.concept_id=163766,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as support_grp_meeting_awareness,
        max(if(o.concept_id=163164,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as enrolled_in_reminder_system,
        max(if(o.concept_id=164360,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as other_support_systems,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in (1729,160246,159891,1048,164425,121764,5619,159707,163089,162695,160119,164886,163766,163164,164360)
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('782a4263-3ac9-4ce8-b316-534571233f12')
        ) f on f.form_id= e.form_id
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time

      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),provider=VALUES(provider),
      understands_hiv_art_benefits=VALUES(understands_hiv_art_benefits),screened_negative_substance_abuse=VALUES(screened_negative_substance_abuse),
      screened_negative_psychiatric_illness=VALUES(screened_negative_psychiatric_illness),HIV_status_disclosure=VALUES(HIV_status_disclosure),
      trained_drug_admin=VALUES(trained_drug_admin),informed_drug_side_effects=VALUES(informed_drug_side_effects),
      caregiver_committed=VALUES(caregiver_committed),adherance_barriers_identified=VALUES(adherance_barriers_identified),caregiver_location_contacts_known=VALUES(caregiver_location_contacts_known),
      ready_to_start_art=VALUES(ready_to_start_art),
      identified_drug_time=VALUES(identified_drug_time),treatment_supporter_engaged=VALUES(treatment_supporter_engaged),support_grp_meeting_awareness=VALUES(support_grp_meeting_awareness),
      enrolled_in_reminder_system=VALUES(enrolled_in_reminder_system),other_support_systems=VALUES(other_support_systems);

    END $$

-- ------------- update etl_enhanced_adherence-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_enhanced_adherence $$
CREATE PROCEDURE sp_update_etl_enhanced_adherence(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing Enhanced Adherence ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_enhanced_adherence(

      uuid,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      provider,
      session_number,
      first_session_date,
      pill_count,
      arv_adherence,
      has_vl_results,
      vl_results_suppressed,
      vl_results_feeling,
      cause_of_high_vl,
      way_forward,
      patient_hiv_knowledge,
      patient_drugs_uptake,
      patient_drugs_reminder_tools,
      patient_drugs_uptake_during_travels,
      patient_drugs_side_effects_response,
      patient_drugs_uptake_most_difficult_times,
      patient_drugs_daily_uptake_feeling,
      patient_ambitions,
      patient_has_people_to_talk,
      patient_enlisting_social_support,
      patient_income_sources,
      patient_challenges_reaching_clinic,
      patient_worried_of_accidental_disclosure,
      patient_treated_differently,
      stigma_hinders_adherence,
      patient_tried_faith_healing,
      patient_adherence_improved,
      patient_doses_missed,
      review_and_barriers_to_adherence,
      other_referrals,
      appointments_honoured,
      referral_experience,
      home_visit_benefit,
      adherence_plan,
      next_appointment_date,
      date_created,
      date_last_modified
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.creator,
        max(if(o.concept_id=1639,o.value_numeric,null)) as session_number,
        max(if(o.concept_id=164891,o.value_datetime,null)) as first_session_date,
        max(if(o.concept_id=162846,o.value_numeric,null)) as pill_count,
        max(if(o.concept_id=1658,(case o.value_coded when 159405 then "Good" when 163794 then "Inadequate" when 159407 then "Poor" else "" end), "" )) as arv_adherence,
        max(if(o.concept_id=164848,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as has_vl_results,
        max(if(o.concept_id=163310,(case o.value_coded when 1302 then "Suppressed" when 1066 then "Unsuppresed" else "" end), "" )) as vl_results_suppressed,
        max(if(o.concept_id=164981,trim(o.value_text),null)) as vl_results_feeling,
        max(if(o.concept_id=164982,trim(o.value_text),null)) as cause_of_high_vl,
        max(if(o.concept_id=160632,trim(o.value_text),null)) as way_forward,
        max(if(o.concept_id=164983,trim(o.value_text),null)) as patient_hiv_knowledge,
        max(if(o.concept_id=164984,trim(o.value_text),null)) as patient_drugs_uptake,
        max(if(o.concept_id=164985,trim(o.value_text),null)) as patient_drugs_reminder_tools,
        max(if(o.concept_id=164986,trim(o.value_text),null)) as patient_drugs_uptake_during_travels,
        max(if(o.concept_id=164987,trim(o.value_text),null)) as patient_drugs_side_effects_response,
        max(if(o.concept_id=164988,trim(o.value_text),null)) as patient_drugs_uptake_most_difficult_times,
        max(if(o.concept_id=164989,trim(o.value_text),null)) as patient_drugs_daily_uptake_feeling,
        max(if(o.concept_id=164990,trim(o.value_text),null)) as patient_ambitions,
        max(if(o.concept_id=164991,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as patient_has_people_to_talk,
        max(if(o.concept_id=164992,trim(o.value_text),null)) as patient_enlisting_social_support,
        max(if(o.concept_id=164993,trim(o.value_text),null)) as patient_income_sources,
        max(if(o.concept_id=164994,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as patient_challenges_reaching_clinic,
        max(if(o.concept_id=164995,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as patient_worried_of_accidental_disclosure,
        max(if(o.concept_id=164996,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as patient_treated_differently,
        max(if(o.concept_id=164997,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as stigma_hinders_adherence,
        max(if(o.concept_id=164998,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as patient_tried_faith_healing,
        max(if(o.concept_id=1898,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as patient_adherence_improved,
        max(if(o.concept_id=160110,(case o.value_coded when 1 then "Yes" when 0 then "No" else "" end), "" )) as patient_doses_missed,
        max(if(o.concept_id=163108,trim(o.value_text),null)) as review_and_barriers_to_adherence,
        max(if(o.concept_id=1272,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as other_referrals,
        max(if(o.concept_id=164999,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as appointments_honoured,
        max(if(o.concept_id=165000,trim(o.value_text),null)) as referral_experience,
        max(if(o.concept_id=165001,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as home_visit_benefit,
        max(if(o.concept_id=165002,trim(o.value_text),null)) as adherence_plan,
        max(if(o.concept_id=5096,o.value_datetime,null)) as next_appointment_date,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0
                            and o.concept_id in(1639,164891,162846,1658,164848,163310,164981,164982,160632,164983,164984,164985,164986,164987,164988,164989,164990,164991,164992,164993,164994,164995,164996,164997,164998,1898,160110,163108,1272,164999,165000,165001,165002,5096)

        inner join
        (
          select form_id, uuid,name from form where
            uuid in('c483f10f-d9ee-4b0d-9b8c-c24c1ec24701')
        ) f on f.form_id= e.form_id
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time

      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_id=VALUES(encounter_id),provider=VALUES(provider),
      session_number=VALUES(session_number),first_session_date=VALUES(first_session_date),
      pill_count=VALUES(pill_count),arv_adherence=VALUES(arv_adherence),
      has_vl_results=VALUES(has_vl_results),vl_results_suppressed=VALUES(vl_results_suppressed),
      patient_has_people_to_talk=VALUES(patient_has_people_to_talk),patient_challenges_reaching_clinic=VALUES(patient_challenges_reaching_clinic),patient_worried_of_accidental_disclosure=VALUES(patient_worried_of_accidental_disclosure),
      patient_treated_differently=VALUES(patient_treated_differently),
      stigma_hinders_adherence=VALUES(stigma_hinders_adherence),patient_tried_faith_healing=VALUES(patient_tried_faith_healing),patient_adherence_improved=VALUES(patient_adherence_improved),
      patient_doses_missed=VALUES(patient_doses_missed),other_referrals=VALUES(other_referrals),appointments_honoured=VALUES(appointments_honoured),
      home_visit_benefit=VALUES(home_visit_benefit),next_appointment_date=VALUES(next_appointment_date);

    END $$
-- ------------- update etl_patient_triage-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_patient_triage $$
CREATE PROCEDURE sp_update_etl_patient_triage(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing Patient Triage ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_patient_triage(
      uuid,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      visit_reason,
      weight,
      height,
      systolic_pressure,
      diastolic_pressure,
      temperature,
      pulse_rate,
      respiratory_rate,
      oxygen_saturation,
      muac,
      nutritional_status,
      last_menstrual_period,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=160430,trim(o.value_text),null)) as visit_reason,
        max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
        max(if(o.concept_id=5090,o.value_numeric,null)) as height,
        max(if(o.concept_id=5085,o.value_numeric,null)) as systolic_pressure,
        max(if(o.concept_id=5086,o.value_numeric,null)) as diastolic_pressure,
        max(if(o.concept_id=5088,o.value_numeric,null)) as temperature,
        max(if(o.concept_id=5087,o.value_numeric,null)) as pulse_rate,
        max(if(o.concept_id=5242,o.value_numeric,null)) as respiratory_rate,
        max(if(o.concept_id=5092,o.value_numeric,null)) as oxygen_saturation,
        max(if(o.concept_id=1343,o.value_numeric,null)) as muac,
        max(if(o.concept_id=163300,o.value_coded,null)) as nutritional_status,
        max(if(o.concept_id=1427,date(o.value_datetime),null)) as last_menstrual_period,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid in('d1059fb9-a079-4feb-a749-eedd709ae542','a0034eee-1940-4e35-847f-97537a35d05e','465a92f2-baf8-42e9-9612-53064be868e8')
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (160430,5089,5090,5085,5086,5088,5087,5242,5092,1343,163300,1427)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),weight=VALUES(weight),height=VALUES(height),systolic_pressure=VALUES(systolic_pressure),diastolic_pressure=VALUES(diastolic_pressure),
      temperature=VALUES(temperature),pulse_rate=VALUES(pulse_rate),respiratory_rate=VALUES(respiratory_rate),
      oxygen_saturation=VALUES(oxygen_saturation),muac=VALUES(muac),nutritional_status=VALUES(nutritional_status),last_menstrual_period=VALUES(last_menstrual_period),voided=VALUES(voided);

    END $$


-- ------------- populate etl_prep_behaviour_risk_assessment-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_prep_behaviour_risk_assessment $$
CREATE PROCEDURE sp_update_etl_prep_behaviour_risk_assessment(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing Behaviour risk assessment", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_prep_behaviour_risk_assessment(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      sexual_partner_hiv_status,
      sexual_partner_on_art,
      risk,
      high_risk_partner,
      sex_with_multiple_partners,
      ipv_gbv,
      transactional_sex,
      recent_sti_infected,
      recurrent_pep_use,
      recurrent_sex_under_influence,
      inconsistent_no_condom_use,
      sharing_drug_needles,
      other_reasons,
      other_reason_specify,
      risk_education_offered,
      risk_reduction,
      willing_to_take_prep,
      reason_not_willing,
      risk_edu_offered,
      risk_education,
      referral_for_prevention_services,
      referral_facility,
      time_partner_hiv_positive_known,
      partner_enrolled_ccc,
      partner_ccc_number,
      partner_art_start_date,
      serodiscordant_confirmation_date,
      HIV_serodiscordant_duration_months,
      recent_unprotected_sex_with_positive_partner,
      children_with_hiv_positive_partner,
      voided
    )
      select
        e.uuid, e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,e.date_created,
                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                max(if(o.concept_id = 1436, (case o.value_coded when 703 then "HIV Positive" when 664 then "HIV Negative" when 1067 then "Unknown" else "" end), "" )) as sexual_partner_hiv_status,
                max(if(o.concept_id = 160119, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as sexual_partner_on_art,
                CONCAT_WS(',',max(if(o.concept_id = 163310 and o.value_coded = 162185,  "Detectable viral load",NULL)),
                  max(if(o.concept_id = 163310 and o.value_coded = 160119,  "On ART for less than 6 months",NULL)),
                  max(if(o.concept_id = 163310 and o.value_coded = 160571,  "Couple is trying to concieve",NULL)),
                  max(if(o.concept_id = 163310 and o.value_coded = 159598,  "Suspected poor adherence",NULL))) as risk,
                max(if(o.concept_id = 160581, (case o.value_coded when 1065 then "High risk partner" else "" end), "" )) as high_risk_partner,
                max(if(o.concept_id = 159385, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as sex_with_multiple_partners,
                max(if(o.concept_id = 160579, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as ipv_gbv,
                max(if(o.concept_id = 156660, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as transactional_sex,
                max(if(o.concept_id = 164845, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as recent_sti_infected,
                max(if(o.concept_id = 165088, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as recurrent_pep_use,
                max(if(o.concept_id = 165089, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as recurrent_sex_under_influence,
                max(if(o.concept_id = 165090, (case o.value_coded when 1065 then "Yes" else "" end), "" )) as inconsistent_no_condom_use,
                max(if(o.concept_id = 165091, (case o.value_coded when 138643 then "Risk" when 1066 then "No risk" else "" end), "" )) as sharing_drug_needles,
                max(if(o.concept_id = 165241, (case o.value_coded when 1065 then "Yes" when 1066 then "No"  else "" end), "" )) as other_reasons,
                max(if(o.concept_id = 160632, o.value_text, null )) as other_reason_specify,
                max(if(o.concept_id = 165053, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as risk_education_offered,
                max(if(o.concept_id = 165092, o.value_text, null )) as risk_reduction,
                max(if(o.concept_id = 165094, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as willing_to_take_prep,
                CONCAT_WS(',',max(if(o.concept_id = 1743 and o.value_coded = 1107,  "None",NULL)),
                  max(if(o.concept_id = 1743 and o.value_coded = 159935,  "Side effects(ADR)",NULL)),
                  max(if(o.concept_id = 1743 and o.value_coded = 164997,  "Stigma",NULL)),
                  max(if(o.concept_id = 1743 and o.value_coded = 160588,  "Pill burden",NULL)),
                  max(if(o.concept_id = 1743 and o.value_coded = 164401,  "Too many HIV tests",NULL)),
                  max(if(o.concept_id = 1743 and o.value_coded = 161888,  "Taking pills for a long time",NULL))) as reason_not_willing,
                max(if(o.concept_id = 161595, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as risk_edu_offered,
                max(if(o.concept_id = 161011, o.value_text, null )) as risk_education,
                concat_ws(',',max(if(o.concept_id = 165093 and o.value_coded = 165276,'Risk reduction counselling',NULL)),
                max(if(o.concept_id = 165093 and o.value_coded = 159612,'Safer sex practices',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 162223,'vmmc-referral',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 161594,'Consistent and correct use of male and female Condom with compatible lubricant',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 165149,'Post-exposure prophylaxis',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 164882,'Prevention and treatment of STIs',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 165151,'Substance abuse and mental health treatment',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 165273,'Prevention of GBV',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 1459,'HIV testing and re-testing',NULL)),
                  max(if(o.concept_id = 165093 and o.value_coded = 5622,'Other',NULL)),
                  max(if(o.concept_id = 161550, o.value_text, NULL))) as referral_for_prevention_services,
                max(if(o.concept_id = 161550, o.value_text, null )) as referral_facility,
                max(if(o.concept_id = 160082, o.value_datetime, null )) as time_partner_hiv_positive_known,
                max(if(o.concept_id = 165095, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as partner_enrolled_ccc,
                max(if(o.concept_id = 162053, o.value_numeric, null )) as partner_ccc_number,
                max(if(o.concept_id = 159599, o.value_datetime, null )) as partner_art_start_date,
                max(if(o.concept_id = 165096, o.value_datetime, null )) as serodiscordant_confirmation_date,
                max(if(o.concept_id = 164393, o.value_numeric * 12, null )) + max(if(o.concept_id = 165356, o.value_numeric, null )) as HIV_serodiscordant_duration_months,
                max(if(o.concept_id = 165097, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as recent_unprotected_sex_with_positive_partner,
                max(if(o.concept_id = 1825, o.value_numeric, null )) as children_with_hiv_positive_partner,
                e.voided as voided

      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("40374909-05fc-4af8-b789-ed9c394ac785")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (1436,160119,163310,160581,159385,160579,156660,164845,165088,165089,165090,165241,160632,165091,165053,165092,165094,1743,161595,161011,165093,161550,160082,165095,162053,159599,165096,1825,164393,165356) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      sexual_partner_hiv_status=VALUES(sexual_partner_hiv_status),
      sexual_partner_on_art=VALUES(sexual_partner_on_art),
      risk=VALUES(risk),
      high_risk_partner=VALUES(high_risk_partner),
      sex_with_multiple_partners=VALUES(sex_with_multiple_partners),
      ipv_gbv=VALUES(ipv_gbv),
      transactional_sex=VALUES(transactional_sex),
      recent_sti_infected=VALUES(recent_sti_infected),
      recurrent_pep_use=VALUES(recurrent_pep_use),
      recurrent_sex_under_influence=VALUES(recurrent_sex_under_influence),
      inconsistent_no_condom_use=VALUES(inconsistent_no_condom_use),
      sharing_drug_needles=VALUES(sharing_drug_needles),
      other_reasons=VALUES(other_reasons),
      other_reason_specify=VALUES(other_reason_specify),
      risk_education_offered=VALUES(risk_education_offered),
      risk_reduction=VALUES(risk_reduction),
      willing_to_take_prep=VALUES(willing_to_take_prep),
      reason_not_willing=VALUES(reason_not_willing),
      risk_edu_offered=VALUES(risk_edu_offered),
      risk_education=VALUES(risk_education),
      referral_for_prevention_services=VALUES(referral_for_prevention_services),
      referral_facility=VALUES(referral_facility),
      time_partner_hiv_positive_known=VALUES(time_partner_hiv_positive_known),
      partner_enrolled_ccc=VALUES(partner_enrolled_ccc),
      partner_ccc_number=VALUES(partner_ccc_number),
      partner_art_start_date=VALUES(partner_art_start_date),
      serodiscordant_confirmation_date=VALUES(serodiscordant_confirmation_date),
      HIV_serodiscordant_duration_months=VALUES(HIV_serodiscordant_duration_months),
      recent_unprotected_sex_with_positive_partner=VALUES(recent_unprotected_sex_with_positive_partner),
      children_with_hiv_positive_partner=VALUES(children_with_hiv_positive_partner),
      voided=VALUES(voided);
    END $$

-- ------------- populate etl_prep_monthly_refill-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_prep_monthly_refill $$
CREATE PROCEDURE sp_update_etl_prep_monthly_refill(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing monthly refill", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_prep_monthly_refill(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      risk_for_hiv_positive_partner,
      client_assessment,
      adherence_assessment,
      poor_adherence_reasons,
      other_poor_adherence_reasons,
      adherence_counselling_done,
      prep_status,
      prescribed_prep_today,
      prescribed_regimen,
      prescribed_regimen_months,
      prep_discontinue_reasons,
      prep_discontinue_other_reasons,
      appointment_given,
      next_appointment,
      remarks,
      voided
    )
      select
        e.uuid, e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,e.date_created,
                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                max(if(o.concept_id = 1169, (case o.value_coded when 160571 then "Couple is trying to conceive" when 159598 then "Suspected poor adherence"
                                             when 160119 then "On ART for less than 6 months" when 162854 then "Not on ART" else "" end), "" )) as risk_for_hiv_positive_partner,
                max(if(o.concept_id = 162189, (case o.value_coded when 159385 then "Has Sex with more than one partner" when 1402 then "Sex partner(s)at high risk for HIV and HIV status unknown"
                                               when 160579 then "Transactional sex" when 165088 then "Recurrent sex under influence of alcohol/recreational drugs" when 165089 then "Inconsistent or no condom use" when 165090 then "Injecting drug use with shared needles and/or syringes"
                                               when 164845 then "Recurrent use of Post Exposure Prophylaxis (PEP)" when 112992 then "Recent STI" when 141814 then "Ongoing IPV/GBV"  else "" end), "" )) as client_assessment,
                max(if(o.concept_id = 164075, (case o.value_coded when 159405 then "Good" when 159406 then "Fair"
                                               when 159407 then "Poor" when 1067 then "Good,Fair,Poor,N/A(Did not pick PrEP at last"  else "" end), "" )) as adherence_assessment,
                max(if(o.concept_id = 160582, (case o.value_coded when 163293 then "Sick" when 1107 then "None"
                                               when 164997 then "Stigma" when 160583 then "Shared with others" when 1064 then "No perceived risk"
                                               when 160588 then "Pill burden" when 160584 then "Lost/out of pills" when 1056 then "Separated from HIV+"
                                               when 159935 then "Side effects" when 160587 then "Forgot" when 5622 then "Other-specify" else "" end), "" )) as poor_adherence_reasons,
                max(if(o.concept_id = 160632, o.value_text, null )) as other_poor_adherence_reasons,
                max(if(o.concept_id = 164425, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as adherence_counselling_done,
                max(if(o.concept_id = 161641, (case o.value_coded when 159836 then "Discontinue" when 159835 then "Continue" else "" end), "" )) as prep_status,
                max(if(o.concept_id = 1417, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as prescribed_prep_today,
                max(if(o.concept_id = 164515, (case o.value_coded when 161364 then "TDF/3TC" when 84795 then "TDF"  when 104567 then "FTC/TDF" else "" end), "" )) as prescribed_regimen,
                max(if(o.concept_id = 164433, o.value_text, null )) as prescribed_regimen_months,
                max(if(o.concept_id = 161555, (case o.value_coded when 138571 then "HIV test is positive" when 113338 then "Renal dysfunction"
                                               when 1302 then "Viral suppression of HIV+" when 159598 then "Not adherent to PrEP" when 164401 then "Too many HIV tests"
                                               when 162696 then "Client request" when 5622 then "other"  else "" end), "" )) as prep_discontinue_reasons,
                max(if(o.concept_id = 160632, o.value_text, null )) as prep_discontinue_other_reasons,
                max(if(o.concept_id = 164999, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as appointment_given,
                max(if(o.concept_id = 5096, o.value_datetime, null )) as next_appointment,
                max(if(o.concept_id = 161011, o.value_text, null )) as remarks,
                e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("291c03c8-a216-11e9-a2a3-2a2ae2dbcce4")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (1169,162189,164075,160582,160632,164425,161641,1417,164515,164433,161555,164999,161011,5096) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      risk_for_hiv_positive_partner=VALUES(risk_for_hiv_positive_partner),
      client_assessment=VALUES(client_assessment),
      adherence_assessment=VALUES(adherence_assessment),
      poor_adherence_reasons=VALUES(poor_adherence_reasons),
      other_poor_adherence_reasons=VALUES(other_poor_adherence_reasons),
      adherence_counselling_done=VALUES(adherence_counselling_done),
      prep_status=VALUES(prep_status),
      prescribed_prep_today=VALUES(prescribed_prep_today),
      prescribed_regimen=VALUES(prescribed_regimen),
      prescribed_regimen_months=VALUES(prescribed_regimen_months),
      prep_discontinue_reasons=VALUES(prep_discontinue_reasons),
      prep_discontinue_other_reasons=VALUES(prep_discontinue_other_reasons),
      appointment_given=VALUES(appointment_given),
      next_appointment=VALUES(next_appointment),
      remarks=VALUES(remarks),
      voided=VALUES(voided);
    END $$

-- ------------- populate etl_prep_discontinuation-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_prep_discontinuation $$
CREATE PROCEDURE sp_update_etl_prep_discontinuation(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing PrEP discontinuation", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_prep_discontinuation(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      discontinue_reason,
      care_end_date,
      last_prep_dose_date,
      voided
    )
      select
        e.uuid, e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,e.date_created,
                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
               max(if(o.concept_id = 161555, (case o.value_coded when 138571 then "HIV test is positive"
                                       when 113338 then "Renal dysfunction"
                                       when 1302 then "Viral suppression of HIV+"
                                       when 159598 then "Not adherent to PrEP"
                                       when 164401 then "Too many HIV tests"
                                       when 162696 then "Client request"
                                       when 150506 then "Intimate partner violence"
                                       when 978 then "Self Discontinuation"
                                       when 160581 then "Low risk of HIV"
                                       when 121760 then "Adverse drug reaction"
                                       when 160034 then "Died"
                                       when 159492 then "Transferred Out"
                                       when 5240 then "Defaulters (missed drugs pick ups)"
                                       when 162479 then "Partner Refusal"
                                       when 5622 then "Other" else "" end), "" )) as discontinue_reason,
                max(if(o.concept_id = 164073, o.value_datetime, null )) as care_end_date,
                max(if(o.concept_id = 162549, o.value_datetime, null )) as last_prep_dose_date,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("467c4cc3-25eb-4330-9cf6-e41b9b14cc10")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (161555,164073,162549) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      discontinue_reason=VALUES(discontinue_reason),
      care_end_date=VALUES(care_end_date),
      voided=VALUES(voided);
    END $$

-- ------------- populate etl_prep_enrollment-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_prep_enrolment $$
CREATE PROCEDURE sp_update_etl_prep_enrolment(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing PrEP enrolment", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_prep_enrolment(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      patient_type,
      population_type,
      kp_type,
      transfer_in_entry_point,
      referred_from,
      transit_from,
      transfer_in_date,
      transfer_from,
      initial_enrolment_date,
      date_started_prep_trf_facility,
      previously_on_prep,
      regimen,
      prep_last_date,
      in_school,
      buddy_name,
      buddy_alias,
      buddy_relationship,
      buddy_phone,
      buddy_alt_phone,
      voided
    )
      select
        e.uuid, e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,e.date_created,
                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                max(if(o.concept_id = 164932, (case o.value_coded when 164144 then "New Patient" when 160563 then "Transfer in" when 162904 then "Restart" else "" end), "" )) as patient_type,
                max(if(o.concept_id = 164930, o.value_coded, null )) as population_type,
                max(if(o.concept_id = 160581, o.value_coded, null )) as kp_type,
                max(if(o.concept_id = 160540, (case o.value_coded when 159938 then "HBTC" when 160539 then "VCT Site" when 159937 then "MCH" when 160536 then "IPD-Adult" when 160541 then "TB Clinic" when 160542 then "OPD" when 162050 then "CCC" when 160551 then "Self Test" when 5622 then "Other" else "" end), "" )) as transfer_in_entry_point,
                max(if(o.concept_id = 162724, o.value_text, null )) as referred_from,
                max(if(o.concept_id = 161550, o.value_text, null )) as transit_from,
                max(if(o.concept_id = 160534, o.value_datetime, null )) as transfer_in_date,
                max(if(o.concept_id = 160535, o.value_text, null )) as transfer_from,
                max(if(o.concept_id = 160555, o.value_datetime, null )) as initial_enrolment_date,
                max(if(o.concept_id = 159599, o.value_datetime, null )) as date_started_prep_trf_facility,
                max(if(o.concept_id = 160533, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as previously_on_prep,
                max(if(o.concept_id = 1088, (case o.value_coded when 104567 then "TDF/FTC" when 84795 then "TDF" when 161364 then "TDF/3TC" else "" end), "" )) as regimen,
                max(if(o.concept_id = 162881, o.value_datetime, null )) as prep_last_date,
                max(if(o.concept_id = 5629, o.value_coded, null )) as in_school,
                max(if(o.concept_id = 160638, o.value_text, null )) as buddy_name,
                max(if(o.concept_id = 165038, o.value_text, null )) as buddy_alias,
                max(if(o.concept_id = 160640,(case o.value_coded when 973 then "Grandparent" when 972 then "Sibling" when 160639 then "Guardian" when 1527 then "Parent" when 5617 then "Spouse" when 163565 then "Partner" when 5622 then "Other" else "" end), "" )) as buddy_relationship,
                max(if(o.concept_id = 160642, o.value_text, null )) as buddy_phone,
                max(if(o.concept_id = 160641, o.value_text, null )) as buddy_alt_phone,
                e.voided as voided

      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("d5ca78be-654e-4d23-836e-a934739be555")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (164932,160540,162724,161550,160534,160535,160555,159599,160533,1088162881,5629,160638,165038,160640,160642,160641,164930,160581) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      patient_type=VALUES(patient_type),
      population_type=VALUES(population_type),
      kp_type=VALUES(kp_type),
      transfer_in_entry_point=VALUES(transfer_in_entry_point),
      referred_from=VALUES(referred_from),
      transit_from=VALUES(transit_from),
      transfer_in_date=VALUES(transfer_in_date),
      transfer_from=VALUES(transfer_from),
      initial_enrolment_date=VALUES(initial_enrolment_date),
      date_started_prep_trf_facility=VALUES(date_started_prep_trf_facility),
      previously_on_prep=VALUES(previously_on_prep),
      regimen=VALUES(regimen),
      prep_last_date=VALUES(prep_last_date),
      in_school=VALUES(in_school),
      buddy_name=VALUES(buddy_name),
      buddy_alias=VALUES(buddy_alias),
      buddy_relationship=VALUES(buddy_relationship),
      buddy_phone=VALUES(buddy_phone),
      buddy_alt_phone=VALUES(buddy_alt_phone),
      voided=VALUES(voided);

    END $$

-- ------------- populate etl_prep_followup-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_prep_followup $$
CREATE PROCEDURE sp_update_etl_prep_followup(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing PrEP follow-up", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_prep_followup(
        uuid,
        form,
        provider,
        patient_id,
        visit_id,
        visit_date,
        location_id,
        encounter_id,
        date_created,
        date_last_modified,
        sti_screened,
        genital_ulcer_disease,
        vaginal_discharge,
        cervical_discharge,
        pid,
        urethral_discharge,
        anal_discharge,
        other_sti_symptoms,
        sti_treated,
        vmmc_screened,
        vmmc_status,
        vmmc_referred,
        lmp,
        menopausal_status,
        pregnant,
        edd,
        planned_pregnancy,
        wanted_pregnancy,
        breastfeeding,
        fp_status,
        fp_method,
        ended_pregnancy,
        pregnancy_outcome,
        outcome_date,
        defects,
        has_chronic_illness,
        adverse_reactions,
        known_allergies,
        hepatitisB_vaccinated,
        hepatitisB_treated,
        hepatitisC_vaccinated,
        hepatitisC_treated,
        hiv_signs,
        adherence_counselled,
        adherence_outcome,
        poor_adherence_reasons,
        other_poor_adherence_reasons,
        prep_contraindications,
        treatment_plan,
        prescribed_PrEP,
        regimen_prescribed,
        months_prescribed_regimen,
        condoms_issued,
        number_of_condoms,
        appointment_given,
        appointment_date,
        reason_no_appointment,
        clinical_notes,
        voided
    )
    select
        e.uuid,
        (case f.uuid
              when '1bfb09fc-56d7-4108-bd59-b2765fd312b8' then 'prep-initial'
              when 'ee3e2017-52c0-4a54-99ab-ebb542fb8984' then 'prep-consultation'
         end) as form,
        e.creator as provider,e.patient_id, e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id = 161558,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as sti_screened,
        max(if(o.concept_id = 165098 and o.value_coded = 145762,"GUD",null)) as genital_ulcer_disease,
        max(if(o.concept_id = 165098 and o.value_coded = 121809,"VG",null)) as vaginal_discharge,
        max(if(o.concept_id = 165098 and o.value_coded = 116995,"CD",null)) as cervical_discharge,
        max(if(o.concept_id = 165098 and o.value_coded = 130644,"PID",null)) as pid,
        max(if(o.concept_id = 165098 and o.value_coded = 123529,"UD",null)) as urethral_discharge,
        max(if(o.concept_id = 165098 and o.value_coded = 148895,"AD",null)) as anal_discharge,
        max(if(o.concept_id = 165098 and o.value_coded = 5622,"Other",null)) as other_sti_symptoms,
        max(if(o.concept_id = 165200,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as sti_treated,
        max(if(o.concept_id = 165308,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as vmmc_screened,
        max(if(o.concept_id = 165099,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end), "" )) as vmmc_status,
        max(if(o.concept_id = 1272,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as vmmc_referred,
        max(if(o.concept_id = 1472, o.value_datetime, null )) as lmp,
        max(if(o.concept_id = 134346, o.value_coded, null )) as menopausal_status,
        max(if(o.concept_id = 5272,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as pregnant,
        max(if(o.concept_id = 5596, o.value_datetime, null )) as edd,
        max(if(o.concept_id = 1426, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as planned_pregnancy,
        max(if(o.concept_id = 164933, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as wanted_pregnancy,
        max(if(o.concept_id = 5632, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as breastfeeding,
        max(if(o.concept_id = 160653, (case o.value_coded when 965 then "On Family Planning" when 160652 then "Not using Family Planning" when 1360 then "Wants Family Planning" else "" end), "" )) as fp_status,
        CONCAT_WS(',',max(if(o.concept_id = 374 and o.value_coded = 160570, "Emergency contraceptive pills",NULL)),max(if(o.concept_id = 374 and o.value_coded = 780, "Oral Contraceptives Pills",NULL)),
        max(if(o.concept_id = 374 and o.value_coded = 5279, "Injectable",NULL)),max(if(o.concept_id = 374 and o.value_coded = 1359, "Implant",NULL)),max(if(o.concept_id = 374 and o.value_coded = 136163, "Lactational Amenorhea Method",NULL))
            ,max(if(o.concept_id = 374 and o.value_coded = 5275, "Intrauterine Device",NULL)),max(if(o.concept_id = 374 and o.value_coded = 5278, "Diaphram/Cervical Cap",NULL))
            ,max(if(o.concept_id = 374 and o.value_coded = 5277, "Fertility Awareness",NULL)),max(if(o.concept_id = 374 and o.value_coded = 1472, "Tubal Ligation/Female sterilization",NULL)),
        max(if(o.concept_id = 374 and o.value_coded = 190, "Condoms",NULL)),max(if(o.concept_id = 374 and o.value_coded = 1489, "Vasectomy(Partner)",NULL)),max(if(o.concept_id = 374 and o.value_coded = 162332, "Undecided",NULL))) as fp_method,
        max(if(o.concept_id = 165103, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as ended_pregnancy,
        max(if(o.concept_id = 161033, (case o.value_coded when 1395 then "Term live" when 129218 then "Preterm Delivery" when 125872 then "Still birth" when 159896 then "Induced abortion" else "" end), "" )) as pregnancy_outcome,
        max(if(o.concept_id = 1596, o.value_datetime, null )) as outcome_date,
        max(if(o.concept_id = 164122, (case o.value_coded when 155871 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end), "" )) as defects,
        max(if(o.concept_id = 162747, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as has_chronic_illness,
        max(if(o.concept_id = 121764, o.value_coded, null )) as adverse_reactions,
        max(if(o.concept_id = 160557, o.value_coded, null )) as known_allergies,
        max(if(o.concept_id = 1272, o.value_coded, null )) as hepatitisB_vaccinated,
        max(if(o.concept_id = 1272, o.value_coded, null )) as hepatitisB_treated,
        max(if(o.concept_id = 1272, o.value_coded, null )) as hepatitisC_vaccinated,
        max(if(o.concept_id = 1272, o.value_coded, null )) as hepatitisC_treated,
        max(if(o.concept_id = 165101, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as hiv_signs,
        max(if(o.concept_id = 165104, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as adherence_counselled,
        max(if(o.concept_id = 164075, (case o.value_coded when 159405 then "Good" when 159406 then "Fair" when 159407 then 'Poor' else "" end), "" )) as adherence_outcome,
        max(if(o.concept_id = 160582, (case o.value_coded when 163293 then "Sick" when 1107 then "None"
                                     when 164997 then "Stigma" when 160583 then "Shared with others" when 1064 then "No perceived risk"
                                     when 160588 then "Pill burden" when 160584 then "Lost/out of pills" when 1056 then "Separated from HIV+"
                                     when 159935 then "Side effects" when 160587 then "Forgot" when 5622 then "Other-specify" else "" end), "" )) as poor_adherence_reasons,
        max(if(o.concept_id = 160632, o.value_text, null )) as other_poor_adherence_reasons,
        CONCAT_WS(',',max(if(o.concept_id = 165106 and o.value_coded = 1107, "None",NULL)),
        max(if(o.concept_id = 165106 and o.value_coded = 138571, "Confirmed HIV+",NULL)),
        max(if(o.concept_id = 165106 and o.value_coded = 155589, "Renal impairment",NULL)),
        max(if(o.concept_id = 165106 and o.value_coded = 127750, "Not willing",NULL)),
        max(if(o.concept_id = 165106 and o.value_coded = 165105, "Less than 35ks and under 15 yrs",NULL))) as prep_contraindications,
        max(if(o.concept_id = 165109, (case o.value_coded when 1257 then "Continue" when 162904 then "Restart" when 1260 then "Discontinue" else "" end), "" )) as treatment_plan,
        max(if(o.concept_id = 1417, (case o.value_coded when 1065 then "Yes" when 1066 then "No" end), "" )) as prescribed_PrEP,
        max(if(o.concept_id = 164515, (case o.value_coded when 161364 then "TDF/3TC" when 84795 then "TDF" when 104567 then "TDF/FTC(Preferred)" end), "" )) as regimen_prescribed,
        max(if(o.concept_id = 164433, o.value_text, null)) as months_prescribed_regimen,
        max(if(o.concept_id = 159777, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as condoms_issued,
        max(if(o.concept_id = 165055, o.value_numeric, null )) as number_of_condoms,
        max(if(o.concept_id = 165353, (case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as appointment_given,
        max(if(o.concept_id = 5096, o.value_datetime, null )) as appointment_date,
        max(if(o.concept_id = 165354, (case o.value_coded when 165053 then "Risk will no longer exist" when 159492 then "Intention to transfer out" else "" end), "" )) as reason_no_appointment,
        max(if(o.concept_id = 163042, o.value_text, null )) as clinical_notes,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("ee3e2017-52c0-4a54-99ab-ebb542fb8984","1bfb09fc-56d7-4108-bd59-b2765fd312b8")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (161558,165098,165200,165308,165099,1272,1472,5272,5596,1426,164933,5632,160653,374,
                                                                                                                                                    165103,161033,1596,164122,162747,1284,159948,1282,1443,1444,160855,159368,1732,121764,1193,159935,162760,1255,160557,160643,159935,162760,160753,165101,165104,165106,
                                                                                                                                                                                                                                                             165109,159777,165055,165309,5096,165310,163042,134346,164075,160582,160632,1417,164515,164433,165354,165310) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id,visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      sti_screened=VALUES(sti_screened),
      genital_ulcer_disease = VALUES(genital_ulcer_disease),
      vaginal_discharge = VALUES(vaginal_discharge),
      cervical_discharge = VALUES(cervical_discharge),
      pid = VALUES(pid),
      urethral_discharge = VALUES(urethral_discharge),
      anal_discharge = VALUES(anal_discharge),
      other_sti_symptoms = VALUES(other_sti_symptoms),
      sti_treated=VALUES(sti_treated),
      vmmc_screened=VALUES(vmmc_screened),
      vmmc_status=VALUES(vmmc_status),
      vmmc_referred=VALUES(vmmc_referred),
      lmp=VALUES(lmp),
      menopausal_status=VALUES(menopausal_status),
      pregnant=VALUES(pregnant),
      edd=VALUES(edd),
      planned_pregnancy=VALUES(planned_pregnancy),
      wanted_pregnancy=VALUES(wanted_pregnancy),
      breastfeeding=VALUES(breastfeeding),
      fp_status=VALUES(fp_status),
      fp_method=VALUES(fp_method),
      ended_pregnancy=VALUES(ended_pregnancy),
      pregnancy_outcome=VALUES(pregnancy_outcome),
      outcome_date=VALUES(outcome_date),
      defects=VALUES(defects),
      has_chronic_illness=VALUES(has_chronic_illness),
      adverse_reactions=VALUES(adverse_reactions),
      known_allergies=VALUES(known_allergies),
      hepatitisB_vaccinated=VALUES(hepatitisB_vaccinated),
      hepatitisB_treated=VALUES(hepatitisB_treated),
      hepatitisC_vaccinated=VALUES(hepatitisC_vaccinated),
      hepatitisC_treated=VALUES(hepatitisC_treated),
      hiv_signs=VALUES(hiv_signs),
      adherence_counselled=VALUES(adherence_counselled),
      adherence_outcome=VALUES(adherence_outcome),
      poor_adherence_reasons=VALUES(poor_adherence_reasons),
      other_poor_adherence_reasons=VALUES(other_poor_adherence_reasons),
      prep_contraindications=VALUES(prep_contraindications),
      treatment_plan=VALUES(treatment_plan),
      prescribed_PrEP=VALUES(prescribed_PrEP),
      regimen_prescribed=VALUES(regimen_prescribed),
      months_prescribed_regimen=VALUES(months_prescribed_regimen),
      condoms_issued=VALUES(condoms_issued),
      number_of_condoms=VALUES(number_of_condoms),
      appointment_given=VALUES(appointment_given),
      appointment_date=VALUES(appointment_date),
      reason_no_appointment=VALUES(reason_no_appointment),
      clinical_notes=VALUES(clinical_notes),
      voided=VALUES(voided);

    END $$

-- ------------- populate etl_progress_note-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_progress_note $$
CREATE PROCEDURE sp_update_etl_progress_note(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing progress", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_progress_note(
      uuid,
      provider ,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      notes,
      voided
    )
      select
        e.uuid, e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,e.date_created,
                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                max(if(o.concept_id = 159395, o.value_text, null )) as notes,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("c48ed2a2-0a0f-4f4e-9fed-a79ca3e1a9b9")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (159395) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=values(visit_date),
      provider=values(provider),
      notes=values(notes),
      voided=values(voided);
    END $$

/*SET sql_mode=@OLD_SQL_MODE$$*/
-- ----------------------------  scheduled updates ---------------------
-- ------------------------------------- populate tpt initiation -----------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_ipt_initiation $$
CREATE PROCEDURE sp_update_etl_ipt_initiation(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating TPT initiations ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_ipt_initiation(
      patient_id,
      uuid,
      encounter_provider,
      visit_date ,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      ipt_indication,
      voided
    )
      select
        e.patient_id,
        e.uuid,
        e.creator,
        e.encounter_datetime,
        e.location_id,
        e.encounter_id,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=162276,o.value_coded,null)) as ipt_indication,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0 and o.concept_id=162276
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('de5cacd4-7d15-4ad0-a1be-d81c77b6c37d')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),ipt_indication=VALUES(ipt_indication), voided=VALUES(voided)
    ;
    SELECT "Completed Updating TPT Initiation ", CONCAT("Time: ", NOW());
    END $$

-- ------------------------------------- process tpt followup -------------------------
/*DROP PROCEDURE IF EXISTS sp_update_etl_ipt_followup $$
CREATE PROCEDURE sp_update_etl_ipt_followup(IN last_update_time DATETIME)
	BEGIN
		SELECT "Updating TPT followup ", CONCAT("Time: ", NOW());
		INSERT INTO kenyaemr_etl.etl_ipt_followup(
			uuid,
			patient_id,
			visit_id,
			visit_date,
			location_id,
			encounter_id,
			encounter_provider,
			date_created,
			ipt_due_date,
			date_collected_ipt,
			has_hepatoxicity,
			has_peripheral_neuropathy,
			has_rash,
			adherence,
			action_taken,
			voided
		)
			select
				e.uuid,
				e.patient_id,
				e.visit_id,
				date(e.encounter_datetime) as visit_date,
				e.location_id,
				e.encounter_id as encounter_id,
				e.creator,
				e.date_created as date_created,
				max(if(o.concept_id=164073,date(o.value_datetime),null)) as ipt_due_date,
				max(if(o.concept_id=164074,date(o.value_datetime),null)) as date_collected_ipt,
				max(if(o.concept_id=159098,o.value_coded,null)) as has_hepatoxicity,
				max(if(o.concept_id=118983,o.value_coded,null)) as has_peripheral_neuropathy,
				max(if(o.concept_id=512,o.value_coded,null)) as has_rash,
				max(if(o.concept_id=164075,o.value_coded,null)) as adherence,
				max(if(o.concept_id=160632,o.value_text,null)) as action_taken,
				e.voided as voided
			from encounter e
				inner join
				(
					select encounter_type_id, uuid, name from encounter_type where uuid in('aadeafbe-a3b1-4c57-bc76-8461b778ebd6')
				) et on et.encounter_type_id=e.encounter_type
				left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
																 and o.concept_id in (164073,164074,159098,118983,512,164075,160632)
			where e.date_created >= last_update_time
						or e.date_changed >= last_update_time
						or e.date_voided >= last_update_time
						or o.date_created >= last_update_time
						or o.date_voided >= last_update_time
			group by e.patient_id, e.encounter_id, visit_date
		ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),
			ipt_due_date=VALUES(ipt_due_date),date_collected_ipt=VALUES(date_collected_ipt),has_hepatoxicity=VALUES(has_hepatoxicity),
			has_peripheral_neuropathy=VALUES(has_peripheral_neuropathy),has_rash=VALUES(has_rash),
			adherence=VALUES(adherence),action_taken=VALUES(action_taken),voided=VALUES(voided)
		;
		SELECT "Completed Updating TPT followup data ", CONCAT("Time: ", NOW());
		END $$*/
-- ----------------------------------- process tpt outcome ---------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_ipt_outcome $$
CREATE PROCEDURE sp_update_etl_ipt_outcome(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating TPT outcome ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_ipt_outcome(
      patient_id,
      uuid,
      encounter_provider,
      visit_date ,
      location_id,
      encounter_id,
      date_created,
      date_last_modified,
      outcome,
      voided
    )
      select
        e.patient_id,
        e.uuid,
        e.creator encounter_provider,
        date(e.encounter_datetime) visit_date,
        e.location_id,
        e.encounter_id,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=161555,o.value_coded,null)) as outcome,
        e.voided voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join obs o on e.encounter_id = o.encounter_id and o.voided =0 and o.concept_id=161555
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where
            uuid in('bb77c683-2144-48a5-a011-66d904d776c9')
        ) et on et.encounter_type_id=e.encounter_type
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.encounter_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),
      outcome=VALUES(outcome), voided=VALUES(voided)
    ;
    SELECT "Completed Updating TPT outcome ", CONCAT("Time: ", NOW());
    END $$

-- --------------------------------------- process HTS linkage tracing ------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_hts_linkage_tracing $$
CREATE PROCEDURE sp_update_etl_hts_linkage_tracing(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating HTS Linkage tracing ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_hts_linkage_tracing(
      uuid,
      patient_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      tracing_type,
      tracing_outcome,
      reason_not_contacted,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=164966,o.value_coded,null)) as tracing_type,
        max(if(o.concept_id=159811,o.value_coded,null)) as tracing_outcome,
        max(if(o.concept_id=1779,o.value_coded,null)) as reason_not_contacted,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('15ed03d2-c972-11e9-a32f-2a2ae2dbcce4')
        ) f on f.form_id=e.form_id
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (164966,159811,1779)
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),
      tracing_type=VALUES(tracing_type),tracing_outcome=VALUES(tracing_outcome),reason_not_contacted=VALUES(reason_not_contacted),
      voided=VALUES(voided)
    ;
    SELECT "Completed updating HTS linkage tracing data ", CONCAT("Time: ", NOW());
    END $$


-- --------------------------------------- process OTZ Enrollment ------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_otz_enrollment $$
CREATE PROCEDURE sp_update_etl_otz_enrollment(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating OTZ Enrollment ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_otz_enrollment(
      uuid,
      patient_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      orientation,
      leadership,
      participation,
      treatment_literacy,
      transition_to_adult_care,
      making_decision_future,
      srh,
      beyond_third_ninety,
      transfer_in,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=165359,(case o.value_coded when 1065 then "Yes" else "" end),null)) as orientation,
        max(if(o.concept_id=165361,(case o.value_coded when 1065 then "Yes" else "" end),null)) as leadership,
        max(if(o.concept_id=165360,(case o.value_coded when 1065 then "Yes" else "" end),null)) as participation,
        max(if(o.concept_id=165364,(case o.value_coded when 1065 then "Yes" else "" end),null)) as treatment_literacy,
        max(if(o.concept_id=165363,(case o.value_coded when 1065 then "Yes" else "" end),null)) as transition_to_adult_care,
        max(if(o.concept_id=165362,(case o.value_coded when 1065 then "Yes" else "" end),null)) as making_decision_future,
        max(if(o.concept_id=165365,(case o.value_coded when 1065 then "Yes" else "" end),null)) as srh,
        max(if(o.concept_id=165366,(case o.value_coded when 1065 then "Yes" else "" end),null)) as beyond_third_ninety,
        max(if(o.concept_id=160563,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as transfer_in,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('3ae95898-0464-11ea-8d71-362b9e155667')
        ) f on f.form_id=e.form_id
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (165359,165361,165360,165364,165363,165362,165365,165366,160563)
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),
      orientation=VALUES(orientation),leadership=VALUES(leadership),participation=VALUES(participation),
      treatment_literacy=VALUES(treatment_literacy),transition_to_adult_care=VALUES(transition_to_adult_care),making_decision_future=VALUES(making_decision_future),
      srh=VALUES(srh),beyond_third_ninety=VALUES(beyond_third_ninety),transfer_in=VALUES(transfer_in),
      voided=VALUES(voided);
    SELECT "Completed updating OTZ enrollment data ", CONCAT("Time: ", NOW());
    END $$


-- --------------------------------------- process OTZ Activity ------------------------
DROP PROCEDURE IF EXISTS sp_update_etl_otz_activity $$
CREATE PROCEDURE sp_update_etl_otz_activity(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating OTZ Activity ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_otz_activity(
      uuid,
      patient_id,
      visit_date,
      visit_id,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      orientation,
      leadership,
      participation,
      treatment_literacy,
      transition_to_adult_care,
      making_decision_future,
      srh,
      beyond_third_ninety,
      attended_support_group,
      remarks,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        date(e.encounter_datetime) as visit_date,
        e.visit_id,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=165359,(case o.value_coded when 1065 then "Yes" else "" end),null)) as orientation,
        max(if(o.concept_id=165361,(case o.value_coded when 1065 then "Yes" else "" end),null)) as leadership,
        max(if(o.concept_id=165360,(case o.value_coded when 1065 then "Yes" else "" end),null)) as participation,
        max(if(o.concept_id=165364,(case o.value_coded when 1065 then "Yes" else "" end),null)) as treatment_literacy,
        max(if(o.concept_id=165363,(case o.value_coded when 1065 then "Yes" else "" end),null)) as transition_to_adult_care,
        max(if(o.concept_id=165362,(case o.value_coded when 1065 then "Yes" else "" end),null)) as making_decision_future,
        max(if(o.concept_id=165365,(case o.value_coded when 1065 then "Yes" else "" end),null)) as srh,
        max(if(o.concept_id=165366,(case o.value_coded when 1065 then "Yes" else "" end),null)) as beyond_third_ninety,
        max(if(o.concept_id=165302,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end), "" )) as attended_support_group,
        max(if(o.concept_id=161011,trim(o.value_text),null)) as remarks,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('3ae95d48-0464-11ea-8d71-362b9e155667')
        ) f on f.form_id=e.form_id
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (165359,165361,165360,165364,165363,165362,165365,165366,165302,161011)
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),visit_id=VALUES(visit_id),encounter_provider=VALUES(encounter_provider),
      orientation=VALUES(orientation),leadership=VALUES(leadership),participation=VALUES(participation),
      treatment_literacy=VALUES(treatment_literacy),transition_to_adult_care=VALUES(transition_to_adult_care),making_decision_future=VALUES(making_decision_future),
      srh=VALUES(srh),beyond_third_ninety=VALUES(beyond_third_ninety),attended_support_group=VALUES(attended_support_group),
      voided=VALUES(voided);
    SELECT "Completed updating OTZ activity data ", CONCAT("Time: ", NOW());
    END $$

-- --------------------------------------- process OTZ Enrollment ------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_ovc_enrolment $$
CREATE PROCEDURE sp_update_etl_ovc_enrolment(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating OVC Enrolment ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_ovc_enrolment(
      uuid,
      patient_id,
      visit_date,
      location_id,
      visit_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      caregiver_enrolled_here,
      caregiver_name,
      caregiver_gender,
      relationship_to_client,
      caregiver_phone_number,
      client_enrolled_cpims,
      partner_offering_ovc,
      ovc_comprehensive_program,
      dreams_program,
      ovc_preventive_program,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        date(e.encounter_datetime) as visit_date,
        e.location_id,
        e.visit_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=163777,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as caregiver_enrolled_here,
        max(if(o.concept_id=163258,o.value_text,null)) as caregiver_name,
        max(if(o.concept_id=1533,(case o.value_coded when 1534 then "Male" when 1535 then "Female" else "" end),null)) as caregiver_gender,
        max(if(o.concept_id=164352,(case o.value_coded when 1527 then "Parent" when 974 then "Uncle" when 972 then "Sibling" when 162722 then "Childrens home" when 975 then "Aunt"  else "" end),null)) as relationship_to_client,
        max(if(o.concept_id=160642,o.value_text,null)) as caregiver_phone_number,
        max(if(o.concept_id=163766,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as client_enrolled_cpims,
        max(if(o.concept_id=165347,o.value_text,null)) as partner_offering_ovc,
        max(if(o.concept_id=163775 and o.value_coded=1141, "Yes",null)) as ovc_comprehensive_program,
        max(if(o.concept_id=163775 and o.value_coded=160549,"Yes",null)) as dreams_program,
        max(if(o.concept_id=163775 and o.value_coded=164128,"Yes",null)) as ovc_preventive_program,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select form_id, uuid,name from form where
            uuid in('5cf01528-09da-11ea-8d71-362b9e155667')
        ) f on f.form_id=e.form_id
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (163777,163258,1533,164352,160642,163766,165347,163775)
      where e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id, visit_date
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),visit_id=VALUES(visit_id),
      caregiver_enrolled_here=VALUES(caregiver_enrolled_here),caregiver_name=VALUES(caregiver_name),caregiver_gender=VALUES(caregiver_gender),
      relationship_to_client=VALUES(relationship_to_client),caregiver_phone_number=VALUES(caregiver_phone_number),client_enrolled_cpims=VALUES(client_enrolled_cpims),
      partner_offering_ovc=VALUES(partner_offering_ovc),ovc_comprehensive_program=VALUES(ovc_comprehensive_program),
      dreams_program=VALUES(dreams_program),ovc_preventive_program=VALUES(ovc_preventive_program),
      voided=VALUES(voided);
    SELECT "Completed updating OVC enrolment data ", CONCAT("Time: ", NOW());
    END $$

-- ------------------------- process patient program ------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_patient_program $$
CREATE PROCEDURE sp_update_etl_patient_program(IN last_update_time DATETIME)
  BEGIN
    SELECT "Updating patient program ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_patient_program(
      uuid,
      patient_id,
      location_id,
      program,
      date_enrolled,
      date_completed,
      outcome,
      date_created,
      date_last_modified,
      voided
    )
      select
        pp.uuid uuid,
        pp.patient_id patient_id,
        pp.location_id location_id,
        (case p.uuid
         when "9f144a34-3a4a-44a9-8486-6b7af6cc64f6" then "TB"
         when "dfdc6d40-2f2f-463d-ba90-cc97350441a8" then "HIV"
         when "c2ecdf11-97cd-432a-a971-cfd9bd296b83" then "MCH-Child Services"
         when "b5d9e05f-f5ab-4612-98dd-adb75438ed34" then "MCH-Mother Services"
         when "335517a1-04bc-438b-9843-1ba49fb7fcd9" then "TPT"
         when "24d05d30-0488-11ea-8d71-362b9e155667" then "OTZ"
         when "6eda83f0-09d9-11ea-8d71-362b9e155667" then "OVC"
         when "7447305a-18a7-11e9-ab14-d663bd873d93" then "KP"
         end) as program,
        pp.date_enrolled date_enrolled,
        pp.date_completed date_completed,
        pp.outcome_concept_id outcome,
        pp.date_created,
        pp.date_changed as date_last_modified,
        pp.voided voided
      from patient_program pp
        inner join program p on p.program_id=pp.program_id and p.retired=0
        inner join person pt on pt.person_id=pp.patient_id and pt.voided=0
      where pp.date_created >= last_update_time
            or pp.date_changed >= last_update_time
            or pp.date_voided >= last_update_time
      GROUP BY pp.uuid
    ON DUPLICATE KEY UPDATE date_enrolled=VALUES(date_enrolled),date_completed=VALUES(date_completed),
      program=VALUES(program),outcome=VALUES(outcome),voided=VALUES(outcome),voided=VALUES(voided)
    ;
    SELECT "Completed updating patient program data ", CONCAT("Time: ", NOW());
    END $$

-- ------------------- update person address table -------------

DROP PROCEDURE IF EXISTS sp_update_etl_person_address $$
CREATE PROCEDURE sp_update_etl_person_address(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing person addresses ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_person_address(
      uuid,
      patient_id,
      county,
      sub_county,
      location,
      ward,
      sub_location,
      village,
      postal_address,
      land_mark,
      voided
    )
      select
        pa.uuid,
        pa.person_id,
        coalesce(pa.country,pa.county_district) county,
        pa.state_province sub_county,
        pa.address6 location,
        pa.address4 ward,
        pa.address5 sub_location,
        pa.city_village village,
        pa.address1 postal_address,
        pa.address2 land_mark,
        pa.voided voided
      from person_address pa
        inner join person pt on pt.person_id=pa.person_id and pt.voided=0
      where pa.date_created >= last_update_time
            or pa.date_changed >= last_update_time
            or pa.date_voided >= last_update_time
    ON DUPLICATE KEY UPDATE county=VALUES(county),sub_county=values(sub_county),location=values(location),
      ward=values(ward),sub_location=values(sub_location),village=VALUES(village),postal_address=values(postal_address),
      land_mark=values(land_mark),voided=values(voided)
    ;
    SELECT "Completed processing person_address data ", CONCAT("Time: ", NOW());
    END $$

-- -------------Update etl_cervical_cancer_screening-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_cervical_cancer_screening $$
CREATE PROCEDURE sp_update_etl_cervical_cancer_screening(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing CAXC screening", CONCAT("Time: ", NOW());

    insert into kenyaemr_etl.etl_cervical_cancer_screening(
      uuid,
      encounter_id,
      encounter_provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      date_created,
      date_last_modified,
      visit_type,
      screening_type,
      post_treatment_complication_cause,
      post_treatment_complication_other,
      screening_method,
      screening_result,
      treatment_method,
      treatment_method_other,
      referred_out,
      referral_facility,
      referral_reason,
      next_appointment_date,
      voided
    )
      select
        e.uuid,  e.encounter_id,e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id,e.date_created,
                                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                                max(if(o.concept_id = 160288, (case o.value_coded when 162080 then 'Initial visit'
                                                               when 161236 then 'Routine visit'
                                                               when 165381 then 'Post treatment visit'
                                                               when 1185 then 'Treatment visit'
                                                               when 165382 then 'Post treatment complication' else "" end), "" )) as visit_type,
                                max(if(o.concept_id = 164181, (case o.value_coded when 164180 then 'First time screening'
                                                               when 160530 then 'Rescreening'
                                                               when 165389 then 'Post treatment followup' else "" end), "" )) as screening_type,
                                max(if(o.concept_id = 165383, (case o.value_coded when 162816 then 'Cryotherapy'
                                                               when 162810 then 'LEEP'
                                                               when 5622 then 'Others' else "" end), "" )) as post_treatment_complication_cause,
                                max(if(o.concept_id=163042,o.value_text,null)) as post_treatment_complication_other,
                                max(if(o.concept_id = 163589, (case o.value_coded when 885 then 'Pap Smear'
                                                               when 162816 then 'VIA'
                                                               when 164805 then 'VIA'
                                                               when 164977 then 'VILI'
                                                               when 160705 then 'Colposcopy'
                                                               when 159859 then 'HPV Test'
                                                               when 5622 then 'Other' else "" end), "" )) as screening_method,
                                max(if(o.concept_id = 164934, (case o.value_coded when 703 then 'Positive'
                                                               when 1116 then 'Positive'
                                                               when 145805 then 'Positive'
                                                               when 155424 then 'Positive'
                                                               when 145808  then 'Presumed'
                                                               when 159393 then 'Presumed'
                                                               when 159008 then 'Presumed'
                                                               when 5622 then 'Other'
                                                               when 1115  then 'Negative'
                                                               when 664  then 'Negative' else NULL end), '' )) as screening_result,
                                max(if(o.concept_id = 165266, (case o.value_coded when 165381 then 'Cryotherapy postponed'
                                                               when 165386 then 'Cryotherapy performed'
                                                               when 162810 then 'LEEP'
                                                               when 165396 then 'Cold knife cone'
                                                               when 165395 then 'Thermocoagulation'
                                                               when 165385 then 'Cryotherapy performed (single Visit)'
                                                               when 159837 then 'Hysterectomy'
                                                               when 165391 then 'Referred for cancer treatment'
                                                               when 5622 then 'Other' else "" end), "" )) as treatment_method,
                                max(if(o.concept_id=160632,o.value_text,null)) as treatment_method_other,
                                max(if(o.concept_id=165267,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as referred_out,
                                max(if(o.concept_id=165268,o.value_text,null)) as referral_facility,
                                max(if(o.concept_id = 1887, (case o.value_coded when 165388 then 'Site does not have cryotherapy machine'
                                                             when 159008 then 'Large lesion, Suspect cancer'
                                                             when 5622 then 'Other' else "" end), "" )) as referral_reason,
                                max(if(o.concept_id=5096,o.value_datetime,null)) as next_appointment_date,
                                e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid ='0c93b93c-bfef-4d2a-9fbe-16b59ee366e7'
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (164934,163589,160288,164181,165383,163042,165266,160632,165267,165268,1887,5096) and o.voided=0
      where
        e.date_created >= last_update_time
        or e.date_changed >= last_update_time
        or e.date_voided >= last_update_time
        or o.date_created >= last_update_time
        or o.date_voided >= last_update_time
      group by e.encounter_id
      having screening_result is not null
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date), encounter_provider=VALUES(encounter_provider),screening_method = VALUES(screening_method), screening_result = VALUES(screening_result);
    SELECT "Completed processing Cervical Cancer Screening", CONCAT("Time: ", NOW());

    SELECT "Completed processing CAXC screening", CONCAT("Time: ", NOW());
    END $$

DROP PROCEDURE IF EXISTS sp_update_etl_kp_contact $$
CREATE PROCEDURE sp_update_etl_kp_contact(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing client contact data ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_contact (
      uuid,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      patient_type,
      transfer_in_date,
      date_first_enrolled_in_kp,
      facility_transferred_from,
      key_population_type,
      priority_population_type,
      implementation_county,
      implementation_subcounty,
      implementation_ward,
      contacted_by_peducator,
      program_name,
      frequent_hotspot_name,
      frequent_hotspot_type,
      year_started_sex_work,
      year_started_sex_with_men,
      year_started_drugs,
      avg_weekly_sex_acts,
      avg_weekly_anal_sex_acts,
      avg_daily_drug_injections,
      contact_person_name,
      contact_person_alias,
      contact_person_phone,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        e.encounter_datetime as visit_date,
        e.location_id,
        e.encounter_id,
        e.creator,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=164932,(case o.value_coded when 164144 then "New Patient" when 160563 then "Transfer in" else "" end),null)) as patient_type,
        max(if(o.concept_id=160534,o.value_datetime,null)) as transfer_in_date,
        max(if(o.concept_id=160555,o.value_datetime,null)) as date_first_enrolled_in_kp,
        max(if(o.concept_id=160535,left(trim(o.value_text),100),null)) as facility_transferred_from,
        max(if(o.concept_id=164929,(case o.value_coded when 165083 then "FSW" when 160578 then "MSM" when 165084 then "MSW" when 165085
          then  "PWUD" when 105 then "PWID"  when 165100 then "Transgender" when 162277 then "People in prison and other closed settings" when 1175 then "Not applicable" else "" end),null)) as key_population_type,
        max(if(o.concept_id=138643,(case o.value_coded when 159674 then "Fisher Folk" when 162198 then "Truck Driver" when 160549 then "Adolescent and Young Girls" when 162277
          then  "Prisoner" else "" end),null)) as priority_population_type,
        max(if(o.concept_id=167131,o.value_text,null)) as implementation_county,
        max(if(o.concept_id=161551,o.value_text,null)) as implementation_subcounty,
        max(if(o.concept_id=161550,o.value_text,null)) as implementation_ward,
        max(if(o.concept_id=165004,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as contacted_by_peducator,
        max(if(o.concept_id=165137,o.value_text,null)) as program_name,
        max(if(o.concept_id=165006,o.value_text,null)) as frequent_hotspot_name,
        max(if(o.concept_id=165005,( case o.value_coded
                                     when 165011 then "Street"
                                     when 165012 then "Injecting den"
                                     when 165013 then "Uninhabitable building"
                                     when 165014 then "Public Park"
                                     when 1536 then "Homes"
                                     when 165015 then "Beach"
                                     when 165016 then "Casino"
                                     when 165017 then "Bar with lodging"
                                     when 165018 then "Bar without lodging"
                                     when 165019 then "Sex den"
                                     when 165020 then "Strip club"
                                     when 165021 then "Highway"
                                     when 165022 then "Brothel"
                                     when 165023 then "Guest house/hotel"
                                     when 165024 then "Massage parlor"
                                     when 165025 then "illicit brew den"
                                     when 165026 then "Barber shop/salon"
                                     when 165297 then "Virtual Space"
                                     when 5622 then "Other"
                                     else "" end),null)) as frequent_hotspot_type,
        max(if(o.concept_id=165030,o.value_numeric,null)) as year_started_sex_work,
        max(if(o.concept_id=165031,o.value_numeric,null)) as year_started_sex_with_men,
        max(if(o.concept_id=165032,o.value_numeric,null)) as year_started_drugs,
        max(if(o.concept_id=165007,o.value_numeric,null)) as avg_weekly_sex_acts,
        max(if(o.concept_id=165008,o.value_numeric,null)) as avg_weekly_anal_sex_acts,
        max(if(o.concept_id=165009,o.value_numeric,null)) as avg_daily_drug_injections,
        max(if(o.concept_id=160638,o.value_text,null)) as contact_person_name,
        max(if(o.concept_id=165038,o.value_text,null)) as contact_person_alias,
        max(if(o.concept_id=160642,o.value_text,null)) as contact_person_phone,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid='ea68aad6-4655-4dc5-80f2-780e33055a9e'
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                         and o.concept_id in (164932,160534,160555,160535,164929,138643,167131,161551,161550,165004,165137,165006,165005,165030,165031,165032,165007,165008,165009,160638,165038,160642)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),encounter_provider=VALUES(encounter_provider),patient_type=VALUES(patient_type),transfer_in_date=VALUES(transfer_in_date),date_first_enrolled_in_kp=VALUES(date_first_enrolled_in_kp),
      facility_transferred_from=VALUES(facility_transferred_from),key_population_type=VALUES(key_population_type),priority_population_type=VALUES(priority_population_type),implementation_county=VALUES(implementation_county),implementation_subcounty=VALUES(implementation_subcounty),
      implementation_ward=VALUES(implementation_ward),contacted_by_peducator=VALUES(contacted_by_peducator),
      program_name=VALUES(program_name),frequent_hotspot_name=VALUES(frequent_hotspot_name),frequent_hotspot_type=VALUES(frequent_hotspot_type),year_started_sex_work=VALUES(year_started_sex_work),
      year_started_sex_with_men=VALUES(year_started_sex_with_men),year_started_drugs=VALUES(year_started_drugs),avg_weekly_sex_acts=VALUES(avg_weekly_sex_acts),avg_weekly_anal_sex_acts=VALUES(avg_weekly_anal_sex_acts),
      avg_daily_drug_injections=VALUES(avg_daily_drug_injections),contact_person_name=VALUES(contact_person_name),contact_person_alias=VALUES(contact_person_alias),contact_person_phone=VALUES(contact_person_phone),voided=VALUES(voided);

    SELECT "Completed processing KP contact data", CONCAT("Time: ", NOW());

    update kenyaemr_etl.etl_contact c
      join (select pi.patient_id,
              max(if(pit.uuid='b7bfefd0-239b-11e9-ab14-d663bd873d93',pi.identifier,null)) unique_identifier
            from patient_identifier pi
              join patient_identifier_type pit on pi.identifier_type=pit.patient_identifier_type_id
            where voided=0
            group by pi.patient_id) pid on pid.patient_id=c.client_id
    set
      c.unique_identifier=pid.unique_identifier;

    END $$

DROP PROCEDURE IF EXISTS sp_update_etl_kp_client_enrollment $$
CREATE PROCEDURE sp_update_etl_kp_client_enrollment(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing client enrollment data ", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_client_enrollment (
      uuid,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      contacted_for_prevention,
      has_regular_free_sex_partner,
      year_started_sex_work,
      year_started_sex_with_men,
      year_started_drugs,
      has_expereienced_sexual_violence,
      has_expereienced_physical_violence,
      ever_tested_for_hiv,
      test_type,
      share_test_results,
      willing_to_test,
      test_decline_reason,
      receiving_hiv_care,
      care_facility_name,
      ccc_number,
      vl_test_done,
      vl_results_date,
      contact_for_appointment,
      contact_method,
      buddy_name,
      buddy_phone_number,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        e.encounter_datetime as visit_date,
        e.location_id,
        e.encounter_id,
        e.creator,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=165004,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as contacted_for_prevention,
        max(if(o.concept_id=165027,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as has_regular_free_sex_partner,
        max(if(o.concept_id=165030,o.value_numeric,null)) as year_started_sex_work,
        max(if(o.concept_id=165031,o.value_numeric,null)) as year_started_sex_with_men,
        max(if(o.concept_id=165032,o.value_numeric,null)) as year_started_drugs,
        max(if(o.concept_id=123160,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as has_expereienced_sexual_violence,
        max(if(o.concept_id=165034,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as has_expereienced_physical_violence,
        max(if(o.concept_id=164401,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as ever_tested_for_hiv,
        max(if(o.concept_id=164956,(case o.value_coded when 163722 then "Rapid HIV Testing" when 164952 THEN "Self Test" else "" end),null)) as test_type,
        max(if(o.concept_id=165153,(case o.value_coded when 703 then "Yes I tested positive" when 664 THEN "Yes I tested negative" when 1066 THEN "No I do not want to share" else "" end),null)) as share_test_results,
        max(if(o.concept_id=165154,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as willing_to_test,
        max(if(o.concept_id=159803,o.value_text,null)) as test_decline_reason,
        max(if(o.concept_id=159811,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as receiving_hiv_care,
        max(if(o.concept_id=162724,o.value_text,null)) as care_facility_name,
        max(if(o.concept_id=162053,o.value_numeric,null)) as ccc_number,
        max(if(o.concept_id=164437,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as vl_test_done,
        max(if(o.concept_id=163281,o.value_datetime,null)) as vl_results_date,
        max(if(o.concept_id=165036,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as contact_for_appointment,
        max(if(o.concept_id=164966,(case o.value_coded when 161642 then "Treatment supporter" when 165037 then "Peer educator"  when 1555 then "Outreach worker"
                                    when 159635 then "Phone number" else "" end),null)) as contact_method,
        max(if(o.concept_id=160638,o.value_text,null)) as buddy_name,
        max(if(o.concept_id=160642,o.value_text,null)) as buddy_phone_number,
        e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid='c7f47a56-207b-11e9-ab14-d663bd873d93'
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (165004,165027,165030,165031,165032,123160,165034,164401,164956,165153,165154,159803,159811,
                                                                                                                                   162724,162053,164437,163281,165036,164966,160638,160642)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE
      encounter_provider=VALUES(encounter_provider),
      visit_date=VALUES(visit_date),
      has_expereienced_sexual_violence=VALUES(has_expereienced_sexual_violence),
      has_expereienced_physical_violence=VALUES(has_expereienced_physical_violence),
      ever_tested_for_hiv=VALUES(ever_tested_for_hiv),
      test_type=VALUES(test_type),
      share_test_results=VALUES(share_test_results),
      willing_to_test=VALUES(willing_to_test),
      test_decline_reason=VALUES(test_decline_reason),
      receiving_hiv_care=VALUES(receiving_hiv_care),
      care_facility_name=VALUES(care_facility_name),
      ccc_number=VALUES(ccc_number),
      vl_test_done=VALUES(vl_test_done),
      vl_results_date=VALUES(vl_results_date),
      contact_for_appointment=VALUES(contact_for_appointment),
      contact_method=VALUES(contact_method),
      buddy_name=VALUES(buddy_name),
      buddy_phone_number=VALUES(buddy_phone_number),
      voided=VALUES(voided);
    END $$


-- ------------- populate etl_kp_clinical_visit--------------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_kp_clinical_visit $$
CREATE PROCEDURE sp_update_etl_kp_clinical_visit(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing Clinical Visit ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_clinical_visit(
      uuid,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      implementing_partner,
      type_of_visit,
      visit_reason,
      service_delivery_model,
      sti_screened,
      sti_results,
      sti_treated,
      sti_referred,
      sti_referred_text,
      tb_screened,
      tb_results,
      tb_treated,
      tb_referred,
      tb_referred_text,
      hepatitisB_screened,
      hepatitisB_results,
      hepatitisB_treated,
      hepatitisB_referred,
      hepatitisB_text,
      hepatitisC_screened,
      hepatitisC_results,
      hepatitisC_treated,
      hepatitisC_referred,
      hepatitisC_text,
      overdose_screened,
      overdose_results,
      overdose_treated,
      received_naloxone,
      overdose_referred,
      overdose_text,
      abscess_screened,
      abscess_results,
      abscess_treated,
      abscess_referred,
      abscess_text,
      alcohol_screened,
      alcohol_results,
      alcohol_treated,
      alcohol_referred,
      alcohol_text,
      cerv_cancer_screened,
      cerv_cancer_results,
      cerv_cancer_treated,
      cerv_cancer_referred,
      cerv_cancer_text,
      prep_screened,
      prep_results,
      prep_treated,
      prep_referred,
      prep_text,
      violence_screened,
      violence_results,
      violence_treated,
      violence_referred,
      violence_text,
      risk_red_counselling_screened,
      risk_red_counselling_eligibility,
      risk_red_counselling_support,
      risk_red_counselling_ebi_provided,
      risk_red_counselling_text,
      fp_screened,
      fp_eligibility,
      fp_treated,
      fp_referred,
      fp_text,
      mental_health_screened,
      mental_health_results,
      mental_health_support,
      mental_health_referred,
      mental_health_text,
      mat_screened,
      mat_results,
      mat_treated,
      mat_referred,
      mat_text,
      hiv_self_rep_status,
      last_hiv_test_setting,
      counselled_for_hiv,
      hiv_tested,
      test_frequency,
      received_results,
      test_results,
      linked_to_art,
      facility_linked_to,
      self_test_education,
      self_test_kits_given,
      self_use_kits,
      distribution_kits,
      self_tested,
      self_test_date,
      self_test_frequency,
      self_test_results,
      test_confirmatory_results,
      confirmatory_facility,
      offsite_confirmatory_facility,
      self_test_linked_art,
      self_test_link_facility,
      hiv_care_facility,
      other_hiv_care_facility,
      initiated_art_this_month,
      active_art,
      eligible_vl,
      vl_test_done,
      vl_results,
      received_vl_results,
      condom_use_education,
      post_abortal_care,
      referral,
      linked_to_psychosocial,
      male_condoms_no,
      female_condoms_no,
      lubes_no,
      syringes_needles_no,
      pep_eligible,
      exposure_type,
      other_exposure_type,
      clinical_notes,
      appointment_date,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        (e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=165347,o.value_text,null)) as implementing_partner,
        max(if(o.concept_id=164181,(case o.value_coded when 162080 then "Initial" when 164142 THEN "Revisit" else "" end),null)) as type_of_visit,
        max(if(o.concept_id=164082,(case o.value_coded when 5006 then "Asymptomatic" when 1068 THEN "Symptomatic" when 165348 then "Quarterly Screening checkup" when 160523 then "Follow up"  else "" end),null)) as visit_reason,
        max(if(o.concept_id=160540,(case o.value_coded when 161235 then "Static" when 160545 THEN "Outreach" else "" end),null)) as service_delivery_model,
        max(if(o.concept_id=161558,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as sti_screened,
        max(if(o.concept_id=165199,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" else "" end),null)) as sti_results,
        max(if(o.concept_id=165200,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as sti_treated,
        max(if(o.concept_id=165249,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as sti_referred,
        max(if(o.concept_id=165250,o.value_text,null)) as sti_referred_text,
        max(if(o.concept_id=165197,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as tb_screened,
        max(if(o.concept_id=165198,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" else "" end),null)) as tb_results,
        max(if(o.concept_id=1111,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "NA" end),null)) as tb_treated,
        max(if(o.concept_id=162310,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as tb_referred,
        max(if(o.concept_id=163323,o.value_text,null)) as tb_referred_text,
        max(if(o.concept_id=165040,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as hepatitisB_screened,
        max(if(o.concept_id=1322,(case o.value_coded when 664 then "N" when 703 THEN "P" else "" end),null)) as hepatitisB_results,
        max(if(o.concept_id=165251,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" when 782 then "Vaccinated" else "NA" end),null)) as hepatitisB_treated,
        max(if(o.concept_id=165252,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as hepatitisB_referred,
        max(if(o.concept_id=165253,o.value_text,null)) as hepatitisB_text,
        max(if(o.concept_id=165041,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as hepatitisC_screened,
        max(if(o.concept_id=161471,(case o.value_coded when 664 then "N" when 703 THEN "P" else "" end),null)) as hepatitisC_results,
        max(if(o.concept_id=165254,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "NA" end),null)) as hepatitisC_treated,
        max(if(o.concept_id=165255,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as hepatitisC_referred,
        max(if(o.concept_id=165256,o.value_text,null)) as hepatitisC_text,
        max(if(o.concept_id=165042,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as overdose_screened,
        max(if(o.concept_id=165046,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" else "" end),null)) as overdose_results,
        max(if(o.concept_id=165257,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as overdose_treated,
        max(if(o.concept_id=165201,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as received_naloxone,
        max(if(o.concept_id=165258,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as overdose_referred,
        max(if(o.concept_id=165259,o.value_text,null)) as overdose_text,
        max(if(o.concept_id=165044,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as abscess_screened,
        max(if(o.concept_id=165051,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" else "" end),null)) as abscess_results,
        max(if(o.concept_id=165260,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as abscess_treated,
        max(if(o.concept_id=165261,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as abscess_referred,
        max(if(o.concept_id=165262,o.value_text,null)) as abscess_text,
        max(if(o.concept_id=165043,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as alcohol_screened,
        max(if(o.concept_id=165047,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" else "" end),null)) as alcohol_results,
        max(if(o.concept_id=165263,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as alcohol_treated,
        max(if(o.concept_id=165264,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as alcohol_referred,
        max(if(o.concept_id=165265,o.value_text,null)) as alcohol_text,
        max(if(o.concept_id=164934,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as cerv_cancer_screened,
        max(if(o.concept_id=165196,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" else "" end),null)) as cerv_cancer_results,
        max(if(o.concept_id=165266,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as cerv_cancer_treated,
        max(if(o.concept_id=165267,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as cerv_cancer_referred,
        max(if(o.concept_id=165268,o.value_text,null)) as cerv_cancer_text,
        max(if(o.concept_id=165076,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" when 165080 then "Ongoing" else "" end),null)) as prep_screened,
        max(if(o.concept_id=165202,(case o.value_coded when 165087 then "Eligible" when 165078 THEN "Not eligible" else "" end),null)) as prep_results,
        max(if(o.concept_id=165203,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as prep_treated,
        max(if(o.concept_id=165270,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as prep_referred,
        max(if(o.concept_id=165271,o.value_text,null)) as prep_text,
        max(if(o.concept_id=165204,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as violence_screened,
        max(if(o.concept_id=165205,(case o.value_coded when 165206 then "Harrasment" when 121387 then "Assault" when 165207 THEN "Illegal arrest" when 123007 THEN "Verbal Abuse" when 127910 THEN "Rape/Sexual assault" when 126312 THEN "Discrimination"  else "" end),null)) as violence_results,
        max(if(o.concept_id=165208,(case o.value_coded when  1065 then "Supported" when 1066 THEN "Not supported" else "" end),null)) as violence_treated,
        max(if(o.concept_id=165273,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as violence_referred,
        max(if(o.concept_id=165274,o.value_text,null)) as violence_text,
        max(if(o.concept_id=165045,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as risk_red_counselling_screened,
        max(if(o.concept_id=165050,(case o.value_coded when 165087 then "Eligible" when 165078 THEN "Not eligible" else "" end),null)) as risk_red_counselling_eligibility,
        max(if(o.concept_id=165053,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as risk_red_counselling_support,
        max(if(o.concept_id=161595,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" else "" end),null)) as risk_red_counselling_ebi_provided,
        max(if(o.concept_id=165277,o.value_text,null)) as risk_red_counselling_text,
        max(if(o.concept_id=1382,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as fp_screened,
        max(if(o.concept_id=165209,(case o.value_coded when 165087 then "Eligible" when 165078 THEN "Not eligible" else "" end),null)) as fp_eligibility,
        max(if(o.concept_id=160653,(case o.value_coded when 1065 then "Y" when 1066 THEN "N" when 965 then "On-going" else "" end),null)) as fp_treated,
        max(if(o.concept_id=165279,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as fp_referred,
        max(if(o.concept_id=165280,o.value_text,null)) as fp_text,
        max(if(o.concept_id=165210,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as mental_health_screened,
        max(if(o.concept_id=165211,(case o.value_coded when 165212 then "Depression unlikely" when 157790 THEN "Mild depression" when 134017 THEN "Moderate depression" when 134011 THEN "Moderate-severe depression" when 126627 THEN "Severe Depression"  else "" end),null)) as mental_health_results,
        max(if(o.concept_id=165213,(case o.value_coded when 1065 then "Supported" when 1066 THEN "Not supported" else "" end),null)) as mental_health_support,
        max(if(o.concept_id=165281,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as mental_health_referred,
        max(if(o.concept_id=165282,o.value_text,null)) as mental_health_text,
        max(if(o.concept_id=166663,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as mat_screened,
        max(if(o.concept_id=166664,(case o.value_coded when 703 then "Positive" when 664 THEN "Negative"  else "" end),null)) as mat_results,
        max(if(o.concept_id=165052,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as mat_treated,
        max(if(o.concept_id=165093,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as mat_referred,
        max(if(o.concept_id=166637,o.value_text,null)) as mental_health_text,
        max(if(o.concept_id=165214,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" when 1067 then "Unknown" else "" end),null)) as hiv_self_rep_status,
        max(if(o.concept_id=165215,(case o.value_coded when 165216 then "Universal HTS" when 165217 THEN "Self-testing" when 1402 then "Never tested" else "" end),null)) as last_hiv_test_setting,
        max(if(o.concept_id=159382,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as counselled_for_hiv,
        max(if(o.concept_id=164401,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" when 1175 then "Not Applicable" when 162570 then "Declined" when 1788 then "Referred for testing" else "" end),null)) as hiv_tested,
        max(if(o.concept_id=165218,(case o.value_coded when 162080 THEN "Initial" when 162081 then "Repeat" when 1175 then "Not Applicable" else "" end),null)) as test_frequency,
        max(if(o.concept_id=164848,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" when 1067 then "Not Applicable" else "" end),null)) as received_results,
        max(if(o.concept_id=159427,(case o.value_coded when 664 then "Negative" when 703 THEN "Positive" when 165232 then "Inconclusive" when 138571 then "Known Positive" when 1118 then "Not done" else "" end),null)) as test_results,
        max(if(o.concept_id=1648,(case o.value_coded when 1 then "Yes" when 0 then "No" else "" end),null)) as linked_to_art,
        max(if(o.concept_id=163042,o.value_text,null)) as facility_linked_to,
        max(if(o.concept_id=165220,(case o.value_coded when 1065 then "Yes" when 1066 THEN "No" else "" end),null)) as self_test_education,
        max(if(o.concept_id=165221,(case o.value_coded when 165222 then "Self use" when 165223 THEN "Distribution" else "" end),null)) as self_test_kits_given,
        max(if(o.concept_id=165222,o.value_numeric,null)) as self_use_kits,
        max(if(o.concept_id=165223,o.value_numeric,null)) as distribution_kits,
        max(if(o.concept_id=164952,(case o.value_coded when 1065 THEN "Y" when 1066 then "N" else "" end),null)) as self_tested,
        max(if(o.concept_id=164400,o.value_datetime,null)) as self_test_date,
        max(if(o.concept_id=165231,(case o.value_coded when 162080 THEN "Initial" when 162081 then "Repeat" else "" end),null)) as self_test_frequency,
        max(if(o.concept_id=165233,(case o.value_coded when 664 THEN "Negative" when 703 then "Positive" when 165232 then "Inconclusive" else "" end),null)) as self_test_results,
        max(if(o.concept_id=165234,(case o.value_coded when 664 THEN "Negative" when 703 then "Positive" when 1118 then "Not done" else "" end),null)) as test_confirmatory_results,
        max(if(o.concept_id=165237,o.value_text,null)) as confirmatory_facility,
        max(if(o.concept_id=162724,o.value_text,null)) as offsite_confirmatory_facility,
        max(if(o.concept_id=165238,(case o.value_coded when 1 then "Yes" when 0 then "No" else "" end),null)) as self_test_linked_art,
        max(if(o.concept_id=161562,o.value_text,null)) as self_test_link_facility,
        max(if(o.concept_id=165239,(case o.value_coded when 163266 THEN "Provided here" when 162723 then "Provided elsewhere" when 160563 then "Referred" else "" end),null)) as hiv_care_facility,
        max(if(o.concept_id=163042,o.value_text,null)) as other_hiv_care_facility,
        max(if(o.concept_id=165240,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" when 1175 then "Not Applicable" else "" end),null)) as initiated_art_this_month,
        max(if(o.concept_id=160119,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" when 1175 then "Not Applicable" else "" end),null)) as active_art,
        max(if(o.concept_id=165242,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" when 1175 then "Not Applicable" else "" end),null)) as eligible_vl,
        max(if(o.concept_id=165243,(case o.value_coded when 1065 THEN "Y" when 1066 then "N" when 1175 then "Not Applicable" else "" end),null)) as vl_test_done,
        max(if(o.concept_id=165246,(case o.value_coded when 165244 THEN "Y" when 165245 then "N" when 1175 then "NA" else "" end),null)) as vl_results,
        max(if(o.concept_id=165246,(case o.value_coded when 164369 then "N"  else "Y" end),null)) as received_vl_results,
        max(if(o.concept_id=165247,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as condom_use_education,
        max(if(o.concept_id=164820,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as post_abortal_care,
        max(if(o.concept_id=165302,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as referral,
        max(if(o.concept_id=163766,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as linked_to_psychosocial,
        max(if(o.concept_id=165055,o.value_numeric,null)) as male_condoms_no,
        max(if(o.concept_id=165056,o.value_numeric,null)) as female_condoms_no,
        max(if(o.concept_id=165057,o.value_numeric,null)) as lubes_no,
        max(if(o.concept_id=165058,o.value_numeric,null)) as syringes_needles_no,
        max(if(o.concept_id=164845,(case o.value_coded when 1065 THEN "Y" when 1066 then "N" else "NA" end),null)) as pep_eligible,
        max(if(o.concept_id=165060,(case o.value_coded when 127910 THEN "Rape" when 165045 then "Condom burst" when 5622 then "Others" else "" end),null)) as exposure_type,
        max(if(o.concept_id=163042,o.value_text,null)) as other_exposure_type,
        max(if(o.concept_id=165248,o.value_text,null)) as clinical_notes,
        max(if(o.concept_id=5096,o.value_datetime,null)) as appointment_date,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid in('92e03f22-9686-11e9-bc42-526af7764f64')
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (165347,164181,164082,160540,161558,165199,165200,165249,165250,165197,165198,1111,162310,163323,165040,1322,165251,165252,165253,
                                                                                                                                   165041,161471,165254,165255,165256,165042,165046,165257,165201,165258,165259,165044,165051,165260,165261,165262,165043,165047,165263,165264,165265,
                                                                                                                                                                                                                       164934,165196,165266,165267,165268,165076,165202,165203,165270,165271,165204,165205,165208,165273,165274,165045,165050,165053,161595,165277,1382,
          165209,160653,165279,165280,165210,165211,165213,165281,165282,166663,166664,165052,166637,165093,165214,165215,159382,164401,165218,164848,159427,1648,163042,165220,165221,165222,165223,
                                                                                                                                                    164952,164400,165231,165233,165234,165237,162724,165238,161562,165239,163042,165240,160119,165242,165243,165246,165247,164820,165302,163766,165055,165056,
                                                      165057,165058,164845,165248,5096)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE  visit_date=VALUES(visit_date),
      encounter_provider=VALUES(encounter_provider),
      implementing_partner=VALUES(implementing_partner),
      type_of_visit=VALUES(type_of_visit),
      visit_reason=VALUES(visit_reason),
      service_delivery_model=VALUES(service_delivery_model),
      sti_screened=VALUES(sti_screened),
      sti_results=VALUES(sti_results),
      sti_treated=VALUES(sti_treated),
      sti_referred=VALUES(sti_referred),
      sti_referred_text=VALUES(sti_referred_text),
      tb_screened=VALUES(tb_screened),
      tb_results=VALUES(tb_results),
      tb_treated=VALUES(tb_treated),
      tb_referred=VALUES(tb_referred),
      tb_referred_text=VALUES(tb_referred_text),
      hepatitisB_screened=VALUES(hepatitisB_screened),
      hepatitisB_results=VALUES(hepatitisB_results),
      hepatitisB_treated=VALUES(hepatitisB_treated),
      hepatitisB_referred=VALUES(hepatitisB_referred),
      hepatitisB_text=VALUES(hepatitisB_text),
      hepatitisC_screened=VALUES(hepatitisC_screened),
      hepatitisC_results=VALUES(hepatitisC_results),
      hepatitisC_treated=VALUES(hepatitisC_treated),
      hepatitisC_referred=VALUES(hepatitisC_referred),
      hepatitisC_text=VALUES(hepatitisC_text),
      overdose_screened=VALUES(overdose_screened),
      overdose_results=VALUES(overdose_results),
      overdose_treated=VALUES(overdose_treated),
      received_naloxone=VALUES(received_naloxone),
      overdose_referred=VALUES(overdose_referred),
      overdose_text=VALUES(overdose_text),
      abscess_screened=VALUES(abscess_screened),
      abscess_results=VALUES(abscess_results),
      abscess_treated=VALUES(abscess_treated),
      abscess_referred=VALUES(abscess_referred),
      abscess_text=VALUES(abscess_text),
      alcohol_screened=VALUES(alcohol_screened),
      alcohol_results=VALUES(alcohol_results),
      alcohol_treated=VALUES(alcohol_treated),
      alcohol_referred=VALUES(alcohol_referred),
      alcohol_text=VALUES(alcohol_text),
      cerv_cancer_screened=VALUES(cerv_cancer_screened),
      cerv_cancer_results=VALUES(cerv_cancer_results),
      cerv_cancer_treated=VALUES(cerv_cancer_treated),
      cerv_cancer_referred=VALUES(cerv_cancer_referred),
      cerv_cancer_text=VALUES(cerv_cancer_text),
      prep_screened=VALUES(prep_screened),
      prep_results=VALUES(prep_results),
      prep_treated=VALUES(prep_treated),
      prep_referred=VALUES(prep_referred),
      prep_text=VALUES(prep_text),
      violence_screened=VALUES(violence_screened),
      violence_results=VALUES(violence_results),
      violence_treated=VALUES(violence_treated),
      violence_referred=VALUES(violence_referred),
      violence_text=VALUES(violence_text),
      risk_red_counselling_screened=VALUES(risk_red_counselling_screened),
      risk_red_counselling_eligibility=VALUES(risk_red_counselling_eligibility),
      risk_red_counselling_support=VALUES(risk_red_counselling_support),
      risk_red_counselling_ebi_provided=VALUES(risk_red_counselling_ebi_provided),
      risk_red_counselling_text=VALUES(risk_red_counselling_text),
      fp_screened=VALUES(fp_screened),
      fp_eligibility=VALUES(fp_eligibility),
      fp_treated=VALUES(fp_treated),
      fp_referred=VALUES(fp_referred),
      fp_text=VALUES(fp_text),
      mental_health_screened=VALUES(mental_health_screened),
      mental_health_results=VALUES(mental_health_results),
      mental_health_support=VALUES(mental_health_support),
      mental_health_referred=VALUES(mental_health_referred),
      mental_health_text=VALUES(mental_health_text),
      mat_screened=VALUES(mat_screened),
      mat_results=VALUES(mat_results),
      mat_treated=VALUES(mat_treated),
      mat_referred=VALUES(mat_referred),
      mat_text=VALUES(mat_text),
      hiv_self_rep_status=VALUES(hiv_self_rep_status),
      last_hiv_test_setting=VALUES(last_hiv_test_setting),
      counselled_for_hiv=VALUES(counselled_for_hiv),
      hiv_tested=VALUES(hiv_tested),
      test_frequency=VALUES(test_frequency),
      received_results=VALUES(received_results),
      test_results=VALUES(test_results),
      linked_to_art=VALUES(linked_to_art),
      facility_linked_to=VALUES(facility_linked_to),
      self_test_education=VALUES(self_test_education),
      self_test_kits_given=VALUES(self_test_kits_given),
      self_use_kits=VALUES(self_use_kits),
      distribution_kits=VALUES(distribution_kits),
      self_tested=VALUES(self_tested),
      self_test_date=VALUES(self_test_date),
      self_test_frequency=VALUES(self_test_frequency),
      self_test_results=VALUES(self_test_results),
      test_confirmatory_results=VALUES(test_confirmatory_results),
      confirmatory_facility=VALUES(confirmatory_facility),
      offsite_confirmatory_facility=VALUES(offsite_confirmatory_facility),
      self_test_linked_art=VALUES(self_test_linked_art),
      self_test_link_facility=VALUES(self_test_link_facility),
      hiv_care_facility=VALUES(hiv_care_facility),
      other_hiv_care_facility=VALUES(other_hiv_care_facility),
      initiated_art_this_month=VALUES(initiated_art_this_month),
      active_art=VALUES(active_art),
      eligible_vl=VALUES(eligible_vl),
      vl_test_done=VALUES(vl_test_done),
      vl_results=VALUES(vl_results),
      received_vl_results=VALUES(received_vl_results),
      condom_use_education=VALUES(condom_use_education),
      post_abortal_care=VALUES(post_abortal_care),
      referral=VALUES(referral),
      linked_to_psychosocial=VALUES(linked_to_psychosocial),
      male_condoms_no=VALUES(male_condoms_no),
      female_condoms_no=VALUES(female_condoms_no),
      lubes_no=VALUES(lubes_no),
      syringes_needles_no=VALUES(syringes_needles_no),
      pep_eligible=VALUES(pep_eligible),
      exposure_type=VALUES(exposure_type),
      other_exposure_type=VALUES(other_exposure_type),
      clinical_notes=VALUES(clinical_notes),
      appointment_date=VALUES(appointment_date),
      voided=VALUES(voided);
    END $$

-- ------------- populate etl_kp_sti_treatment--------------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_kp_sti_treatment $$
CREATE PROCEDURE sp_update_etl_kp_sti_treatment(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing STI Treatment ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_sti_treatment(
      uuid,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      visit_reason,
      syndrome,
      other_syndrome,
      drug_prescription,
      other_drug_prescription,
      genital_exam_done,
      lab_referral,
      lab_form_number,
      referred_to_facility,
      facility_name,
      partner_referral_done,
      given_lubes,
      no_of_lubes,
      given_condoms,
      no_of_condoms,
      provider_comments,
      provider_name,
      appointment_date,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        (e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=164082,(case o.value_coded when 1068 THEN "Symptomatic" when 5006 then "Asymptomatic" when 163139 then "Quartely Screening" when 160523 then "Follow up" else "" end),null)) as visit_reason,
        max(if(o.concept_id=1169,(case o.value_coded when 1065 then "Positive" when 1066 then "Negative" else "" end),null)) as syndrome,
        max(if(o.concept_id=165138,o.value_text,null)) as other_syndrome,
        max(if(o.concept_id=165200,(case o.value_coded when 1065 then "Yes" when 1066 then "No"
                                    else "" end),null)) as drug_prescription,
        max(if(o.concept_id=163101,o.value_text,null)) as other_drug_prescription,
        max(if(o.concept_id=163743,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as genital_exam_done,
        max(if(o.concept_id=1272,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as lab_referral,
        max(if(o.concept_id=163042,o.value_text,null)) as lab_form_number,
        max(if(o.concept_id=1788,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as referred_to_facility,
        max(if(o.concept_id=162724,o.value_text,null)) as facility_name,
        max(if(o.concept_id=165128,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as partner_referral_done,
        max(if(o.concept_id=165127,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as given_lubes,
        max(if(o.concept_id=163169,o.value_numeric,null)) as no_of_lubes,
        max(if(o.concept_id=159777,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as given_condoms,
        max(if(o.concept_id=165055,o.value_numeric,null)) as no_of_condoms,
        max(if(o.concept_id=162749,o.value_text,null)) as provider_comments,
        max(if(o.concept_id=1473,o.value_text,null)) as provider_name,
        max(if(o.concept_id=5096,o.value_datetime,null)) as appointment_date,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid in('2cc8c535-bbfa-4668-98c7-b12e3550ee7b')
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (164082,1169,165138,165200,163101,163743,1272,163042,1788,162724,165128,165127,163169,
                                                      159777,165055,162749,1473,5096)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      encounter_provider=VALUES(encounter_provider),
      visit_reason=VALUES(visit_reason),
      syndrome=VALUES(syndrome),
      other_syndrome=VALUES(other_syndrome),
      drug_prescription=VALUES(drug_prescription),
      other_drug_prescription=VALUES(other_drug_prescription),
      genital_exam_done=VALUES(genital_exam_done),
      lab_referral=VALUES(lab_referral),
      lab_form_number=VALUES(lab_form_number),
      referred_to_facility=VALUES(referred_to_facility),
      facility_name=VALUES(facility_name),
      partner_referral_done=VALUES(partner_referral_done),
      given_lubes=VALUES(given_lubes),
      no_of_lubes=VALUES(no_of_lubes),
      given_condoms=VALUES(given_condoms),
      no_of_condoms=VALUES(no_of_condoms),
      provider_comments=VALUES(provider_comments),
      provider_name=VALUES(provider_name),
      appointment_date=VALUES(appointment_date),
      voided=VALUES(voided);

    END $$
-- ------------- populate etl_kp_peer_calendar--------------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_kp_peer_calendar $$
CREATE PROCEDURE sp_update_etl_kp_peer_calendar(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing Peer calendar ", CONCAT("Time: ", NOW());
    INSERT INTO  kenyaemr_etl.etl_peer_calendar(
      uuid,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      encounter_provider,
      date_created,
      date_last_modified,
      hotspot_name,
      typology,
      other_hotspots,
      weekly_sex_acts,
      monthly_condoms_required,
      weekly_anal_sex_acts,
      monthly_lubes_required,
      daily_injections,
      monthly_syringes_required,
      years_in_sexwork_drugs,
      experienced_violence,
      service_provided_within_last_month,
      monthly_n_and_s_distributed,
      monthly_male_condoms_distributed,
      monthly_lubes_distributed,
      monthly_female_condoms_distributed,
      monthly_self_test_kits_distributed,
      received_clinical_service,
      violence_reported,
      referred,
      health_edu,
      remarks,
      voided
    )
      select
        e.uuid,
        e.patient_id,
        e.visit_id,
        (e.encounter_datetime) as visit_date,
        e.location_id,
        e.encounter_id as encounter_id,
        e.creator,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        max(if(o.concept_id=165006,o.value_text,null)) as hotspot_name,
        max(if(o.concept_id=165005,(case o.value_coded when  165011 then "Street" when  165012 then" Injecting den" when  165013 then" Uninhabitable building"
                                    when  165014 then" Park" when  1536 then" Homes" when  165015 then" Beach" when  165016 then" Casino"
                                    when  165017 then "Bar with lodging" when  165018 then "Bar without lodging"
                                    when  165019 then "Sex den" when  165020 then "Strip club" when  165021 then "Highways" when  165022 then "Brothel"
                                    when  165023 then "Guest house/Hotels/Lodgings" when 165024 then "Massage parlor" when 165025 then "Chang’aa den" when 165026 then "Barbershop/Salon"
                                    when  165297 then "Virtual Space" when  5622 then "Other (Specify)" else "" end),null)) as typology,
        max(if(o.concept_id=165298,o.value_text,null)) as other_hotspots,
        max(if(o.concept_id=165007,o.value_numeric,null)) as weekly_sex_acts,
        max(if(o.concept_id=165299,o.value_numeric,null)) as monthly_condoms_required,
        max(if(o.concept_id=165008,o.value_numeric,null)) as weekly_anal_sex_acts,
        max(if(o.concept_id=165300,o.value_numeric,null)) as monthly_lubes_required,
        max(if(o.concept_id=165009,o.value_numeric,null)) as daily_injections,
        max(if(o.concept_id=165308,o.value_numeric,null)) as monthly_syringes_required,
        max(if(o.concept_id=165301,o.value_numeric,null)) as years_in_sexwork_drugs,
        max(if(o.concept_id=123160,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as experienced_violence,
        max(if(o.concept_id=165302,(case o.value_coded when 159777 then "Condoms" when 165303 then "Needles and Syringes" when 165004 then "Contact" when 161643 THEN "Visited Clinic" else "" end),null)) as service_provided_within_last_month,
        max(if(o.concept_id=165341,o.value_numeric,null)) as monthly_n_and_s_distributed,
        max(if(o.concept_id=165343,o.value_numeric,null)) as monthly_male_condoms_distributed,
        max(if(o.concept_id=165057,o.value_numeric,null)) as monthly_lubes_distributed,
        max(if(o.concept_id=165344,o.value_numeric,null)) as monthly_female_condoms_distributed,
        max(if(o.concept_id=165345,o.value_numeric,null)) as monthly_self_test_kits_distributed,
        max(if(o.concept_id=1774,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as received_clinical_service,
        max(if(o.concept_id=165272,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as violence_reported,
        max(if(o.concept_id=1749,o.value_numeric,null)) as referred,
        max(if(o.concept_id=165346,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as health_edu,
        max(if(o.concept_id=160632,o.value_text,null)) as remarks,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join
        (
          select encounter_type_id, uuid, name from encounter_type where uuid in('c4f9db39-2c18-49a6-bf9b-b243d673c64d')
        ) et on et.encounter_type_id=e.encounter_type
        left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
                                 and o.concept_id in (165006,165005,165298,165007,165299,165008,165301,165302,165341,165343,165057,165344,165345,
                                                      1774,123160,1749,165346,160632,165272)
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      encounter_provider=VALUES(encounter_provider),
      hotspot_name=VALUES(hotspot_name),
      typology=VALUES(typology),
      other_hotspots=VALUES(other_hotspots),
      weekly_sex_acts=VALUES(weekly_sex_acts),
      monthly_condoms_required=VALUES(monthly_condoms_required),
      weekly_anal_sex_acts=VALUES(weekly_anal_sex_acts),
      monthly_lubes_required=VALUES(monthly_lubes_required),
      daily_injections=VALUES(daily_injections),
      monthly_syringes_required=VALUES(monthly_syringes_required),
      years_in_sexwork_drugs=VALUES(years_in_sexwork_drugs),
      experienced_violence=VALUES(experienced_violence),
      service_provided_within_last_month=VALUES(service_provided_within_last_month),
      monthly_n_and_s_distributed=VALUES(monthly_n_and_s_distributed),
      monthly_male_condoms_distributed=VALUES(monthly_male_condoms_distributed),
      monthly_lubes_distributed=VALUES(monthly_lubes_distributed),
      monthly_female_condoms_distributed=VALUES(monthly_female_condoms_distributed),
      monthly_self_test_kits_distributed=VALUES(monthly_self_test_kits_distributed),
      received_clinical_service=VALUES(received_clinical_service),
      violence_reported=VALUES(violence_reported),
      referred=VALUES(referred),
      health_edu=VALUES(health_edu),
      remarks=VALUES(remarks),
      voided=VALUES(voided);

    END $$

-- ------------- populate kp peer tracking-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_kp_peer_tracking $$
CREATE PROCEDURE sp_update_etl_kp_peer_tracking(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing kp peer tracking form", CONCAT("Time: ", NOW());

    insert into kenyaemr_etl.etl_peer_tracking(
      uuid,
      provider,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      tracing_attempted,
      tracing_not_attempted_reason,
      attempt_number,
      tracing_date,
      tracing_type,
      tracing_outcome,
      is_final_trace,
      tracing_outcome_status,
      voluntary_exit_comment,
      status_in_program,
      source_of_information,
      other_informant,
      date_created,
      date_last_modified,
      voided
    )
      select
        e.uuid, e.creator, e.patient_id, e.visit_id, e.encounter_datetime, e.location_id, e.encounter_id,
        max(if(o.concept_id=165004,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as tracing_attempted,
        max(if(o.concept_id=165071,(case o.value_coded when 165078 THEN "Contact information illegible" when 165073 then "Location listed too general to make tracking possible"
                                    when 165072 then "Contact information missing" when 163777 then "Cohort register or peer outreach calendar reviewed and client not lost to follow up" when 5622 then "other" else "" end),null)) as tracing_not_attempted_reason,
        max(if(o.concept_id = 1639, o.value_numeric, "" )) as attempt_number,
        max(if(o.concept_id = 160753, o.value_datetime, "" )) as tracing_date,
        max(if(o.concept_id = 164966, (case o.value_coded when 1650 THEN "Phone" when 164965 then "Physical" else "" end),null)) as tracing_type,
        max(if(o.concept_id = 160721, (case o.value_coded when 160718 THEN "KP reached" when 160717 then "KP not reached but other informant reached" when 160720 then "KP not reached" else "" end),null)) as tracing_outcome,
        max(if(o.concept_id = 163725, (case o.value_coded when 1267 THEN "Yes" when 163339 then "No" else "" end),null)) as is_final_trace,
        max(if(o.concept_id = 160433,(case o.value_coded when 160432 then "Dead" when 160415 then "Relocated" when 165219 then "Voluntary exit" when
          134236 then "Enrolled in MAT (applicable to PWIDS only)" when 165067 then "Untraceable" when 162752 then "Bedridden" when 156761 then "Imprisoned" when 162632 then "Found" else "" end),null)) as tracing_outcome_status,
        max(if(o.concept_id = 160716, o.value_text, "" )) as voluntary_exit_comment,
        max(if(o.concept_id = 161641, (case o.value_coded when 5240 THEN "Lost to follow up" when 160031 then "Defaulted" when 161636 then "Active" when 160432 then "Dead" else "" end),null)) as status_in_program,
        max(if(o.concept_id = 162568, (case o.value_coded when 164929 THEN "KP" when 165037 then "PE" when 5622 then "Other" else "" end),null)) as source_of_information,
        max(if(o.concept_id = 160632, o.value_text, "" )) as other_informant,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ('63917c60-3fea-11e9-b210-d663bd873d93')
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (165004,165071,1639,160753,164966,160721,163725,160433,160716,161641,162568,160632) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      tracing_attempted=VALUES(tracing_attempted),
      tracing_not_attempted_reason=VALUES(tracing_not_attempted_reason),
      attempt_number=VALUES(attempt_number),
      tracing_date=VALUES(tracing_date),
      tracing_type=VALUES(tracing_type),
      tracing_outcome=VALUES(tracing_outcome),
      is_final_trace=VALUES(is_final_trace),
      tracing_outcome_status=VALUES(tracing_outcome_status),
      voluntary_exit_comment=VALUES(voluntary_exit_comment),
      status_in_program=VALUES(status_in_program),
      source_of_information=VALUES(source_of_information),
      other_informant=VALUES(other_informant),
      voided=VALUES(voided);

    END $$

DROP PROCEDURE IF EXISTS sp_update_etl_kp_treatment_verification $$
CREATE PROCEDURE sp_update_etl_kp_treatment_verification(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing kp treatment verification form", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_treatment_verification(
      uuid,
      provider,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_diagnosed_with_hiv,
      art_health_facility,
      ccc_number,
      is_pepfar_site,
      date_initiated_art,
      current_regimen,
      information_source,
      cd4_test_date,
      cd4,
      vl_test_date,
      viral_load,
      disclosed_status,
      person_disclosed_to,
      other_person_disclosed_to,
      IPT_start_date,
      IPT_completion_date,
      on_diff_care,
      in_support_group,
      support_group_name,
      opportunistic_infection,
      oi_diagnosis_date,
      oi_treatment_start_date,
      oi_treatment_end_date,
      comment,
      date_created,
      date_last_modified,
      voided
    )
      select
        e.uuid, e.creator, e.patient_id, e.visit_id, e.encounter_datetime, e.location_id, e.encounter_id,
        max(if(o.concept_id = 159948, o.value_datetime, "" )) as date_diagnosed_with_hiv,
        max(if(o.concept_id = 162724, o.value_text, "" )) as art_health_facility,
        max(if(o.concept_id = 162053, o.value_numeric, "" )) as ccc_number,
        max(if(o.concept_id=1768,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as is_pepfar_site,
        max(if(o.concept_id = 159599, o.value_datetime, "" )) as date_initiated_art,
        max(if(o.concept_id = 164515,(case o.value_coded
                                      when 162565 then "TDF/3TC/NVP"
                                      when 164505 then "TDF/3TC/EFV"
                                      when 1652 then "AZT/3TC/NVP"
                                      when 160124 then "AZT/3TC/EFV"
                                      when 792 then "D4T/3TC/NVP"
                                      when 160104 then "D4T/3TC/EFV"
                                      when 162561 then "AZT/3TC/LPV/r"
                                      when 164511 then "AZT/3TC/ATV/r"
                                      when 164512 then "TDF/3TC/ATV/r"
                                      when 162201 then "TDF/3TC/LPV/r"
                                      when 162561 then "AZT/3TC/LPV/r"
                                      when 164511 then "AZT/3TC/ATV/r"
                                      when 162201 then "TDF/3TC/LPV/r"
                                     when 164512 then "TDF/3TC/ATV/r"
                                      when 162560 then "D4T/3TC/LPV/r"
                                      when 162200 then "ABC/3TC/LPV/r"
                                      when 164971 then "TDF/3TC/AZT"
                                      when 164968 then "AZT/3TC/DTG"
                                      when 164969 then "TDF/3TC/DTG"
                                      when 164970 then "ABC/3TC/DTG"
                                      when 164972 then "AZT/TDF/3TC/LPV/r"
                                      when 164973 then "ETR/RAL/DRV/RTV"
                                      when 164974 then "ETR/TDF/3TC/LPV/r"
                                      when 165357 then "ABC/3TC/ATV/r"
                                      when 165375 then "RAL/3TC/DRV/RTV"
                                      when 165376 then "RAL/3TC/DRV/RTV/AZT"
                                      when 165379 then "RAL/3TC/DRV/RTV/TDF"
                                      when 165378 then "ETV/3TC/DRV/RTV"
                                      when 165369 then "TDF/3TC/DTG/DRV/r"
                                      when 165370 then "TDF/3TC/RAL/DRV/r"
                                      when 165371 then "TDF/3TC/DTG/EFV/DRV/r" else "" end),null)) as current_regimen,
        max(if(o.concept_id = 162568, (case o.value_coded when 162969 THEN "SMS" when 163787 then "Verbal report"  when 1238 then "Written record" when 162189 then "Phone call" when 160526 then "EID Dashboard" when 165048 then "Appointment card" else "" end),null)) as information_source,
        max(if(o.concept_id = 160103, o.value_datetime, "" )) as cd4_test_date,
        max(if(o.concept_id = 5497, o.value_numeric, "" )) as cd4,
        max(if(o.concept_id = 163281, o.value_datetime, "" )) as vl_test_date,
        max(if(o.concept_id = 160632, o.value_numeric, "" )) as viral_load,
        max(if(o.concept_id = 163524, (case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as disclosed_status,
        max(if(o.concept_id = 5616, (case o.value_coded when 159423 THEN "Sexual Partner" when 1560 then "Family member" when 161642 then "Treatment partner" when 160639 then "Spiritual Leader" when 5622 then "Other" else "" end),null)) as person_disclosed_to,
        max(if(o.concept_id = 163101, o.value_text, "" )) as other_person_disclosed_to,
        max(if(o.concept_id = 162320, o.value_datetime, "" )) as IPT_start_date,
        max(if(o.concept_id = 162279, o.value_datetime, "" )) as IPT_completion_date,
        max(if(o.concept_id=164947,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as on_diff_care,
        max(if(o.concept_id=165302,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as in_support_group,
        max(if(o.concept_id = 165137, o.value_text, "" )) as support_group_name,
        max(if(o.concept_id = 162634, (case o.value_coded when 112141 THEN "Tuberculosis" when 990 then "Toxoplasmosis" when 130021 then "Pneumocystosis carinii pneumonia" when 114100 then "Pneumonia" when 136326 then "Kaposi Sarcoma"
                                       when 123118 then "HIV encephalitis" when 117543 then "Herpes Zoster" when 154119 then "Cytomegalovirus (CMV)" when 1219 then "Cryptococcosis" when 120939 then "Candidiasis" when 116104 then "Lymphoma" when 5622 then "Other" else "" end),null)) as opportunistic_infection,
        max(if(o.concept_id = 159948, o.value_datetime, "" )) as oi_diagnosis_date,
        max(if(o.concept_id = 160753, o.value_datetime, "" )) as oi_treatment_start_date,
        max(if(o.concept_id = 162868, o.value_datetime, "" )) as oi_treatment_end_date,
        max(if(o.concept_id = 161011, o.value_datetime, "" )) as comment,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ('a70a1132-75b3-11ea-bc55-0242ac130003')
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (159948,162724,162053,1768,
                                                                                                159599,164515,162568,657,5497,163281,160632,163524,5616,5497,160716,161641,162568,163101,162320,162279,164947,
                                                                                         165302,165137,162634,159948,160753,162868,161011) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      date_diagnosed_with_hiv=VALUES(date_diagnosed_with_hiv),
      art_health_facility=VALUES(art_health_facility),
      ccc_number=VALUES(ccc_number),
      is_pepfar_site=VALUES(is_pepfar_site),
      date_initiated_art=VALUES(date_initiated_art),
      current_regimen=VALUES(current_regimen),
      information_source=VALUES(information_source),
      cd4_test_date=VALUES(cd4_test_date),
      cd4=VALUES(cd4),
      vl_test_date=VALUES(vl_test_date),
      viral_load=VALUES(viral_load),
      disclosed_status=VALUES(disclosed_status),
      person_disclosed_to=VALUES(person_disclosed_to),
      other_person_disclosed_to=VALUES(other_person_disclosed_to),
      IPT_start_date=VALUES(IPT_start_date),
      IPT_completion_date=VALUES(IPT_completion_date),
      on_diff_care=VALUES(on_diff_care),
      in_support_group=VALUES(in_support_group),
      support_group_name=VALUES(support_group_name),
      opportunistic_infection=VALUES(opportunistic_infection),
      oi_diagnosis_date=VALUES(oi_diagnosis_date),
      oi_treatment_start_date=VALUES(oi_treatment_start_date),
      oi_treatment_end_date=VALUES(oi_treatment_end_date),
      comment=VALUES(comment),
      voided=VALUES(voided);

    END $$


DROP PROCEDURE IF EXISTS sp_update_etl_gender_based_violence $$
CREATE PROCEDURE sp_update_etl_gender_based_violence(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing kp gender based violence form", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_gender_based_violence(
      uuid,
      provider,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      is_physically_abused,
      physical_abuse_perpetrator,
      other_physical_abuse_perpetrator,
      in_physically_abusive_relationship,
      in_physically_abusive_relationship_with,
      other_physically_abusive_relationship_perpetrator,
      in_emotionally_abusive_relationship,
      emotional_abuse_perpetrator,
      other_emotional_abuse_perpetrator,
      in_sexually_abusive_relationship,
      sexual_abuse_perpetrator,
      other_sexual_abuse_perpetrator,
      ever_abused_by_unrelated_person,
      unrelated_perpetrator,
      other_unrelated_perpetrator,
      sought_help,
      help_provider,
      date_helped,
      help_outcome,
      other_outcome,
      reason_for_not_reporting,
      other_reason_for_not_reporting,
      date_created,
      date_last_modified,
      voided
    )
      select
        e.uuid, e.creator, e.patient_id, e.visit_id, e.encounter_datetime, e.location_id, e.encounter_id,
        max(if(o.concept_id=160658,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as is_physically_abused,
        max(if(o.concept_id=159449,(case o.value_coded when 5617 THEN "Sexual Partner" when 5618 then "Boy/Girl Friend" when 1067 then "Stranger" when 5622 then "Other" else "" end),null)) as physical_abuse_perpetrator,
        max(if(o.concept_id=165230, o.value_text, "" )) as other_physical_abuse_perpetrator,
        max(if(o.concept_id=160658,(case o.value_coded when 1065 then "Yes" when 158358 then "Yes" when 1066 then "No" else "" end),null)) as in_physically_abusive_relationship,
        max(if(o.concept_id=164352,(case o.value_coded when 5617 THEN "Sexual Partner" when 5618 then "Boy/Girl Friend" when 5620 then "Relative" when 5622 then "Other" else "" end),null)) as in_physically_abusive_relationship_with,
        max(if(o.concept_id=165230, o.value_text, "" )) as other_physically_abusive_relationship_perpetrator,
        max(if(o.concept_id=160658,(case o.value_coded when 1065 then "Yes" when 118688 then "Yes" when 1066 then "No" else "" end),null)) as in_emotionally_abusive_relationship,
        max(if(o.concept_id=164352,(case o.value_coded when 5617 THEN "Sexual Partner" when 5618 then "Boy/Girl Friend" when 5620 then "Relative" when 5622 then "Other" else "" end),null)) as emotional_abuse_perpetrator,
        max(if(o.concept_id=165230, o.value_text, "" )) as other_emotional_abuse_perpetrator,
        max(if(o.concept_id=160658,(case o.value_coded when 1065 then "Yes" when 152370 THEN "Yes" when 1066 then "No" else "" end),null)) as in_sexually_abusive_relationship,
        max(if(o.concept_id=164352,(case o.value_coded when 5617 THEN "Sexual Partner" when 5618 then "Boy/Girl Friend" when 5620 then "Relative" when 5622 then "Other" else "" end),null)) as sexual_abuse_perpetrator,
        max(if(o.concept_id=165230, o.value_text, "" )) as other_sexual_abuse_perpetrator,
        max(if(o.concept_id=160658,(case o.value_coded when 1065 then"Yes" when 1582 THEN "Yes" when 1066 then "No" else "" end),null)) as ever_abused_by_unrelated_person,
        max(if(o.concept_id=164352,(case o.value_coded when 5617 THEN "Sexual Partner" when 5618 then "Boy/Girl Friend" when 5620 then "Relative" when 5622 then "Other" else "" end),null)) as unrelated_perpetrator,
        max(if(o.concept_id=165230, o.value_text, "" )) as other_unrelated_perpetrator,
        max(if(o.concept_id=162871,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" else "" end),null)) as sought_help,
        max(if(o.concept_id=162886,(case o.value_coded when 1589 THEN "Hospital" when 165284 then "Police" when 165037 then "Peer Educator" when 1560 then "Family" when 165294 then "Peers" when 5618 then "Friends"
                                    when 165290 then "Religious Leader" when 165350 then "Dice" when 162690 then "Chief" when 5622 then "Other" else "" end),null)) as help_provider,
        max(if(o.concept_id = 160753, o.value_datetime, "" )) as date_helped,
        max(if(o.concept_id=162875,(case o.value_coded when 1066 then "No action taken"
                                    when 165070 then "Counselling"
                                    when 160570 then "Emergency pills"
                                    when 1356 then "Hiv testing"
                                    when 130719 then "Investigation done"
                                    when 135914 then "Matter presented to court"
                                    when 165228 then "P3 form issued"
                                    when 165171 then "PEP given"
                                    when 165192 then "Perpetrator arrested"
                                    when 127910 then "Post rape care"
                                    when 165203 then "PrEP given"
                                    when 5618 then "Reconciliation"
                                    when 165093 then "Referred back to the family"
                                    when 165274 then "Referred to hospital"
                                    when 165180 then "Statement taken"
                                    when 165200 then "STI Prophylaxis"
                                    when 165184 then "Trauma counselling done"
                                    when 1185 then "Treatment"
                                    when 5622 then "Other"
                                    else "" end),null)) as help_outcome,
        max(if(o.concept_id = 165230, o.value_text, "" )) as other_outcome,
        max(if(o.concept_id=6098,(case o.value_coded
                                  when 162951 then "Did not know where to report"
                                  when 1811 then "Distance"
                                  when 140923 then "Exhaustion/Lack of energy"
                                  when 163473 then "Fear shame"
                                  when 159418 then "Lack of faith in system"
                                  when 162951 then "Lack of knowledge"
                                  when 664 then "Negative attitude of the person reported to"
                                  when 143100 then "Not allowed culturally"
                                  when 165161 then "Perpetrator above the law"
                                  when 163475 then "Self blame"
                                  else "" end),null)) as reason_for_not_reporting,
        max(if(o.concept_id = 165230, o.value_text, "" )) as other_reason_for_not_reporting,
        e.date_created as date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ('94eec122-83a1-11ea-bc55-0242ac130003')
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (160658,159449,165230,160658,164352,162871,162886,160753,162875,6098) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      is_physically_abused=VALUES(is_physically_abused),
      physical_abuse_perpetrator=VALUES(physical_abuse_perpetrator),
      other_physical_abuse_perpetrator=VALUES(other_physical_abuse_perpetrator),
      in_physically_abusive_relationship=VALUES(in_physically_abusive_relationship),
      in_physically_abusive_relationship_with=VALUES(in_physically_abusive_relationship_with),
      other_physically_abusive_relationship_perpetrator=VALUES(other_physically_abusive_relationship_perpetrator),
      in_emotionally_abusive_relationship=VALUES(in_emotionally_abusive_relationship),
      emotional_abuse_perpetrator=VALUES(emotional_abuse_perpetrator),
      other_emotional_abuse_perpetrator=VALUES(other_emotional_abuse_perpetrator),
      in_sexually_abusive_relationship=VALUES(in_sexually_abusive_relationship),
      sexual_abuse_perpetrator=VALUES(sexual_abuse_perpetrator),
      other_sexual_abuse_perpetrator=VALUES(other_sexual_abuse_perpetrator),
      ever_abused_by_unrelated_person=VALUES(ever_abused_by_unrelated_person),
      unrelated_perpetrator=VALUES(unrelated_perpetrator),
      other_unrelated_perpetrator=VALUES(other_unrelated_perpetrator),
      sought_help=VALUES(sought_help),
      help_provider=VALUES(help_provider),
      date_helped=VALUES(date_helped),
      help_outcome=VALUES(help_outcome),
      other_outcome=VALUES(other_outcome),
      reason_for_not_reporting=VALUES(reason_for_not_reporting),
      other_reason_for_not_reporting=VALUES(other_reason_for_not_reporting),
      voided=VALUES(voided);

    END $$

-- ------------- Update kp PrEP verification-------------------------

DROP PROCEDURE IF EXISTS sp_update_etl_PrEP_verification $$
CREATE PROCEDURE sp_update_etl_PrEP_verification(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing kp PrEP verification form", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_PrEP_verification(
      uuid,
      provider,
      client_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      date_enrolled,
      health_facility_accessing_PrEP,
      is_pepfar_site,
      date_initiated_PrEP,
      PrEP_regimen,
      information_source,
      PrEP_status,
      verification_date,
      discontinuation_reason,
      other_discontinuation_reason,
      appointment_date,
      date_created,
      date_last_modified,
      voided
    )
      select
        e.uuid, e.creator as provider, e.patient_id as client_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,
                max(if(o.concept_id = 163526, o.value_datetime, "" )) as date_enrolled,
                max(if(o.concept_id = 162724, o.value_text, "" )) as health_facility_accessing_PrEP,
                max(if(o.concept_id=1768,(case o.value_coded when 1065 THEN "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as is_pepfar_site,
                max(if(o.concept_id = 160555, o.value_datetime, "" )) as date_initiated_PrEP,
                max(if(o.concept_id=164515,(case o.value_coded when 161364 THEN "TDF/3TC" when 84795 then "TDF" when 104567 then "TDF/FTC(Preferred)" else "" end),null)) as PrEP_regimen,
                max(if(o.concept_id = 162568, (case o.value_coded when 163787 then "Verbal report" when 162969 THEN "SMS" when 1662 then "Apointment card"  when 1650 then "Phone call" when 1238 then "Written record" when 160526 then "EID Dashboard" else "" end),null)) as information_source,
                max(if(o.concept_id=165109,(case o.value_coded when 1256 THEN "Start" when 1257 then "Continue" when 162904 then "Restart" when 1260 then "Discontinue" else "" end),null)) as PrEP_status,
                max(if(o.concept_id = 162079, o.value_datetime, "" )) as verification_date,
                max(if(o.concept_id=161555,(case o.value_coded when 138571 THEN "HIV test is positive" when 1302 then "Viral suppression of HIV+ Partner" when
                  159598 then "Not adherent to PrEP" when 164401 then "Too many HIV tests" when 162696 then "Client request" when 5622 then "Other" else "" end),null)) as discontinuation_reason,
                max(if(o.concept_id = 165230, o.value_text, "" )) as other_discontinuation_reason,
                max(if(o.concept_id = 159948, o.value_datetime, "" )) as appointment_date,
                e.date_created as date_created,
                if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ("5c64e61a-7fdc-11ea-bc55-0242ac130003")
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (163526,162724,1768,160555,164515,162568,162079,165109,161555,165230,5096) and o.voided=0
      where e.voided=0 and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id, e.encounter_id
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      date_enrolled=VALUES(date_enrolled),
      health_facility_accessing_PrEP=VALUES(health_facility_accessing_PrEP),
      is_pepfar_site=VALUES(is_pepfar_site),
      date_initiated_PrEP=VALUES(date_initiated_PrEP),
      PrEP_regimen=VALUES(PrEP_regimen),
      information_source=VALUES(information_source),
      PrEP_status=VALUES(PrEP_status),
      verification_date=VALUES(verification_date),
      discontinuation_reason=VALUES(discontinuation_reason),
      other_discontinuation_reason=VALUES(other_discontinuation_reason),
      appointment_date=VALUES(appointment_date),
      voided=VALUES(voided);
    END $$

    DROP PROCEDURE IF EXISTS sp_update_etl_alcohol_drug_abuse_screening $$
    CREATE PROCEDURE sp_update_etl_alcohol_drug_abuse_screening(IN last_update_time DATETIME)
    BEGIN
    SELECT "Processing Alcohol and Drug Abuse Screening(CAGE-AID/CRAFFT)", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_alcohol_drug_abuse_screening(
    patient_id,
    uuid,
    provider,
    visit_id,
    visit_date,
    encounter_id,
    location_id,
    alcohol_drinking_frequency,
    smoking_frequency,
    drugs_use_frequency,
    date_created,
    date_last_modified,
    voided
    )
    select
    e.patient_id, e.uuid, e.creator, e.visit_id, date(e.encounter_datetime) as visit_date, e.encounter_id, e.location_id,
    max(case o.concept_id when 159449 then o.value_coded else null end) as alcohol_drinking_frequency,
    max(case o.concept_id when 163201 then o.value_coded else null end) as smoking_frequency,
    max(case o.concept_id when 112603 then o.value_coded else null end) as drugs_use_frequency,
    e.date_created as date_created,
    if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
    e.voided as voided
    from encounter e
      inner join person p on p.person_id=e.patient_id and p.voided=0
      inner join form f on f.form_id=e.form_id and f.uuid in ('7b1ec2d5-a4ad-4ffc-a0d3-ff1ea68e293c')
    inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (159449, 163201, 112603) and o.voided=0
    where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o.date_created >= last_update_time
                or o.date_voided >= last_update_time
    group by e.encounter_id
    order by e.patient_id
        ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
          provider=VALUES(provider),
          alcohol_drinking_frequency=VALUES(alcohol_drinking_frequency),
          smoking_frequency=VALUES(smoking_frequency),
          drugs_use_frequency=VALUES(drugs_use_frequency),
          voided=VALUES(voided);
    END $$

    DROP PROCEDURE IF EXISTS sp_update_etl_gbv_screening $$
    CREATE PROCEDURE sp_update_etl_gbv_screening(IN last_update_time DATETIME)
    BEGIN
    SELECT "Processing GBV Screening", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_gbv_screening(
        uuid,
        provider,
        patient_id,
        visit_id,
        visit_date,
        location_id,
        encounter_id,
        ipv,
        physical_ipv,
        emotional_ipv,
        sexual_ipv,
        ipv_relationship,
        date_created,
        date_last_modified,
        voided
        )
    select
       e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,
       max(if(o.obs_group = 141814 and o.concept_id = 160658 and (o.value_coded =1065 or o.value_coded =1066),o.value_coded, "" )) as ipv,
       max(if(o.obs_group = 141814 and o.concept_id = 160658 and (o.value_coded =158358 or o.value_coded =1066),o.value_coded, "" )) as physical_ipv,
       max(if(o.obs_group = 141814 and o.concept_id = 160658 and (o.value_coded =118688 or o.value_coded =1066),o.value_coded, "" )) as emotional_ipv,
       max(if(o.obs_group = 141814 and o.concept_id = 160658 and (o.value_coded =152370 or o.value_coded =1066),o.value_coded, "" )) as sexual_ipv,
       max(if(o.obs_group = 141814 and o.concept_id = 160658 and (o.value_coded =1582 or o.value_coded =1066),o.value_coded, "" )) as ipv_relationship,
       e.date_created as date_created,
       if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
       e.voided as voided
    from encounter e
       inner join person p on p.person_id=e.patient_id and p.voided=0
       inner join form f on f.form_id=e.form_id and f.uuid in ('03767614-1384-4ce3-aea9-27e2f4e67d01')
    inner join (select o.encounter_id as encounter_id,o.person_id, o.obs_id,o.concept_id as obs_group,o1.concept_id as concept_id, o1.value_coded as value_coded,o1.date_created as date_created,o1.voided,o1.date_voided as date_voided
            from obs o join obs o1 on o.obs_id = o1.obs_group_id and o1.concept_id =160658 and o.concept_id =141814)o on o.encounter_id = e.encounter_id
            and o.voided=0
    where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o.date_created >= last_update_time
                or o.date_voided >= last_update_time
    group by e.encounter_id
    order by e.patient_id
        ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
          provider=VALUES(provider),
          ipv=VALUES(ipv),
          physical_ipv=VALUES(physical_ipv),
          emotional_ipv=VALUES(emotional_ipv),
          sexual_ipv=VALUES(sexual_ipv),
          ipv_relationship=VALUES(ipv_relationship),
          voided=VALUES(voided);
    END $$

------updating etl_gbv_screening_action table-------
 DROP PROCEDURE IF EXISTS sp_update_etl_gbv_screening_action $$
    CREATE PROCEDURE sp_update_etl_gbv_screening_action(IN last_update_time DATETIME)
    BEGIN
    SELECT "Processing GBV Screening", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_gbv_screening_action(
    uuid,
    provider,
    patient_id,
    visit_id,
    visit_date,
    location_id,
    obs_id,
    help_provider,
    action_taken,
    reason_for_not_reporting,
    date_created,
    date_last_modified,
    voided
    )
select
       e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, o.id as obs_id,
       max(if(o.obs_group = 1562 and o.concept_id = 162886,o.value_coded, NULL)) as help_provider,
       max(if(o.obs_group = 159639 and o.concept_id = 162875,o.value_coded, NULL)) as action_taken,
       max(if(o.obs_group = 1743 and o.concept_id = 6098,o.value_coded,NULL)) as reason_for_not_reporting,
       e.date_created as date_created,
       if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
       e.voided as voided
from encounter e
       inner join person p on p.person_id=e.patient_id and p.voided=0
       inner join form f on f.form_id=e.form_id and f.uuid in ('03767614-1384-4ce3-aea9-27e2f4e67d01','94eec122-83a1-11ea-bc55-0242ac130003')
       inner join (select o.encounter_id as encounter_id,o.person_id, o.obs_id,o1.obs_id as id,o.concept_id as obs_group,o1.concept_id as concept_id, o1.value_coded as value_coded,o1.date_created,o1.voided
                   from obs o join obs o1 on o.obs_id = o1.obs_group_id and o1.concept_id in (162871,162886,162875,6098) and o.concept_id in(1562,159639,1743))o on o.encounter_id = e.encounter_id and o.voided=0
where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o1.date_created >= last_update_time
                or o1.date_voided >= last_update_time
group by o.id
order by e.patient_id
 ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
        provider=VALUES(provider),
        help_provider=VALUES(help_provider),
        action_taken=VALUES(action_taken),
        reason_for_not_reporting=VALUES(reason_for_not_reporting),
        voided=VALUES(voided);
SELECT "Completed processing gbv screening action data ", CONCAT("Time: ", NOW());
END $$

  DROP PROCEDURE IF EXISTS sp_update_etl_depression_screening $$
    CREATE PROCEDURE sp_update_etl_depression_screening(IN last_update_time DATETIME)
    BEGIN
    SELECT "Processing depression Screening", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_depression_screening(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      PHQ_9_rating,
      date_created,
      date_last_modified,
      voided
)
select
       e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,
       max(if(o.concept_id = 165110,o.value_coded,null)) as PHQ_9_rating,
       e.date_created as date_created,
       if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
       e.voided as voided
from encounter e
       inner join person p on p.person_id=e.patient_id and p.voided=0
       inner join form f on f.form_id=e.form_id and f.uuid in ('5fe533ee-0c40-4a1f-a071-dc4d0fbb0c17')
inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (165110) and o.voided=0
where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o.date_created >= last_update_time
                or o.date_voided >= last_update_time
group by e.encounter_id
order by e.patient_id
        ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
        provider=VALUES(provider),
        PHQ_9_rating=VALUES(PHQ_9_rating),
        voided=VALUES(voided);
END $$

-- Update Adverse events
DROP PROCEDURE IF EXISTS sp_update_etl_adverse_events $$
CREATE PROCEDURE sp_update_etl_adverse_events(IN last_update_time DATETIME)
BEGIN
SELECT "Processing adverse events", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_adverse_events(
uuid ,
form,
provider,
patient_id,
visit_id,
visit_date,
location_id,
encounter_id,
obs_id,
cause,
adverse_event,
severity,
start_date,
action_taken,
date_created,
date_last_modified,
voided
)
select
       e.uuid,
      (case f.uuid
       when '22c68f86-bbf0-49ba-b2d1-23fa7ccf0259' then 'greencard'
       when '1bfb09fc-56d7-4108-bd59-b2765fd312b8' then 'prep-initial'
       when 'ee3e2017-52c0-4a54-99ab-ebb542fb8984' then 'prep-consultation'
       when '5ee93f48-960b-11ec-b909-0242ac120002' then 'vmmc-procedure'
       when '08873f91-7161-4f90-931d-65b131f2b12b' then 'vmmc-followup'
       end) as form,
       e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,o1.obs_id,
       max(if(o1.obs_group =121760 and o1.concept_id = 1193,o1.value_coded,null)) as cause,
       max(if(o1.obs_group =121760 and o1.concept_id in (159935,162875),o1.value_coded,null)) as adverse_event,
       max(if(o1.obs_group =121760 and o1.concept_id = 162760,o1.value_coded,null)) as severity,
       max(if(o1.obs_group =121760 and o1.concept_id = 160753,date(o1.value_datetime),null)) as start_date,
       max(if(o1.obs_group =121760 and o1.concept_id = 1255,o1.value_coded,null)) as action_taken,
       e.date_created as date_created,
       if(max(o1.date_created) > min(e.date_created),max(o1.date_created),NULL) as date_last_modified,
       e.voided as voided
from encounter e
       inner join person p on p.person_id=e.patient_id and p.voided=0
       inner join form f on f.form_id=e.form_id and f.retired=0
       inner join (
                    select encounter_type_id, uuid, name from encounter_type where uuid in('a0034eee-1940-4e35-847f-97537a35d05e',
                                                                                                   'c4a2be28-6673-4c36-b886-ea89b0a42116',
                                                                                                   '706a8b12-c4ce-40e4-aec3-258b989bf6d3',
                                                                                                   '35c6fcc2-960b-11ec-b909-0242ac120002',
                                                                                                   '2504e865-638e-4a63-bf08-7e8f03a376f3')
    ) et on et.encounter_type_id=e.encounter_type
                          inner join (select o.person_id,o1.encounter_id, o.obs_id,o.concept_id as obs_group,o1.concept_id as concept_id,o1.value_coded, o1.value_datetime,
                          o1.date_created as date_created, o1.date_voided as date_voided,o1.voided from obs o join obs o1 on o.obs_id = o1.obs_group_id
                          and o1.concept_id in (1193,159935,162875,162760,160753,1255) and o.concept_id = 121760)
                          o1 on o1.encounter_id = e.encounter_id and o1.voided=0
                where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o1.date_created >= last_update_time
                or o1.date_voided >= last_update_time
group by o1.obs_id
order by e.patient_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
        provider=VALUES(provider),
        cause=VALUES(cause),
        adverse_event=VALUES(adverse_event),
        severity=VALUES(severity),
        start_date=VALUES(start_date),
        action_taken=VALUES(action_taken),
        voided=VALUES(voided);

SELECT "Completed processing adverse events data ", CONCAT("Time: ", NOW());
END $$

-- Update Allergy and chronic illness----
DROP PROCEDURE IF EXISTS sp_update_etl_allergy_chronic_illness $$
CREATE PROCEDURE sp_update_etl_allergy_chronic_illness(IN last_update_time DATETIME)
BEGIN
SELECT "Processing allergy and chronic illness", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_allergy_chronic_illness(
uuid ,
provider,
patient_id,
visit_id,
visit_date,
location_id,
encounter_id,
obs_id,
chronic_illness,
chronic_illness_onset_date,
allergy_causative_agent,
allergy_reaction,
allergy_severity,
allergy_onset_date,
date_created,
date_last_modified,
voided
)
select
   e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id, o1.obs_id,
   max(if(o1.obs_group =159392 and o1.concept_id = 1284,o1.value_coded,null)) as chronic_illness,
   max(if(o1.obs_group =159392 and o1.concept_id = 159948,date(o1.value_datetime),null)) as chronic_illness_onset_date,
   max(if(o1.obs_group =121689 and o1.concept_id = 160643,o1.value_coded,null)) as allergy_causative_agent,
   max(if(o1.obs_group =121689 and o1.concept_id = 159935,o1.value_coded,null)) as allergy_reaction,
   max(if(o1.obs_group =121689 and o1.concept_id = 162760,o1.value_coded,null)) as allergy_severity,
   max(if(o1.obs_group =121689 and o1.concept_id = 160753,date(o1.value_datetime),null)) as allergy_onset_date,
   e.date_created as date_created,  if(max(o1.date_created) > min(e.date_created),max(o1.date_created),NULL) as date_last_modified,
   e.voided as voided
from encounter e
   inner join person p on p.person_id=e.patient_id and p.voided=0
   inner join (
              select encounter_type_id, uuid, name from encounter_type where uuid in('a0034eee-1940-4e35-847f-97537a35d05e','c6d09e05-1f25-4164-8860-9f32c5a02df0','c4a2be28-6673-4c36-b886-ea89b0a42116','a2010bf5-2db0-4bf4-819f-8a3cffbcb21b')
              ) et on et.encounter_type_id=e.encounter_type
                          inner join (select o.person_id,o1.encounter_id, o.obs_id,o.concept_id as obs_group,o1.concept_id as concept_id,o1.value_coded, o1.value_datetime,o1.date_voided as date_voided,
                          o1.date_created as date_created,o1.voided from obs o join obs o1 on o.obs_id = o1.obs_group_id
                           and o1.concept_id in (1284,159948,160643,159935,162760,160753)
                          and o.concept_id in (159392,121689)) o1 on o1.encounter_id = e.encounter_id and o1.voided=0
where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o1.date_created >= last_update_time
                or o1.date_voided >= last_update_time
group by o1.obs_id
order by e.patient_id
 ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
        provider=VALUES(provider),
        chronic_illness=VALUES(chronic_illness),
        chronic_illness_onset_date=VALUES(chronic_illness_onset_date),
        allergy_causative_agent=VALUES(allergy_causative_agent),
        allergy_reaction=VALUES(allergy_reaction),
        allergy_severity=VALUES(allergy_severity),
        allergy_onset_date=VALUES(allergy_onset_date),
        voided=VALUES(voided);
SELECT "Completed processing allergy and chronic illness data ", CONCAT("Time: ", NOW());
END $$


-- Update TPT screening----
DROP PROCEDURE IF EXISTS sp_update_etl_ipt_screening $$
CREATE PROCEDURE sp_update_etl_ipt_screening(IN last_update_time DATETIME)
BEGIN
SELECT "Processing TPT screening", CONCAT("Time: ", NOW());

insert into kenyaemr_etl.etl_ipt_screening(
uuid,
provider,
patient_id,
visit_id,
visit_date,
location_id,
encounter_id,
obs_id,
cough,
fever,
weight_loss_poor_gain,
night_sweats,
contact_with_tb_case,
lethargy,
yellow_urine,
numbness_bs_hands_feet,
eyes_yellowness,
upper_rightQ_abdomen_tenderness,
date_created,
date_last_modified,
voided
)
select
       e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id,e.encounter_id,o1.obs_id,
       max(if(o1.obs_group =160108 and o1.concept_id = 1729 and (o1.value_coded = 159799 or o1.value_coded = 1066),o1.value_coded,null)) as cough,
       max(if(o1.obs_group =160108 and o1.concept_id = 1729 and (o1.value_coded = 1494 or o1.value_coded = 1066),o1.value_coded,null)) as fever,
       max(if(o1.obs_group =160108 and o1.concept_id = 1729 and (o1.value_coded = 832 or o1.value_coded = 1066),o1.value_coded,null)) as weight_loss_poor_gain,
       max(if(o1.obs_group =160108 and o1.concept_id = 1729 and (o1.value_coded = 133027 or o1.value_coded = 1066),o1.value_coded,null)) as night_sweats,
       max(if(o1.obs_group =160108 and o1.concept_id = 1729 and (o1.value_coded = 124068 or o1.value_coded = 1066),o1.value_coded,null)) as contact_with_tb_case,
       max(if(o1.obs_group =160108 and o1.concept_id = 1729 and (o1.value_coded = 116334 or o1.value_coded = 1066),o1.value_coded,null)) as lethargy,
       max(if(o1.obs_group =1727 and o1.concept_id = 1729 and (o1.value_coded = 162311 or o1.value_coded = 1066),o1.value_coded,null)) as yellow_urine,
       max(if(o1.obs_group =1727 and o1.concept_id = 1729 and (o1.value_coded = 132652 or o1.value_coded = 1066),o1.value_coded,null)) as numbness_bs_hands_feet,
       max(if(o1.obs_group =1727 and o1.concept_id = 1729 and (o1.value_coded = 5192 or o1.value_coded = 1066),o1.value_coded,null)) as eyes_yellowness,
       max(if(o1.obs_group =1727 and o1.concept_id = 1729 and (o1.value_coded = 124994 or o1.value_coded = 1066),o1.value_coded,null)) as upper_rightQ_abdomen_tenderness,
       e.date_created as date_created,  if(max(o1.date_created) > min(e.date_created),max(o1.date_created),NULL) as date_last_modified,
       e.voided as voided
from encounter e
       inner join person p on p.person_id=e.patient_id and p.voided=0
       inner join (
                  select encounter_type_id, uuid, name from encounter_type where uuid in ('a0034eee-1940-4e35-847f-97537a35d05e', 'ed6dacc9-0827-4c82-86be-53c0d8c449be')
                  ) et on et.encounter_type_id=e.encounter_type
       inner join (select o.person_id,o1.encounter_id, o.obs_id,o.concept_id as obs_group,o1.concept_id as concept_id,o1.value_coded, o1.value_datetime,
                    o1.date_created as date_created,o1.date_voided as date_voided,o1.voided as voided from obs o join obs o1 on o.obs_id = o1.obs_group_id
                    and o1.concept_id =1729
                    and o.concept_id in(160108,1727)) o1 on o1.encounter_id = e.encounter_id and o1.voided=0
where e.voided=0 and e.date_created >= last_update_time
                or e.date_changed >= last_update_time
                or e.date_voided >= last_update_time
                or o1.date_created >= last_update_time
                or o1.date_voided >= last_update_time
group by o1.obs_id
order by e.patient_id
 ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
        cough=VALUES(cough),
        fever=VALUES(fever),
        weight_loss_poor_gain=VALUES(weight_loss_poor_gain),
        night_sweats=VALUES(night_sweats),
        contact_with_tb_case=VALUES(contact_with_tb_case),
        lethargy=VALUES(lethargy),
        yellow_urine=VALUES(yellow_urine),
        numbness_bs_hands_feet=VALUES(numbness_bs_hands_feet),
        eyes_yellowness=VALUES(eyes_yellowness),
        upper_rightQ_abdomen_tenderness=VALUES(upper_rightQ_abdomen_tenderness),
        voided=VALUES(voided);

SELECT "Completed processingIPT screening data ", CONCAT("Time: ", NOW());
END $$

--Populate etl_pre_hiv_enrollment_ART
DROP PROCEDURE IF EXISTS sp_update_etl_pre_hiv_enrollment_art $$
CREATE PROCEDURE sp_update_etl_pre_hiv_enrollment_art(IN last_update_time DATETIME)
BEGIN
SELECT "Processing pre_hiv enrollment ART", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_pre_hiv_enrollment_art(
    uuid,
    provider,
    patient_id,
    visit_id,
    visit_date,
    location_id,
    encounter_id,
    obs_id,
    PMTCT,
    PMTCT_regimen,
    PEP,
    PEP_regimen,
    PrEP,
    PrEP_regimen,
    HAART,
    HAART_regimen,
    date_created,
    date_last_modified,
    voided
    )
select
       e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id,e.encounter_id,o1.obs_id,
       max(if(o1.obs_group =160741 and o1.concept_id = 1148,o1.value_coded,null)) as PMTCT,
       max(if(o1.obs_group =160741 and o1.concept_id = 966,o1.value_coded,null)) as PMTCT_regimen,
       max(if(o1.obs_group =160741 and o1.concept_id = 1691,o1.value_coded,null)) as PEP,
       max(if(o1.obs_group =160741 and o1.concept_id = 1088,o1.value_coded,null)) as PEP_regimen,
       max(if(o1.obs_group =160741 and o1.concept_id = 165269,o1.value_coded,null)) as PrEP,
       max(if(o1.obs_group =160741 and o1.concept_id = 1087,o1.value_coded,null)) as PrEP_regimen,
       max(if(o1.obs_group =1085 and o1.concept_id = 1181,o1.value_coded,null)) as HAART,
       max(if(o1.obs_group =1085 and o1.concept_id = 1088,o1.value_coded,null)) as HAART_regimen,
       e.date_created as date_created,  if(max(o1.date_created) > min(e.date_created),max(o1.date_created),NULL) as date_last_modified,
       e.voided as voided
from encounter e
       inner join person p on p.person_id=e.patient_id and p.voided=0
       inner join (
                  select encounter_type_id, uuid, name from encounter_type where uuid ='de78a6be-bfc5-4634-adc3-5f1a280455cc'
                  ) et on et.encounter_type_id=e.encounter_type
       inner join (select o.person_id,o1.encounter_id, o.obs_id,o.concept_id as obs_group,o1.concept_id as concept_id,o1.value_coded, o1.value_datetime,
                          o1.date_created,o1.date_voided,o1.voided from obs o join obs o1 on o.obs_id = o1.obs_group_id
                                                                                and o1.concept_id in (1148,966,1691,1088,1087,1181,165269) and o1.voided=0
                                                                                and o.concept_id in(160741,1085)) o1 on o1.encounter_id = e.encounter_id
where e.voided=0 and e.date_created >= last_update_time or e.date_changed >= last_update_time or e.date_voided >= last_update_time or o1.date_created >= last_update_time
or o1.date_voided >= last_update_time
group by o1.obs_id order by e.patient_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),provider=VALUES(provider),PMTCT=VALUES(PMTCT),PMTCT_regimen=VALUES(PMTCT_regimen),PEP=VALUES(PEP),PEP_regimen=VALUES(PEP_regimen),
PrEP=VALUES(PrEP),PrEP_regimen=VALUES(PrEP_regimen),HAART=VALUES(HAART),HAART_regimen=VALUES(HAART_regimen),voided=VALUES(voided);
SELECT "Completed processing pre_hiv enrollment ART data ", CONCAT("Time: ", NOW());
END $$

--Update etl_covid_19_assessment
DROP PROCEDURE IF EXISTS sp_update_etl_covid_19_assessment $$
  CREATE PROCEDURE sp_update_etl_covid_19_assessment(IN last_update_time DATETIME)
  BEGIN
  SELECT "Processing covid_19 assessment", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_covid19_assessment (uuid,
                                                 provider,
                                                 patient_id,
                                                 visit_id,
                                                 visit_date,
                                                 location_id,
                                                 encounter_id,
                                                 obs_id,
                                                 ever_vaccinated,
                                                 first_vaccine_type,
                                                 second_vaccine_type,
                                                 first_dose,
                                                 second_dose,
                                                 first_dose_date,
                                                 second_dose_date,
                                                 first_vaccination_verified,
                                                 second_vaccination_verified,
                                                 final_vaccination_status,
                                                 ever_received_booster,
                                                 booster_vaccine_taken,
                                                 date_taken_booster_vaccine,
                                                 booster_sequence,
                                                 booster_dose_verified,
                                                 ever_tested_covid_19_positive,
                                                 symptomatic,
                                                 date_tested_positive,
                                                 hospital_admission,
                                                 admission_unit,
                                                 on_ventillator,
                                                 on_oxygen_supplement,
                                                 date_created,
                                                 date_last_modified,
                                                 voided)
select o3.uuid                                                                             as uuid,
       o3.creator                                                                          as provider,
       o3.person_id                                                                        as patient_id,
       o3.visit_id                                                                         as visit_id,
       o3.visit_date                                                                       as visit_date,
       o3.location_id                                                                      as location_id,
       o3.encounter_id                                                                     as encounter_id,
       o1.obs_group                                                                        as obs_id,
       max(if(o3.concept_id = 163100, o3.value_coded, null))                               as ever_vaccinated,
       max(if(dose = 1 and o1.concept_id = 984 and o1.obs_group = 1421, vaccine_type,
              ""))                                                                         as first_vaccine_type,
       max(if(dose = 2 and o1.concept_id = 984 and o1.obs_group = 1421, vaccine_type,
              ""))                                                                         as second_vaccine_type,
       max(if(dose = 1 and o1.concept_id = 1418 and o1.obs_group = 1421, dose, ""))        as first_dose,
       max(if(dose = 2 and o1.concept_id = 1418 and o1.obs_group = 1421, dose, ""))        as second_dose,
       max(if(y.dose = 1 and o1.concept_id = 1410 and y.obs_group = 1421, date(y.date_given),
              ""))                                                                         as first_dose_date,
       max(if(y.dose = 2 and o1.concept_id = 1410 and y.obs_group = 1421, date(y.date_given),
              ""))                                                                         as second_dose_date,
       max(if(dose = 1 and o1.concept_id = 164464 and o1.obs_group = 1421, verified,
              ""))                                                                         as first_vaccination_verified,
       max(if(dose = 2 and o1.concept_id = 164464 and o1.obs_group = 1421, verified,
              ""))                                                                         as second_vaccination_verified,
       max(if(o3.concept_id = 164134, o3.value_coded, null))                               as final_vaccination_status,
       max(if(o3.concept_id = 166063, o3.value_coded, null))                               as ever_received_booster,
       max(if(o1.concept_id = 984 and o1.obs_group = 1184, o1.value_coded, ""))            as booster_vaccine_taken,
       max(
         if(o1.concept_id = 1410 and o1.obs_group = 1184, date(o1.value_datetime),
            ""))                                                                           as date_taken_booster_vaccine,
       max(if(o1.concept_id = 1418 and o1.obs_group = 1184, o1.value_numeric, ""))         as booster_sequence,
       max(
         if(o1.concept_id = 164464 and o1.obs_group = 1184, o1.value_coded, ""))           as booster_dose_verified,
       max(if(o3.concept_id = 166638, o3.value_coded, null))                               as ever_tested_covid_19_positive,
       max(if(o3.concept_id = 159640, o3.value_coded, null))                               as symptomatic,
       max(if(o3.concept_id = 159948, date(o3.value_datetime), null))                      as date_tested_positive,
       max(if(o3.concept_id = 162477, o3.value_coded, null))                               as hospital_admission,
       concat_ws(',', max(if(o3.concept_id = 161010 and o3.value_coded = 165994, 'Isolation', null)),
                 max(if(o3.concept_id = 161010 and o3.value_coded = 165995, 'HDU', null)),
                 max(if(o3.concept_id = 161010 and o3.value_coded = 161936, 'ICU', null))) as admission_unit,
       max(if(o3.concept_id = 165932, o3.value_coded, null))                               as on_ventillator,
       max(if(o3.concept_id = 165864, o3.value_coded, null))                               as on_oxygen_supplement,
       o3.date_created                                                                     as date_created,
       o3.date_last_modified                                                               as date_last_modified,
       o3.enc_voided                                                                           as voided
from (select e.uuid,
             e.creator,
             o.person_id,
             o.encounter_id,
             date(e.encounter_datetime) as visit_date,
             e.visit_id,
             e.location_id,
             o.obs_id,
             o.concept_id               as obs_group,
             o.concept_id               as concept_id,
             o.value_coded,
             o.value_datetime,
             o.value_numeric,
             o.date_created,
             if(max(o.date_created) > min(e.date_created), max(o.date_created),
                NULL)                   as date_last_modified,
             o.voided,
             o.date_voided,
             e.date_voided as enc_voided,
             e.date_voided as enc_voided_date,
             e.date_changed as enc_changed_date,
             e.date_created as enc_created_date
      from obs o
             inner join encounter e on e.encounter_id = o.encounter_id
             inner join person p on p.person_id = o.person_id and p.voided = 0
             inner join (select encounter_type_id, uuid, name
                         from encounter_type
                         where uuid = '86709cfc-1490-11ec-82a8-0242ac130003') et
               on et.encounter_type_id = e.encounter_type
      where o.concept_id in
            (163100, 984, 1418, 1410, 164464, 164134, 166063, 166638, 159948, 162477, 161010, 165864, 165932, 159640)
        and o.voided = 0
      group by o.obs_id)o3
       left join (select person_id                                       as patient_id,
                         date(encounter_datetime)                        as visit_date,
                         creator,
                         obs_id,
                         date(t.date_created)                            as date_created,
                         t.date_last_modified                            as date_last_modified,
                         encounter_id,
                         name                                            as encounter_type,
                         t.uuid,
                         max(if(t.concept_id = 984, t.value_coded, ""))  as vaccine_type,
                         max(if(t.concept_id = 1418, value_numeric, "")) as dose,
                         max(if(t.concept_id = 164464, value_coded, "")) as verified,
                         max(if(t.concept_id = 1410, date_given, ""))    as date_given,
                         t.concept_id                                    as concept_id,
                         t.obs_group                                     as obs_group,
                         obs_group_id,
                         t.visit_id,
                         t.location_id,
                         t.voided
                  from (select e.uuid,
                               o2.person_id,
                               o2.obs_id,
                               o.concept_id as         obs_group,
                               e.encounter_datetime,
                               e.creator,
                               e.date_created,
                               if(max(o2.date_created) != min(o2.date_created), max(o2.date_created),
                                  NULL)     as         date_last_modified,
                               o2.voided    as         voided,
                               o2.concept_id,
                               o2.value_coded,
                               o2.value_numeric,
                               date(o2.value_datetime) date_given,
                               o2.obs_group_id,
                               o2.encounter_id,
                               et.name,
                               e.visit_id,
                               e.location_id
                        from obs o
                               inner join encounter e on e.encounter_id = o.encounter_id
                               inner join person p on p.person_id = o.person_id and p.voided = 0
                               inner join (select encounter_type_id, uuid, name
                                           from encounter_type
                                           where uuid = '86709cfc-1490-11ec-82a8-0242ac130003') et
                                 on et.encounter_type_id = e.encounter_type
                               inner join obs o2 on o.obs_id = o2.obs_group_id
                        where o2.concept_id in (984, 1418, 1410, 164464)
                          and o2.voided = 0
                        group by o2.obs_id) t
                  group by obs_group_id
                  having vaccine_type != "") y on o3.encounter_id = y.encounter_id
       left join (select o.person_id,
                         o1.encounter_id,
                         o.obs_id,
                         o.concept_id  as obs_group,
                         o1.concept_id as concept_id,
                         o1.value_coded,
                         o1.value_datetime,
                         o1.value_numeric,
                         o1.date_created,
                         o1.voided
                  from obs o
                         inner join person p on p.person_id = o.person_id and p.voided = 0
                         join obs o1 on o.obs_id = o1.obs_group_id
                                          and o1.concept_id in
                                              (163100, 984, 1418, 1410, 164464, 164134, 166063, 166638, 159948, 162477, 161010, 165864, 165932) and
                                        o1.voided = 0
                                          and o.concept_id in (1421, 1184)
                  order by o1.obs_id) o1 on o1.encounter_id = y.encounter_id

where o3.enc_voided = 0 and o3.enc_created_date >= last_update_time
or o3.enc_changed_date >=  last_update_time
or o3.enc_voided_date >=  last_update_time
or o3.date_created >=  last_update_time
or o3.date_voided >=  last_update_time
group by o3.visit_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),provider=VALUES(provider),ever_vaccinated=VALUES(ever_vaccinated),first_vaccine_type=VALUES(first_vaccine_type),second_vaccine_type=VALUES(second_vaccine_type),
                        first_dose=VALUES(first_dose),second_dose=VALUES(second_dose),first_dose_date=VALUES(first_dose_date),second_dose_date=VALUES(second_dose_date),first_vaccination_verified=VALUES(first_vaccination_verified),
                        second_vaccination_verified=VALUES(second_vaccination_verified),final_vaccination_status=VALUES(final_vaccination_status),ever_received_booster=VALUES(ever_received_booster),
                        booster_vaccine_taken=VALUES(booster_vaccine_taken),date_taken_booster_vaccine=VALUES(date_taken_booster_vaccine),booster_sequence=VALUES(booster_sequence),booster_dose_verified=VALUES(booster_dose_verified),
                        ever_tested_covid_19_positive=VALUES(ever_tested_covid_19_positive),symptomatic=VALUES(symptomatic),
                        date_tested_positive=VALUES(date_tested_positive),hospital_admission=VALUES(hospital_admission),admission_unit=VALUES(admission_unit),
                        on_ventillator=VALUES(on_ventillator),on_oxygen_supplement=VALUES(on_oxygen_supplement),voided=VALUES(voided);
SELECT "Completed processing covid assessment data", CONCAT("Time: ", NOW());
END $$

-- Update VMMC enrolment ----
DROP PROCEDURE IF EXISTS sp_update_etl_vmmc_enrolment $$
CREATE PROCEDURE sp_update_etl_vmmc_enrolment(IN last_update_time DATETIME)
BEGIN
SELECT "Processing VMMC enrolment", CONCAT("Time: ", NOW());

insert into kenyaemr_etl.etl_vmmc_enrolment(
    uuid,
    provider,
    patient_id,
    visit_id,
    visit_date,
    location_id,
    encounter_id,
    referee,
    other_referee,
    source_of_vmmc_info,
    other_source_of_vmmc_info,
    county_of_origin,
    date_created,
    date_last_modified,
    voided
)
select
    e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,
  max(if(o.concept_id = 160482,o.value_coded,null)) as referee,
  max(if(o.concept_id = 165143,o.value_text,null)) as other_referee,
  max(if(o.concept_id = 167094,o.value_coded,null)) as source_of_vmmc_info,
  max(if(o.concept_id = 160632,o.value_text,null)) as other_source_of_vmmc_info,
  max(if(o.concept_id = 167131,o.value_text,null)) as county_of_origin,
    e.date_created as date_created,
    if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
    e.voided as voided
from encounter e
    inner join person p on p.person_id=e.patient_id and p.voided=0
    inner join form f on f.form_id=e.form_id and f.uuid in ('a74e3e4a-9e2a-41fb-8e64-4ba8a71ff984')
    inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (160482,165143,167094,160632,167131) and o.voided=0
where e.voided=0 and e.date_created >= last_update_time
   or e.date_changed >= last_update_time
   or e.date_voided >= last_update_time
   or o.date_created >= last_update_time
   or o.date_voided >= last_update_time
group by e.patient_id,date(e.encounter_datetime)
order by e.patient_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
    provider=VALUES(provider),
    referee=VALUES(referee),
    other_referee=VALUES(other_referee),
    source_of_vmmc_info=VALUES(source_of_vmmc_info),
    other_source_of_vmmc_info=VALUES(other_source_of_vmmc_info),
    county_of_origin=VALUES(county_of_origin),
    date_created=VALUES(date_created),
    date_last_modified=VALUES(date_last_modified),
    voided=VALUES(voided);

SELECT "Completed processing VMMC enrolment data ", CONCAT("Time: ", NOW());
END $$

-- Update VMMC circumcision procedure ----
DROP PROCEDURE IF EXISTS sp_update_etl_vmmc_circumcision_procedure $$
CREATE PROCEDURE sp_update_etl_vmmc_circumcision_procedure(IN last_update_time DATETIME)
BEGIN
SELECT "Processing VMMC circumcision procedure", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_vmmc_circumcision_procedure(
    uuid,
    provider,
    patient_id,
    visit_id,
    visit_date,
    location_id,
    encounter_id,
    circumcision_method,
    surgical_circumcision_method,
    reason_circumcision_ineligible,
    circumcision_device,
    specific_other_device,
    device_size,
    lot_number,
    anaesthesia_used,
    anaesthesia_concentration,
    anaesthesia_volume,
    time_of_first_placement_cut,
    time_of_last_device_closure,
    has_adverse_event,
    adverse_event,
    severity,
    adverse_event_management,
    clinician_name,
    clinician_cadre,
    assist_clinician_name,
    assist_clinician_cadre,
    theatre_number,
    date_created,
    date_last_modified,
    voided
)
select
    e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,
  max(if(o.concept_id = 167118,o.value_coded,null)) as circumcision_method,
  max(if(o.concept_id = 167119,o.value_coded,null)) as surgical_circumcision_method,
  max(if(o.concept_id = 163042,o.value_text,null)) as reason_circumcision_ineligible,
  max(if(o.concept_id = 167120,o.value_coded,null)) as circumcision_device,
  max(if(o.concept_id = 163042,o.value_text,null)) as specific_other_device,
  max(if(o.concept_id = 163049,o.value_text,null)) as device_size,
  max(if(o.concept_id = 164964,o.value_text,null)) as lot_number,
  max(if(o.concept_id = 164254,o.value_coded,null)) as anaesthesia_used,
  max(if(o.concept_id = 160047,o.value_numeric,null)) as anaesthesia_concentration,
  max(if(o.concept_id = 166650,o.value_numeric,null)) as anaesthesia_volume,
  max(if(o.concept_id = 160715,o.value_datetime,null)) as time_of_first_placement_cut,
  max(if(o.concept_id = 167132,o.value_datetime,null)) as time_of_last_device_closure,
  max(if(o.concept_id = 162871,o.value_coded,null)) as has_adverse_event,
  concat_ws(',', max(if(o.concept_id = 162875 and o.value_coded = 147241, 'Bleeding', null)),
            max(if(o.concept_id = 162875 and o.value_coded = 135693, 'Anaesthetic Reaction', null)),
            max(if(o.concept_id = 162875 and o.value_coded = 167126, 'Excessive skin removed', null)),
            max(if(o.concept_id = 162875 and o.value_coded = 156911, 'Damage to the penis', null)),
            max(if(o.concept_id = 162875 and o.value_coded = 114403, 'Pain', null)))  as adverse_event,
  concat_ws(',', max(if(o.concept_id = 162760 and o.value_coded = 1500, 'Severe', null)),
            max(if(o.concept_id = 162760 and o.value_coded = 1499, 'Moderate', null)),
            max(if(o.concept_id = 162760 and o.value_coded = 1498, 'Mild', null))) as severity,
  max(if(o.concept_id = 162749,o.value_text,null)) as adverse_event_management,
  max(if(o.concept_id = 1473,o.value_text,null)) as clinician_name,
  max(if(o.concept_id = 163556,o.value_coded,null)) as clinician_cadre,
  max(if(o.concept_id = 164141,o.value_text,null)) as assist_clinician_name,
  max(if(o.concept_id = 166014,o.value_coded,null)) as assist_clinician_cadre,
  max(if(o.concept_id = 167133,o.value_text,null)) as theatre_number,
    e.date_created as date_created,
    if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
    e.voided as voided
from encounter e
    inner join person p on p.person_id=e.patient_id and p.voided=0
    inner join form f on f.form_id=e.form_id and f.uuid in ('5ee93f48-960b-11ec-b909-0242ac120002')
    inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (167118,167119,163042,167120,163042,163049,164254,160047,166650,160715,163138,167132,162871,162875,162760,162749,1473,163556,164141,166014,167133) and o.voided=0
where e.voided=0
and e.date_created >= last_update_time
   or e.date_changed >= last_update_time
   or e.date_voided >= last_update_time
   or o.date_created >= last_update_time
   or o.date_voided >= last_update_time
group by e.patient_id,date(e.encounter_datetime)
order by e.patient_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
    provider=VALUES(provider),
    circumcision_method=VALUES(circumcision_method),
    surgical_circumcision_method=VALUES(surgical_circumcision_method),
     reason_circumcision_ineligible=VALUES(reason_circumcision_ineligible),
     circumcision_device=VALUES(circumcision_device),
     specific_other_device=VALUES(specific_other_device),
     device_size=VALUES(device_size),
     lot_number=VALUES(lot_number),
     anaesthesia_used=VALUES(anaesthesia_used),
     anaesthesia_concentration=VALUES(anaesthesia_concentration),
     anaesthesia_volume=VALUES(anaesthesia_volume),
     time_of_first_placement_cut=VALUES(time_of_first_placement_cut),
     time_of_last_device_closure=VALUES(time_of_last_device_closure),
     has_adverse_event=VALUES(has_adverse_event),
     adverse_event=VALUES(adverse_event),
     severity=VALUES(severity),
     adverse_event_management=VALUES(adverse_event_management),
     clinician_name=VALUES(clinician_name),
     clinician_cadre=VALUES(clinician_cadre),
     assist_clinician_name=VALUES(assist_clinician_name),
     assist_clinician_cadre=VALUES(assist_clinician_cadre),
     theatre_number=VALUES(theatre_number),
     date_created=VALUES(date_created),
     date_last_modified=VALUES(date_last_modified),
     voided=VALUES(voided);

SELECT "Completed processing VMMC circumcision procedure data ", CONCAT("Time: ", NOW());
END $$

-- Update VMMC client followup  ----
DROP PROCEDURE IF EXISTS sp_update_etl_vmmc_client_followup $$
CREATE PROCEDURE sp_update_etl_vmmc_client_followup(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing VMMC client followup", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_vmmc_client_followup(
      uuid,
      provider,
      patient_id,
      visit_id,
      visit_date,
      location_id,
      encounter_id,
      visit_type,
      has_adverse_event,
      adverse_event,
      severity,
      adverse_event_management,
      medications_given,
      other_medications_given,
      clinician_name,
      clinician_cadre,
      clinician_notes,
      date_created,
      date_last_modified,
      voided
    )
      select
        e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,
                                                  max(if(o.concept_id = 164181,o.value_coded,null)) as visit_type,
                                                  max(if(o.concept_id = 162871,o.value_coded,null)) as has_adverse_event,
                                                  concat_ws(',', max(if(o.concept_id = 162875 and o.value_coded = 114403, 'Pain', null)),
                                                            max(if(o.concept_id = 162875 and o.value_coded = 147241, 'Bleeding', null)),
                                                            max(if(o.concept_id = 162875 and o.value_coded = 152045, 'Problems with appearance', null)),
                                                            max(if(o.concept_id = 162875 and o.value_coded = 156567, 'Hematoma', null)),
                                                            max(if(o.concept_id = 162875 and o.value_coded = 139510, 'Infection', null)),
                                                            max(if(o.concept_id = 162875 and o.value_coded = 118771, 'Difficulty urinating', null)),
                                                            max(if(o.concept_id = 162875 and o.value_coded = 163799, 'Wound disruption', null)))  as adverse_event,
                                                  concat_ws(',', max(if(o.concept_id = 162760 and o.value_coded = 1500, 'Severe', null)),
                                                            max(if(o.concept_id = 162760 and o.value_coded = 1499, 'Moderate', null)),
                                                            max(if(o.concept_id = 162760 and o.value_coded = 1498, 'Mild', null))) as severity,
                                                  max(if(o.concept_id = 162749,o.value_text,null)) as adverse_event_management,
                                                  concat_ws(',', max(if(o.concept_id = 159369 and o.value_coded = 1107, 'None', null)),
                                                            max(if(o.concept_id = 159369 and o.value_coded = 103294, 'Analgesic', null)),
                                                            max(if(o.concept_id = 159369 and o.value_coded = 1195, 'Antibiotics', null)),
                                                            max(if(o.concept_id = 159369 and o.value_coded = 84879, 'TTCV', null)),
                                                            max(if(o.concept_id = 159369 and o.value_coded = 5622, 'Other', null)))  as medications_given,
                                                  max(if(o.concept_id = 161011,o.value_text,null)) as other_medications_given,
                                                  max(if(o.concept_id = 1473,o.value_text,null)) as clinician_name,
                                                  max(if(o.concept_id = 1542,o.value_coded,null)) as clinician_cadre,
                                                  max(if(o.concept_id = 160632,o.value_text,null)) as clinician_notes,
                                                  e.date_created as date_created,
                                                  if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
                                                  e.voided as voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id=e.form_id and f.uuid in ('08873f91-7161-4f90-931d-65b131f2b12b')
        inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (164181,162871,162875,162760,162749,159369,161011,1473,1542,160632) and o.voided=0
      where e.voided=0
            and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
            or o.date_created >= last_update_time
            or o.date_voided >= last_update_time
      group by e.patient_id,date(e.encounter_datetime)
      order by e.patient_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
      provider=VALUES(provider),
      visit_type=VALUES(visit_type),
      has_adverse_event=VALUES(has_adverse_event),
      adverse_event=VALUES(adverse_event),
      severity=VALUES(severity),
      adverse_event_management=VALUES(adverse_event_management),
      medications_given=VALUES(medications_given),
      other_medications_given=VALUES(other_medications_given),
      clinician_name=VALUES(clinician_name),
      clinician_cadre=VALUES(clinician_cadre),
      clinician_notes=VALUES(clinician_notes),
      date_created=VALUES(date_created),
      date_last_modified=VALUES(date_last_modified),
      voided=VALUES(voided);

    SELECT "Completed processing VMMC client followup data ", CONCAT("Time: ", NOW());
  END $$

-- Update VMMC medical history examination ----

DROP PROCEDURE IF EXISTS sp_update_etl_vmmc_medical_history $$
CREATE PROCEDURE sp_update_etl_vmmc_medical_history(IN last_update_time DATETIME)
BEGIN
    SELECT "Processing VMMC medical history examination", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_vmmc_medical_history(
        uuid,
        provider,
        patient_id,
        visit_id,
        visit_date,
        location_id,
        encounter_id,
        assent_given,
        consent_given,
        hiv_status,
        hiv_test_date,
        art_start_date,
        current_regimen,
        ccc_number,
        next_appointment_date,
        hiv_care_facility,
        hiv_care_facility_name,
        vl,
        cd4_count,
        bleeding_disorder,
        diabetes,
        client_presenting_complaints,
        other_complaints,
        ongoing_treatment,
        other_ongoing_treatment,
        hb_level,
        sugar_level,
        has_known_allergies,
        ever_had_surgical_operation,
        specific_surgical_operation,
        proven_tetanus_booster,
        ever_received_tetanus_booster,
        date_received_tetanus_booster,
        blood_pressure,
        pulse_rate,
        temperature,
        in_good_health,
        counselled,
        reason_ineligible,
        circumcision_method_chosen,
        conventional_method_chosen,
        device_name,
        device_size,
        other_conventional_method_device_chosen,
        services_referral,
        date_created,
        date_last_modified,
        voided
    )
    select
        e.uuid,e.creator,e.patient_id,e.visit_id, date(e.encounter_datetime) as visit_date, e.location_id, e.encounter_id,
      max(if(o.concept_id = 167093,o.value_coded,null)) as assent_given,
      max(if(o.concept_id = 1710,o.value_coded,null)) as consent_given,
      max(if(o.concept_id = 159427,o.value_coded,null)) as hiv_status,
      max(if(o.concept_id = 160554,o.value_datetime,null)) as hiv_test_date,
      max(if(o.concept_id = 159599,o.value_datetime,null)) as art_start_date,
      max(if(o.concept_id = 164855,o.value_coded,null)) as current_regimen,
      max(if(o.concept_id = 162053,o.value_text,null)) as ccc_number,
      max(if(o.concept_id = 5096,o.value_datetime,null)) as next_appointment_date,
      max(if(o.concept_id = 165239,o.value_coded,null)) as hiv_care_facility,
      max(if(o.concept_id = 161550,o.value_text,null)) as hiv_care_facility_name,
      max(if(o.concept_id = 856,o.value_coded,null)) as vl,
      max(if(o.concept_id = 5497,o.value_numeric,null)) as cd4_count,
      max(if(o.concept_id = 1628 and o.value_coded = 147241,o.value_coded,null)) as bleeding_disorder,
      max(if(o.concept_id = 1628 and o.value_coded = 119481,o.value_coded,null)) as diabetes,
      concat_ws(',', max(if(o.concept_id = 1728 and o.value_coded = 123529, 'Urethral Discharge', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 118990, 'Genital Sore', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 163606, 'Pain on Urination', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 125203, 'Swelling of the scrotum', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 163831, 'Difficulty in retracting foreskin', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 130845, 'Difficulty in returning foreskin to normal', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 116123, 'Concerns about erection/sexual function', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 163813, 'Epispadia', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 138010, 'Hypospadia', null)),
                max(if(o.concept_id = 1728 and o.value_coded = 5622, 'Other', null))) as client_presenting_complaints,
      max(if(o.concept_id = 163047,o.value_text,null)) as other_complaints,
      concat_ws(',', max(if(o.concept_id = 1794 and o.value_coded = 121629, 'Anaemia', null)),
                max(if(o.concept_id = 1794 and o.value_coded = 142484, 'Diabetes', null)),
                max(if(o.concept_id = 1794 and o.value_coded = 138571, 'HIV/AIDS', null)),
                max(if(o.concept_id = 1794 and o.value_coded = 5622, 'Other', null))) as ongoing_treatment,
      max(if(o.concept_id = 163104,o.value_text,null)) as other_ongoing_treatment,
      max(if(o.concept_id = 21,o.value_numeric,null)) as hb_level,
      max(if(o.concept_id = 887,o.value_numeric,null)) as sugar_level,
      max(if(o.concept_id = 160557,o.value_coded,null)) as has_known_allergies,
      max(if(o.concept_id = 164896,o.value_coded,null)) as ever_had_surgical_operation,
      max(if(o.concept_id = 163393,o.value_text,null)) as specific_surgical_operation,
      max(if(o.concept_id = 54,o.value_coded,null)) as proven_tetanus_booster,
      max(if(o.concept_id = 161536,o.value_coded,null)) as ever_received_tetanus_booster,
      max(if(o.concept_id = 1410,o.value_datetime,null)) as date_received_tetanus_booster,
      concat_ws('/',max(if(o.concept_id = 5085,o.value_numeric,null)),
                max(if(o.concept_id = 5086,o.value_numeric,null))) as blood_pressure,
      max(if(o.concept_id = 5242,o.value_numeric,null)) as pulse_rate,
      max(if(o.concept_id = 5088,o.value_numeric,null)) as temperature,
      max(if(o.concept_id = 1855,o.value_coded,null)) as in_good_health,
      max(if(o.concept_id = 165070,o.value_coded,null)) as counselled,
      max(if(o.concept_id = 162169,o.value_text,null)) as reason_ineligible,
      max(if(o.concept_id = 167118,o.value_coded,null)) as circumcision_method_chosen,
      max(if(o.concept_id = 167119,o.value_coded,null)) as conventional_method_chosen,
      max(if(o.concept_id = 167120,o.value_coded,null)) as device_name,
      max(if(o.concept_id = 163049,o.value_text,null)) as device_size,
      max(if(o.concept_id = 163042,o.value_text,null)) as other_conventional_method_device_chosen,
      concat_ws(',',max(if(o.concept_id = 1272 and o.value_coded = 167125,'STI Treatment',null)),
                max(if(o.concept_id = 1272 and o.value_coded = 166536,'PrEP Services',null)),
                max(if(o.concept_id = 1272 and o.value_coded = 190,'Condom dispensing',null))) as services_referral,
      e.date_created as date_created,
      if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
      e.voided as voided
    from encounter e
             inner join person p on p.person_id=e.patient_id and p.voided=0
             inner join form f on f.form_id=e.form_id and f.uuid in ('d42aeb3d-d5d2-4338-a154-f75ddac78b59')
             inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (167093,1710,159427,160554,164855,159599,162053,5096,165239,161550,856,
                                                                                      5497,1628,1728,163047,1794,163104,21,887,160557,164896,163393,54,161536,
                                                                                      1410,5085,5086,5242,5088,1855,165070,162169,167118,167119,167120,163049,163042,1272) and o.voided=0
    where e.voided=0
        and e.date_created >= last_update_time
       or e.date_changed >= last_update_time
       or e.date_voided >= last_update_time
       or o.date_created >= last_update_time
       or o.date_voided >= last_update_time
    group by e.patient_id,date(e.encounter_datetime)
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
                            provider=VALUES(provider),
                            assent_given=VALUES(assent_given),
                            consent_given=VALUES(consent_given),
                            hiv_status=VALUES(hiv_status),
                            hiv_test_date=VALUES(hiv_test_date),
                            art_start_date=VALUES(art_start_date),
                            current_regimen=VALUES(current_regimen),
                            ccc_number=VALUES(ccc_number),
                            next_appointment_date=VALUES(next_appointment_date),
                            hiv_care_facility=VALUES(hiv_care_facility),
                            hiv_care_facility_name=VALUES(hiv_care_facility_name),
                            vl=VALUES(vl),
                            cd4_count=VALUES(cd4_count),
                            bleeding_disorder=VALUES(bleeding_disorder),
                            diabetes=VALUES(diabetes),
                            client_presenting_complaints=VALUES(client_presenting_complaints),
                            other_complaints=VALUES(other_complaints),
                            ongoing_treatment=VALUES(ongoing_treatment),
                            other_ongoing_treatment=VALUES(other_ongoing_treatment),
                            hb_level=VALUES(hb_level),
                            sugar_level=VALUES(sugar_level),
                            has_known_allergies=VALUES(has_known_allergies),
                            ever_had_surgical_operation=VALUES(ever_had_surgical_operation),
                            specific_surgical_operation=VALUES(specific_surgical_operation),
                            proven_tetanus_booster=VALUES(proven_tetanus_booster),
                            ever_received_tetanus_booster=VALUES(ever_received_tetanus_booster),
                            date_received_tetanus_booster=VALUES(date_received_tetanus_booster),
                            blood_pressure=VALUES(blood_pressure),
                            pulse_rate=VALUES(pulse_rate),
                            temperature=VALUES(temperature),
                            in_good_health=VALUES(in_good_health),
                            counselled=VALUES(counselled),
                            reason_ineligible=VALUES(reason_ineligible),
                            circumcision_method_chosen=VALUES(circumcision_method_chosen),
                            conventional_method_chosen=VALUES(conventional_method_chosen),
                            device_name=VALUES(device_name),
                            device_size=VALUES(device_size),
                            other_conventional_method_device_chosen=VALUES(other_conventional_method_device_chosen),
                            services_referral=VALUES(services_referral),
                            date_created=VALUES(date_created),
                            date_last_modified=VALUES(date_last_modified),
                            voided =VALUES(voided);

    SELECT "Completed processing VMMC medical examination data ", CONCAT("Time: ", NOW());
END $$

-- Update VMMC post operation assessment ----

DROP PROCEDURE IF EXISTS sp_update_etl_vmmc_post_operation_assessment $$
CREATE PROCEDURE sp_update_etl_vmmc_post_operation_assessment(IN last_update_time DATETIME)
BEGIN
SELECT "Processing post vmmc operation assessment", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_vmmc_post_operation_assessment(uuid,
            provider,
            patient_id,
            visit_id,
            visit_date,
            location_id,
            encounter_id,
            blood_pressure,
            pulse_rate,
            temperature,
            penis_elevated,
            given_post_procedure_instruction,
            post_procedure_instructions,
            given_post_operation_medication,
            medication_given,
            other_medication_given,
            removal_date,
            next_appointment_date,
            discharged_by,
            cadre,
            date_created,
            date_last_modified,
            voided)
    select e.uuid,
           e.creator,
           e.patient_id,
           e.visit_id,
           date(e.encounter_datetime) as visit_date,
           e.location_id,
           e.encounter_id,
           concat_ws('/', max(if(o.concept_id = 5085, o.value_numeric, null)),
                     max(if(o.concept_id = 5086, o.value_numeric, null)))                    as blood_pressure,
           max(if(o.concept_id = 5087, o.value_numeric, null))                               as pulse_rate,
           max(if(o.concept_id = 5088, o.value_numeric, null))                               as temperature,
           max(if(o.concept_id = 162871, o.value_coded, null))                               as penis_elevated,
           max(if(o.concept_id = 166639, o.value_coded, null))                               as given_post_procedure_instruction,
           max(if(o.concept_id = 160632, o.value_text, null))                                as post_procedure_instructions,
           max(if(o.concept_id = 159369 and o.value_coded=1107,o.value_coded, null))     as given_post_operation_medication,
           concat_ws(',', max(if(o.concept_id = 159369 and o.value_coded = 103294, 'Analgesic', null)),
                     max(if(o.concept_id = 159369 and o.value_coded = 1195, 'Antibiotics', null)),
                     max(if(o.concept_id = 159369 and o.value_coded = 84879, 'TTCV', null)),
                     max(if(o.concept_id = 159369 and o.value_coded = 5622, 'Other', null))) as medication_given,
           max(if(o.concept_id = 161011, o.value_text, null)) as other_medication_given,
           max(if(o.concept_id = 160753, o.value_datetime, null))                            as removal_date,
           max(if(o.concept_id = 5096, o.value_datetime, null))                              as next_appointment_date,
           max(if(o.concept_id = 1473, o.value_text, null))                                  as discharged_by,
           max(if(o.concept_id = 1542, o.value_coded, null))                                 as cadre,
           e.date_created                                                                    as date_created,
           if(max(o.date_created) > min(e.date_created), max(o.date_created),NULL) as date_last_modified,
           e.voided                                                                          as voided
    from encounter e
             inner join person p on p.person_id = e.patient_id and p.voided = 0
             inner join form f
                        on f.form_id = e.form_id and f.uuid in ('620b3404-9ae5-11ec-b909-0242ac120002')
             inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in
                                                                     (5085, 5086, 5087, 5088, 162871,
                                                                      160632, 159369, 161011, 160753, 5096,
                                                                      1473, 1542) and o.voided = 0
    where e.voided = 0
        and e.date_created >= last_update_time
       or e.date_changed >= last_update_time
       or e.date_voided >= last_update_time
       or o.date_created >= last_update_time
       or o.date_voided >= last_update_time
    group by e.patient_id,date(e.encounter_datetime)
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
                            provider=VALUES(provider),
                            blood_pressure=VALUES(blood_pressure),
                            pulse_rate=VALUES(pulse_rate),
                            temperature=VALUES(temperature),
                            penis_elevated=VALUES(penis_elevated),
                            given_post_procedure_instruction=VALUES(given_post_procedure_instruction),
                            post_procedure_instructions=VALUES(post_procedure_instructions),
                            given_post_operation_medication=VALUES(given_post_operation_medication),
                            medication_given=VALUES(medication_given),
                            other_medication_given=VALUES(other_medication_given),
                            removal_date=VALUES(removal_date),
                            next_appointment_date=VALUES(next_appointment_date),
                            discharged_by=VALUES(discharged_by),
                            cadre=VALUES(cadre),
                            date_created=VALUES(date_created),
                            date_last_modified=VALUES(date_last_modified),
                            voided =VALUES(voided);

    SELECT "Completed processing VMMC post operation assessment data ", CONCAT("Time: ", NOW());
END $$

-- Update HTS Eligibility screening  ----
DROP PROCEDURE IF EXISTS sp_update_etl_hts_eligibility_screening $$
CREATE PROCEDURE sp_update_etl_hts_eligibility_screening(IN last_update_time DATETIME)
  BEGIN
    SELECT "Processing hts screening", CONCAT("Time: ", NOW());
INSERT INTO kenyaemr_etl.etl_hts_eligibility_screening (
    patient_id,
    visit_id,
    encounter_id,
    uuid,
    location_id,
    provider,
    visit_date,
    population_type,
    key_population_type,
    priority_population_type,
    patient_disabled,
    disability_type,
    department,
    patient_type,
    is_health_worker,
    recommended_test,
    test_strategy,
    hts_entry_point,
    hts_risk_category,
    hts_risk_score,
    relationship_with_contact,
    mother_hiv_status,
    tested_hiv_before,
    who_performed_test,
    test_results,
    date_tested,
    started_on_art,
    upn_number,
    ever_had_sex,
    sexually_active,
    new_partner,
    partner_hiv_status,
    couple_discordant,
    multiple_partners,
    number_partners,
    alcohol_sex,
    money_sex,
    condom_burst,
    unknown_status_partner,
    known_status_partner,
    experienced_gbv,
    type_of_gbv,
    service_received,
    currently_on_prep,
    recently_on_pep,
    recently_had_sti,
    tb_screened,
    cough,
    fever,
    weight_loss,
    night_sweats,
    contact_with_tb_case,
    lethargy,
    tb_status,
    shared_needle,
    needle_stick_injuries,
    traditional_procedures,
    child_reasons_for_ineligibility,
    pregnant,
    breastfeeding_mother,
    eligible_for_test,
    referred_for_testing,
    reason_to_test,
    reason_not_to_test,
    reasons_for_ineligibility,
    specific_reason_for_ineligibility,
    date_created,
    date_last_modified,
    voided
)
select
    e.patient_id,
    e.visit_id,
    e.encounter_id,
    e.uuid,
    e.location_id,
    e.creator,
    date(e.encounter_datetime) as visit_date,
    max(if(o.concept_id=164930,o.value_coded,null)) as population_type,
    max(if(o.concept_id=160581,(case o.value_coded when 105 then 'People who inject drugs'
                                                   when 160578 then 'Men who have sex with men'
                                                   when 160579 then 'Female sex worker'
                                                   when 165100 then 'Transgender'
                                                   when 162277 then 'People in prison and other closed settings' else '' end),null)) as key_population_type,
    max(if(o.concept_id=138643,(case o.value_coded when 159674 then 'Fisher folk'
                                                   when 162198 then 'Truck driver'
                                                   when 160549 then 'Adolescent and young girls'
                                                   when 162277 then 'Prisoner'
                                                   when 165192 then 'Military and other uniformed services' else '' end),null)) as priority_population_type,
    max(if(o.concept_id=164951,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as patient_disabled,
    concat_ws(',',nullif(max(if(o.concept_id=162558 and o.value_coded = 120291,"Hearing impairment",'')),''),
              nullif(max(if(o.concept_id=162558 and o.value_coded =147215,"Visual impairment",'')),''),
              nullif(max(if(o.concept_id=162558 and o.value_coded =151342,"Mentally Challenged",'')),''),
              nullif(max(if(o.concept_id=162558 and o.value_coded = 164538,"Physically Challenged",'')),''),
              nullif(max(if(o.concept_id=162558 and o.value_coded = 5622,"Other",'')),''),
              nullif(max(if(o.concept_id=160632,o.value_text,'')),'')) as disability_type,
    max(if(o.concept_id=159936,o.value_coded,null)) as department,
    max(if(o.concept_id=164932,o.value_coded,null)) as patient_type,
    max(if(o.concept_id=5619,o.value_coded,null)) as is_health_worker,
    max(if(o.concept_id=167229,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as recommended_test,
    max(if(o.concept_id=164956,o.value_coded,null)) as test_strategy,
    max(if(o.concept_id=160540,o.value_coded,null)) as hts_entry_point,
    max(if(o.concept_id=167163,(case o.value_coded when 1407 then "Low" when 1499 then "Moderate" when 1408 then "High" when 167164 then "Very high" else "" end),null)) as hts_risk_category,
    max(if(o.concept_id=167162,o.value_numeric,null)) as hts_risk_score,
    concat_ws(',', max(if(o.concept_id = 166570 and o.value_coded = 163565, 'Sexual Contact', null)),
              max(if(o.concept_id = 166570 and o.value_coded = 166606, 'Social Contact', null)),
              max(if(o.concept_id = 166570 and o.value_coded = 166517, 'Needle sharing', null)),
              max(if(o.concept_id = 166570 and o.value_coded = 1107, 'None', null))) as relationship_with_contact,
    max(if(o.concept_id=1396,o.value_coded,null)) as mother_hiv_status,
    max(if(o.concept_id=164401,o.value_coded,null)) as tested_hiv_before,
    max(if(o.concept_id=165215,o.value_coded,null)) as who_performed_test,
    max(if(o.concept_id=159427,o.value_coded,null)) as test_results,
    max(if(o.concept_id=164400,o.value_datetime,null)) as date_tested,
    max(if(o.concept_id=165240,o.value_coded,null)) as started_on_art,
    max(if(o.concept_id=162053,o.value_numeric,null)) as upn_number,
    max(if(o.concept_id=5569,o.value_coded,null)) as ever_had_sex,
    max(if(o.concept_id=160109,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as sexually_active,
    max(if(o.concept_id=167144,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as new_partner,
    max(if(o.concept_id=1436,(case o.value_coded when 703 then "Positive" when 664 THEN "Negative" when 1067 then 'Unknown' when 162570 THEN "Declined to answer" else "" end),null)) as partner_hiv_status,
    max(if(o.concept_id=6096,o.value_coded,null)) as couple_discordant,
    max(if(o.concept_id=5568,(case o.value_coded when 1 then "YES" when 0 THEN "NO" end),null)) as multiple_partners,
    max(if(o.concept_id=5570,o.value_numeric,null)) as number_partners,
    max(if(o.concept_id=165088,o.value_coded,null)) as alcohol_sex,
    max(if(o.concept_id=160579,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as money_sex,
    max(if(o.concept_id=166559,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as condom_burst,
    max(if(o.concept_id=159218,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as unknown_status_partner,
    max(if(o.concept_id=163568,(case o.value_coded when 163289 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as known_status_partner,
    max(if(o.concept_id=167161,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as experienced_gbv,
    concat_ws(',', max(if(o.concept_id=167145 and o.value_coded = 1065 ,'Sexual violence',null)),
              max(if(o.concept_id=160658 and o.value_coded = 1065 ,'Emotional abuse',null)),
              max(if(o.concept_id=165205 and o.value_coded = 1065 ,'Physical violence',null))) as type_of_gbv,
    concat_ws(',', max(if(o.concept_id=164845 and o.value_coded = 1065 ,'PEP',null)),
              max(if(o.concept_id=165269 and o.value_coded = 1065 ,'PrEP',null)),
              max(if(o.concept_id=165098 and o.value_coded = 1065 ,'STI',null)),
              max(if(o.concept_id=112141 and o.value_coded = 1065 ,'TB',null))) as service_received,
    max(if(o.concept_id=165203,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as currently_on_prep,
    max(if(o.concept_id=1691,(case o.value_coded when 1 then "YES" when 0 THEN "NO" end),null)) as recently_on_pep,
    max(if(o.concept_id=165200,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as recently_had_sti,
    max(if(o.concept_id=165197,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as tb_screened,
    max(if(o.concept_id=1729 and o.value_coded = 159799,o.value_coded,null)) as cough,
    max(if(o.concept_id=1729 and o.value_coded = 1494,o.value_coded,null)) as fever,
    max(if(o.concept_id=1729 and o.value_coded = 832,o.value_coded,null)) as weight_loss,
    max(if(o.concept_id=1729 and o.value_coded = 133027,o.value_coded,null)) as night_sweats,
    max(if(o.concept_id=1729 and o.value_coded = 124068,o.value_coded,null)) as contact_with_tb_case,
    max(if(o.concept_id=1729 and o.value_coded = 116334,o.value_coded,null)) as lethargy,
    max(if(o.concept_id=1659,o.value_coded,null)) as tb_status,
    max(if(o.concept_id=165090,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as shared_needle,
    max(if(o.concept_id=165060,o.value_coded,null)) as needle_stick_injuries,
    max(if(o.concept_id=166365,o.value_coded,null)) as traditional_procedures,
    concat_ws(',', max(if(o.concept_id = 165908 and o.value_coded = 115122, 'Malnutrition', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 5050, 'Failure to thrive', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 127833, 'Recurrent infections', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 112141, 'TB', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 1174, 'Orphaned', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 163718, 'Parents tested HIV positive', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 140238, 'Prolonged fever', null)),
              max(if(o.concept_id = 165908 and o.value_coded = 5632, 'Child breastfeeding', null))) as child_reasons_for_ineligibility,
    max(if(o.concept_id=5272,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as pregnant,
    max(if(o.concept_id=5632,(case o.value_coded when 1065 then "YES" when 1066 THEN "NO" when 162570 THEN "Declined to answer" else "" end),null)) as breastfeeding_mother,
    max(if(o.concept_id=162699,o.value_coded,null)) as eligible_for_test,
    max(if(o.concept_id=1788,o.value_coded,null)) as referred_for_testing,
    max(if(o.concept_id=164082,(case o.value_coded when 165087 then "Client is eligible" when 165091 then "Based on HIV Risk category from EMR" when 1163 then "Both eligible and risk category" else "" end),null)) as reason_to_test,
    max(if(o.concept_id=160416,(case o.value_coded when 165078 then "Client is NOT eligible" when 165091 then "Based on HIV Risk category from EMR" when 1163 then "Both eligible and risk category" else "" end),null)) as reason_not_to_test,
    concat_ws(',', max(if(o.concept_id = 159803 and o.value_coded = 167156, 'Declined testing', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 165029, 'Wants to test with partner', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 160589, 'Stigma related issues', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 141814, 'Fear of violent partner', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 155974, 'No counselor to test', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 158948, 'High workload for the staff', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 163293, 'Too sick', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 160352, 'Lack of test kits', null)),
              max(if(o.concept_id = 159803 and o.value_coded = 5622, 'Other', null))) as reasons_for_ineligibility,
    max(if(o.concept_id=160632,o.value_text,null)) as specific_reason_for_ineligibility,
    e.date_created,
    if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
    e.voided
      from encounter e
        inner join person p on p.person_id=e.patient_id and p.voided=0
        inner join form f on f.form_id = e.form_id and f.uuid = '04295648-7606-11e8-adc0-fa7ae01bbebc'
        left outer join obs o on o.encounter_id = e.encounter_id and o.concept_id in
        (164930,160581,138643,159936,164932,5619,166570,164401,165215,159427,
        164400,165240,162053,160109,167144,1436,6096,5568,5570,165088,160579,
        166559,159218,163568,167161,1396,167145,160658,165205,164845,165269,112141,
        165203,1691,165200,165197,1729,1659,165090,165060,166365,165908,165098,
        5272,5632,162699,1788,159803,160632,164126,159803,167229,160540,167163,167162,160416,1396,5569)
      and o.voided=0
      where e.voided=0
            and e.date_created >= last_update_time
            or e.date_changed >= last_update_time
            or e.date_voided >= last_update_time
      group by e.patient_id,date(e.encounter_datetime)
      order by e.patient_id
    ON DUPLICATE KEY UPDATE
                         provider=VALUES(provider),
                         visit_date=VALUES(visit_date),
                         population_type=VALUES(population_type),
                         key_population_type=VALUES(key_population_type),
                         priority_population_type=VALUES(priority_population_type),
                         patient_disabled=VALUES(patient_disabled),
                         disability_type=VALUES(disability_type),
                         department=VALUES(department),
                         patient_type=VALUES(patient_type),
                         is_health_worker=VALUES(is_health_worker),
                         recommended_test=VALUES(recommended_test),
                         test_strategy=VALUES(test_strategy),
                         hts_entry_point=VALUES(hts_entry_point),
                         hts_risk_category=VALUES(hts_risk_category),
                         hts_risk_score=VALUES(hts_risk_score),
                         relationship_with_contact=VALUES(relationship_with_contact),
                         mother_hiv_status=VALUES(mother_hiv_status),
                         tested_hiv_before=VALUES(tested_hiv_before),
                         who_performed_test=VALUES(who_performed_test),
                         test_results=VALUES(test_results),
                         date_tested=VALUES(date_tested),
                         started_on_art=VALUES(started_on_art),
                         upn_number=VALUES(upn_number),
                         ever_had_sex=VALUES(ever_had_sex),
                         sexually_active=VALUES(sexually_active),
                         new_partner=VALUES(new_partner),
                         partner_hiv_status=VALUES(partner_hiv_status),
                         couple_discordant=VALUES(couple_discordant),
                         multiple_partners=VALUES(multiple_partners),
                         number_partners=VALUES(number_partners),
                         alcohol_sex=VALUES(alcohol_sex),
                         money_sex=VALUES(money_sex),
                         condom_burst=VALUES(condom_burst),
                         unknown_status_partner=VALUES(unknown_status_partner),
                         known_status_partner=VALUES(known_status_partner),
                         experienced_gbv=VALUES(experienced_gbv),
                         type_of_gbv=VALUES(type_of_gbv),
                         service_received=VALUES(service_received),
                         currently_on_prep=VALUES(currently_on_prep),
                         recently_on_pep=VALUES(recently_on_pep),
                         recently_had_sti=VALUES(recently_had_sti),
                         tb_screened=VALUES(tb_screened),
                         cough=VALUES(cough),
                         fever=VALUES(fever),
                         weight_loss=VALUES(weight_loss),
                         night_sweats=VALUES(night_sweats),
                         contact_with_tb_case=VALUES(contact_with_tb_case),
                         lethargy=VALUES(lethargy),
                         tb_status=VALUES(tb_status),
                         shared_needle=VALUES(shared_needle),
                         needle_stick_injuries=VALUES(needle_stick_injuries),
                         traditional_procedures=VALUES(traditional_procedures),
                         child_reasons_for_ineligibility=VALUES(child_reasons_for_ineligibility),
                         pregnant=VALUES(pregnant),
                         breastfeeding_mother=VALUES(breastfeeding_mother),
                         eligible_for_test=VALUES(eligible_for_test),
                         referred_for_testing=VALUES(referred_for_testing),
                         reason_to_test=VALUES(reason_to_test),
                         reason_not_to_test=VALUES(reason_not_to_test),
                         reasons_for_ineligibility=VALUES(reasons_for_ineligibility),
                         specific_reason_for_ineligibility=VALUES(specific_reason_for_ineligibility),
                         date_created=VALUES(date_created),
                         date_last_modified=VALUES(date_last_modified),
                         voided=VALUES(voided);

    SELECT "Completed processing hts eligibility screening data ", CONCAT("Time: ", NOW());
  END $$

   --- sp_update_etl_drug_order ---

DROP PROCEDURE IF EXISTS sp_update_etl_drug_order $$
CREATE PROCEDURE sp_update_etl_drug_order(IN last_update_time DATETIME)
BEGIN
SELECT "Processing Drug orders", CONCAT("Time: ", NOW());

INSERT INTO kenyaemr_etl.etl_drug_order (
    uuid,
    encounter_id,
    order_group_id,
    patient_id,
    location_id,
    visit_date,
    visit_id,
    provider,
    order_id,
    urgency,
    drug_concept_id,
    drug_short_name,
    drug_name,
    frequency,
    enc_name,
    dose,
    dose_units,
    quantity,
    quantity_units,
    dosing_instructions,
    duration,
    duration_units,
    instructions,
    route,
    voided,
    date_voided,
    date_created,
    date_last_modified)
select e.uuid,
    e.encounter_id,
    o.order_group_id,
    e.patient_id,
    e.location_id,
    date(e.encounter_datetime)                                                as visit_date,
    e.visit_id,
    e.creator                                                                 as provider,
    do.order_id                                                               as order_id,
    o.urgency                                                                 as urgency,
    group_concat(o.concept_id SEPARATOR '|')                                  as drug_concept_id,
    group_concat(left(cn0.name, 255) SEPARATOR '+')                           as drug_short_name,
    group_concat(left(cn.name, 255) SEPARATOR '+')                            as drug_name,
    group_concat(case do.frequency when 1 then 'Once daily, in the evening' when 2 then 'Once daily, in the morning' when 3 then 'Twice daily'
                                   when 4 then 'Once daily, at bedtime' when 5 then 'Once daily' when 6 then 'Thrice daily' end SEPARATOR '|')                                  as frequency,
    et.name                                                                   as enc_name,
    group_concat(do.dose SEPARATOR '|')                                       as dose,
    group_concat(left(cn1.name, 255) SEPARATOR '|')                           as dose_units,
    group_concat(do.quantity SEPARATOR '|')                                   as quantity,
    group_concat(left(cn2.name, 255) SEPARATOR '|')                           as quantity_units,
       do.dosing_instructions                                                 as dosing_instructions,
       do.duration                                                            as duration,
       (case do.duration_units
            when 1072 then 'DAYS'
            when 1073 then 'WEEKS'
            when 1074
                then 'MONTHS' end)                                            as duration_units,
       o.instructions                                                         as instructions,
       group_concat(left(cn3.name, 255) SEPARATOR '|')                        as route,
       o.voided                                                               as voided,
       o.date_voided                                                          as date_voided,
       e.date_created                                                         as date_created,
       e.date_changed                                                         as date_last_modified
from orders o
    inner join drug_order do on o.order_id = do.order_id
    inner join encounter e on e.encounter_id = o.encounter_id and e.voided = 0 and e.patient_id = o.patient_id
    inner join person p on p.person_id = e.patient_id and p.voided = 0
    left outer join encounter_type et on et.encounter_type_id = e.encounter_type
    left outer join concept_name cn0
    on o.concept_id = cn0.concept_id and cn0.locale = 'en' and cn0.concept_name_type = 'SHORT'
    left outer join concept_name cn on o.concept_id = cn.concept_id and cn.locale = 'en' and
    cn.concept_name_type = 'FULLY_SPECIFIED'
    left outer join concept_name cn1 on do.dose_units = cn1.concept_id and cn1.locale = 'en' and
    cn1.concept_name_type = 'FULLY_SPECIFIED'
    left outer join concept_name cn2 on do.quantity_units = cn2.concept_id and cn2.locale = 'en' and
    cn2.concept_name_type = 'FULLY_SPECIFIED'
    left outer join concept_name cn3 on do.route = cn3.concept_id and cn3.locale = 'en' and
    cn3.concept_name_type = 'FULLY_SPECIFIED'
    left outer join concept_set cs on o.concept_id = cs.concept_id  and do.dose_units = cs.concept_id and do.quantity_units = cs.concept_id and do.route = cs.concept_id
where o.voided = 0
  and o.order_type_id = 2
  and ((o.order_action = 'NEW' and o.date_stopped is not null) or (o.order_reason_non_coded = 'previously existing orders'))
  and e.voided = 0
  and e.date_created >= last_update_time
   or e.date_changed >= last_update_time
   or e.date_voided >= last_update_time
group by o.order_group_id,o.patient_id, o.encounter_id
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),provider=VALUES(provider),order_id=VALUES(order_id),urgency=VALUES(urgency),
    drug_concept_id=VALUES(drug_concept_id),drug_short_name=VALUES(drug_short_name),drug_name=VALUES(drug_name),frequency=VALUES(frequency),
                     enc_name=VALUES(enc_name),dose=VALUES(dose),dose_units=VALUES(dose_units),quantity=VALUES(quantity),
                     quantity_units=VALUES(quantity_units),dosing_instructions=VALUES(dosing_instructions),duration=VALUES(duration),duration_units=VALUES(duration_units),
                     instructions=VALUES(instructions),route=VALUES(route),voided=VALUES(voided);

SELECT "Completed processing drug orders data ", CONCAT("Time: ", NOW());
END $$

--- sp_update_etl_drug_order ---

DROP PROCEDURE IF EXISTS sp_update_etl_preventive_services $$
CREATE PROCEDURE sp_update_etl_preventive_services(IN last_update_time DATETIME)
BEGIN
    SELECT "Processing Preventive services", CONCAT("Time: ", NOW());

    insert into kenyaemr_etl.etl_preventive_services(
        patient_id,
        visit_date,
        provider,
        location_id,
        encounter_id,
        obs_group_id,
        malaria_prophylaxis_1,
        malaria_prophylaxis_2,
        malaria_prophylaxis_3,
        tetanus_taxoid_1,
        tetanus_taxoid_2,
        tetanus_taxoid_3,
        tetanus_taxoid_4,
        folate_iron_1,
        folate_iron_2,
        folate_iron_3,
        folate_iron_4,
        folate_1,
        folate_2,
        folate_3,
        folate_4,
        iron_1,
        iron_2,
        iron_3,
        iron_4,
        mebendazole,
        long_lasting_insecticidal_net,
        comment,
        date_last_modified,
        date_created,
        voided
    )
    select
        y.patient_id,
        y.visit_date,
        y.provider as provider,
        y.location_id,
        y.encounter_id,
        y.obs_group_id,
        max(if(vaccine='Malarial prophylaxis' and sequence=1, date_given, null)) as malaria_prophylaxis_1,
        max(if(vaccine='Malarial prophylaxis' and sequence=2, date_given, null)) as malaria_prophylaxis_2,
        max(if(vaccine='Malarial prophylaxis' and sequence=3, date_given, null)) as malaria_prophylaxis_3,
        max(if(vaccine='Tetanus Toxoid' and sequence=1, date_given, null)) as tetanus_taxoid_1,
        max(if(vaccine='Tetanus Toxoid' and sequence=2, date_given, null)) as tetanus_taxoid_2,
        max(if(vaccine='Tetanus Toxoid' and sequence=3, date_given, null)) as tetanus_taxoid_3,
        max(if(vaccine='Tetanus Toxoid' and sequence=4, date_given, null)) as tetanus_taxoid_4,
        max(if(vaccine='Folate/Iron' and sequence=1, date_given, null)) as folate_iron_1,
        max(if(vaccine='Folate/Iron' and sequence=2, date_given, null)) as folate_iron_2,
        max(if(vaccine='Folate/Iron' and sequence=3, date_given, null)) as folate_iron_3,
        max(if(vaccine='Folate/Iron' and sequence=4, date_given, null)) as folate_iron_4,
        max(if(vaccine='Folate' and sequence=1, date_given, null)) as folate_1,
        max(if(vaccine='Folate' and sequence=2, date_given, null)) as folate_2,
        max(if(vaccine='Folate' and sequence=3, date_given, null)) as folate_3,
        max(if(vaccine='Folate' and sequence=4, date_given, null)) as folate_4,
        max(if(vaccine='Iron' and sequence=1, date_given, null)) as iron_1,
        max(if(vaccine='Iron' and sequence=2, date_given, null)) as iron_2,
        max(if(vaccine='Iron' and sequence=3, date_given, null)) as iron_3,
        max(if(vaccine='Iron' and sequence=4, date_given, null)) as iron_4,
        max(if(vaccine='Mebendazole', date_given, null)) as mebendazole,
        max(if(vaccine='Long-lasting insecticidal net', date_given, null)) as long_lasting_insecticidal_net,
        y.comment,
        y.date_last_modified,
        y.date_created,
        y.voided
    from (
             select
                 person_id as patient_id,
                 visit_id,
                 date(encounter_datetime) as visit_date,
                 creator as provider,
                 location_id,
                 encounter_id,
                 max(if(concept_id=984 , (case when value_coded=84879 then 'Tetanus Toxoid' when value_coded=159610 then 'Malarial prophylaxis' when value_coded=104677 then 'Folate/Iron'
                                               when value_coded=79413 then 'Mebendazole' when value_coded=160428 then 'Long-lasting insecticidal net'
                                               when value_coded=76609 then 'Folate' when value_coded=78218 then 'Iron' end), null)) as vaccine,
                 max(if(concept_id=1418, value_numeric, null)) as sequence,
                 max(if(concept_id=161011, value_text, null)) as comment,
                 max(if(concept_id=1410, date_given, null)) as date_given,
                 date(date_created) as date_created,
                 date_last_modified,
                 voided,
                 obs_group_id
             from (
                      select o.person_id,e.visit_id,o.concept_id, e.encounter_datetime, e.creator, e.date_created,if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified, o.value_coded, o.value_numeric,o.value_text, date(o.value_datetime) date_given, o.obs_group_id, o.encounter_id, e.voided,e.location_id
                      from obs o
                               inner join encounter e on e.encounter_id=o.encounter_id
                               inner join person p on p.person_id=o.person_id and p.voided=0
                               inner join form f on f.form_id=e.form_id and f.uuid = 'd3ea25c7-a3e8-4f57-a6a9-e802c3565a30'
                      where concept_id in(984,1418,161011,1410,5096) and o.voided=0
                         and e.date_created >= last_update_time
                         or e.date_changed >= last_update_time
                         or e.date_voided >= last_update_time
                      group by o.obs_group_id,o.concept_id, e.encounter_datetime
                  ) t
             group by t.obs_group_id
             having vaccine != ''
         ) y
    group by y.obs_group_id
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),provider=VALUES(provider),malaria_prophylaxis_1=VALUES(malaria_prophylaxis_1),malaria_prophylaxis_2=VALUES(malaria_prophylaxis_2),
                            malaria_prophylaxis_3=VALUES(malaria_prophylaxis_3),tetanus_taxoid_1=VALUES(tetanus_taxoid_1),tetanus_taxoid_2=VALUES(tetanus_taxoid_2),tetanus_taxoid_3=VALUES(tetanus_taxoid_3),
                            tetanus_taxoid_4=VALUES(tetanus_taxoid_4),folate_iron_1=VALUES(folate_iron_1),folate_iron_2=VALUES(folate_iron_2),folate_iron_3=VALUES(folate_iron_3),
                            folate_iron_4=VALUES(folate_iron_4),folate_1=VALUES(folate_1),folate_2=VALUES(folate_2),folate_3=VALUES(folate_3),
                            folate_4=VALUES(folate_4),iron_1=VALUES(iron_1),iron_2=VALUES(iron_2),
                            iron_3=VALUES(iron_3),iron_4=VALUES(iron_4),mebendazole=VALUES(mebendazole),
                            long_lasting_insecticidal_net=VALUES(long_lasting_insecticidal_net),comment=VALUES(comment),voided=VALUES(voided);
    SELECT "Completed processing Preventive services data", CONCAT("Time: ", NOW());
END $$

DROP PROCEDURE IF EXISTS sp_update_etl_overdose_reporting $$
CREATE PROCEDURE sp_update_etl_overdose_reporting(IN last_update_time DATETIME)
BEGIN
    SELECT "Processing overdose reporting";
    INSERT INTO kenyaemr_etl.etl_overdose_reporting (
        client_id,
        visit_id,
        encounter_id,
        uuid,
        provider,
        location_id,
        visit_date,
        overdose_location,
        overdose_date,
        incident_type,
        incident_site_name,
        incident_site_type,
        naloxone_provided,
        risk_factors,
        other_risk_factors,
        drug,
        other_drug,
        outcome,
        remarks,
        reported_by,
        date_reported,
        witness,
        date_witnessed,
        encounter,
        date_created,
        date_last_modified,
        voided
    )
    select
        e.patient_id,
        e.visit_id,
        e.encounter_id,
        e.uuid,
        e.location_id,
        e.creator,
        date(e.encounter_datetime) as visit_date,
        max(if(o.concept_id=162725,o.value_text,null)) as overdose_location,
        max(if(o.concept_id=165146,o.value_datetime,null)) as overdose_date,
        max(if(o.concept_id=165133,o.value_coded,null)) as incident_type,
        max(if(o.concept_id=165006,o.value_text,null)) as incident_site_name,
        max(if(o.concept_id=165005,o.value_coded,null)) as incident_site_type,
        max(if(o.concept_id=165136,o.value_coded,null)) as naloxone_provided,
        concat_ws(',', max(if(o.concept_id = 165140 and o.value_coded = 989, 'Age', null)),
                  max(if(o.concept_id = 165140 and o.value_coded = 162747, 'Comorbidity', null)),
                  max(if(o.concept_id = 165140 and o.value_coded = 131779, 'Abstinence from opioid use', null)),
                  max(if(o.concept_id = 165140 and o.value_coded = 129754, 'Mixing', null)),
                  max(if(o.concept_id = 165140 and o.value_coded = 134236, 'MAT induction/Re-induction', null)),
                  max(if(o.concept_id = 165140 and o.value_coded = 5622, 'Other', null))) as risk_factors,
        max(if(o.concept_id=165145,o.value_text,null)) as other_risk_factors,
        concat_ws(',', max(if(o.concept_id = 1193 and o.value_coded = 79661, 'Methadone', null)),
                  max(if(o.concept_id = 1193 and o.value_coded = 121725, 'Alcohol', null)),
                  max(if(o.concept_id = 1193 and o.value_coded = 146504, 'Cannabis', null)),
                  max(if(o.concept_id = 1193 and o.value_coded = 73650, 'Cocaine', null)),
                  max(if(o.concept_id = 1193 and o.value_coded = 76511, 'Flunitrazepam (Tap tap, Bugizi)', null)),
                  max(if(o.concept_id = 1193 and o.value_coded = 77443, 'Heroine', null)),
                  max(if(o.concept_id = 1193 and o.value_coded = 5622, 'Other', null))) as risk_factors,
        max(if(o.concept_id=163101,o.value_text,null)) as other_drug,
        max(if(o.concept_id=165141,o.value_coded,null)) as outcome,
        max(if(o.concept_id=160632,o.value_text,null)) as remarks,
        max(if(o.concept_id=1473,o.value_text,null)) as reported_by,
        max(if(o.concept_id=165144,o.value_datetime,null)) as date_reported,
        max(if(o.concept_id=165143,o.value_text,null)) as witness,
        max(if(o.concept_id=160753,o.value_datetime,null)) as date_witnessed,
        case f.uuid when '92fd9c5a-c84a-483b-8d78-d4d7a600db30' then 'Peer Overdose' when 'd753bab3-0bbb-43f5-9796-5e95a5d641f3' then 'HCW overdose' end as encounter,
        e.date_created,
        if(max(o.date_created) > min(e.date_created),max(o.date_created),NULL) as date_last_modified,
        e.voided
    from encounter e
             inner join person p on p.person_id=e.patient_id and p.voided=0
             inner join form f on f.form_id = e.form_id and f.uuid in ('92fd9c5a-c84a-483b-8d78-d4d7a600db30','d753bab3-0bbb-43f5-9796-5e95a5d641f3')
             left outer join obs o on o.encounter_id = e.encounter_id and o.concept_id in
                                                                          (162725,165146,165133,165006,165005,165136,165140,1193,163101,165141,160632,1473,165144,165143,160753)
        and o.voided=0
    where e.voided=0
        and e.date_created >= last_update_time
       or e.date_changed >= last_update_time
       or e.date_voided >= last_update_time
       or o.date_created >= last_update_time
       or o.date_voided >= last_update_time
    group by e.patient_id,e.encounter_type
    ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),
                            provider=VALUES(provider),
                            overdose_location=VALUES(overdose_location),
                            overdose_date=VALUES(overdose_date),
                            incident_type=VALUES(incident_type),
                            incident_site_name=VALUES(incident_site_name),
                            incident_site_type=VALUES(incident_site_type),
                            naloxone_provided=VALUES(naloxone_provided),
                            risk_factors=VALUES(risk_factors),
                            other_risk_factors=VALUES(other_risk_factors),
                            drug=VALUES(drug),
                            other_drug=VALUES(other_drug),
                            outcome=VALUES(outcome),
                            remarks=VALUES(remarks),
                            reported_by=VALUES(reported_by),
                            date_reported=VALUES(date_reported),
                            witness=VALUES(witness),
                            date_witnessed=VALUES(date_witnessed),
                            encounter=VALUES(encounter),
                            date_created=VALUES(date_created),
                            date_last_modified=VALUES(date_last_modified),
                            voided=VALUES(voided);
    SELECT "Completed processing overdose reporting";
END $$
-- end of scheduled updates procedures

    SET sql_mode=@OLD_SQL_MODE $$
-- ----------------------------  scheduled updates ---------------------


DROP PROCEDURE IF EXISTS sp_scheduled_updates $$
CREATE PROCEDURE sp_scheduled_updates()
  BEGIN
    DECLARE update_script_id INT(11);
    DECLARE last_update_time DATETIME;
    SELECT max(start_time) into last_update_time from kenyaemr_etl.etl_script_status where stop_time is not null or stop_time !="";

    INSERT INTO kenyaemr_etl.etl_script_status(script_name, start_time) VALUES('scheduled_updates', NOW());
    SET update_script_id = LAST_INSERT_ID();
    CALL sp_update_etl_patient_demographics(last_update_time);
    CALL sp_update_etl_hiv_enrollment(last_update_time);
    CALL sp_update_etl_hiv_followup(last_update_time);
    CALL sp_update_etl_program_discontinuation(last_update_time);
    CALL sp_update_etl_mch_enrollment(last_update_time);
    CALL sp_update_etl_mch_antenatal_visit(last_update_time);
    CALL sp_update_etl_mch_postnatal_visit(last_update_time);
    CALL sp_update_etl_tb_enrollment(last_update_time);
    CALL sp_update_etl_tb_follow_up_visit(last_update_time);
    CALL sp_update_etl_tb_screening(last_update_time);
    CALL sp_update_etl_hei_enrolment(last_update_time);
    CALL sp_update_etl_hei_immunization(last_update_time);
    CALL sp_update_etl_hei_follow_up(last_update_time);
    CALL sp_update_etl_mch_discharge(last_update_time);
    CALL sp_update_etl_mch_delivery(last_update_time);
    CALL sp_update_drug_event(last_update_time);
    CALL sp_update_etl_pharmacy_extract(last_update_time);
    CALL sp_update_etl_laboratory_extract(last_update_time);
    CALL sp_update_hts_test(last_update_time);
    CALL sp_update_hts_linkage_and_referral(last_update_time);
    CALL sp_update_hts_referral(last_update_time);
    CALL sp_update_etl_ipt_initiation(last_update_time);
    CALL sp_update_etl_ipt_outcome(last_update_time);
    CALL sp_update_etl_ipt_follow_up(last_update_time);
    CALL sp_update_etl_ccc_defaulter_tracing(last_update_time);
    CALL sp_update_etl_ART_preparation(last_update_time);
    CALL sp_update_etl_enhanced_adherence(last_update_time);
    CALL sp_update_etl_patient_triage(last_update_time);
    CALL sp_update_etl_prep_enrolment(last_update_time);
    CALL sp_update_etl_prep_behaviour_risk_assessment(last_update_time);
    CALL sp_update_etl_prep_monthly_refill(last_update_time);
    CALL sp_update_etl_prep_followup(last_update_time);
    CALL sp_update_etl_progress_note(last_update_time);
    CALL sp_update_etl_prep_discontinuation(last_update_time);
    CALL sp_update_etl_hts_linkage_tracing(last_update_time);
    CALL sp_update_etl_patient_program(last_update_time);
    CALL sp_update_etl_person_address(last_update_time);
    CALL sp_update_etl_otz_enrollment(last_update_time);
    CALL sp_update_etl_otz_activity(last_update_time);
    CALL sp_update_etl_ovc_enrolment(last_update_time);
    CALL sp_update_etl_cervical_cancer_screening(last_update_time);
    CALL sp_update_etl_kp_contact(last_update_time);
    CALL sp_update_etl_kp_client_enrollment(last_update_time);
    CALL sp_update_etl_kp_clinical_visit(last_update_time);
    CALL sp_update_etl_kp_sti_treatment(last_update_time);
    CALL sp_update_etl_kp_peer_calendar(last_update_time);
    CALL sp_update_etl_kp_peer_tracking(last_update_time);
    CALL sp_update_etl_kp_treatment_verification(last_update_time);
    --CALL sp_update_etl_gender_based_violence(last_update_time);
    CALL sp_update_etl_PrEP_verification(last_update_time);
    CALL sp_update_etl_alcohol_drug_abuse_screening(last_update_time);
    CALL sp_update_etl_gbv_screening(last_update_time);
    CALL sp_update_etl_depression_screening(last_update_time);
    CALL sp_update_etl_adverse_events(last_update_time);
    CALL sp_update_etl_allergy_chronic_illness(last_update_time);
    CALL sp_update_etl_ipt_screening(last_update_time);
    CALL sp_update_etl_pre_hiv_enrollment_art(last_update_time);
    CALL sp_update_etl_covid_19_assessment(last_update_time);
    CALL sp_update_etl_vmmc_enrolment(last_update_time);
    CALL sp_update_etl_vmmc_circumcision_procedure(last_update_time);
    CALL sp_update_etl_vmmc_client_followup(last_update_time);
    CALL sp_update_etl_vmmc_post_operation_assessment(last_update_time);
    CALL sp_update_etl_hts_eligibility_screening(last_update_time);
    CALL sp_update_etl_drug_order(last_update_time);
    CALL sp_update_etl_preventive_services(last_update_time);
    CALL sp_update_etl_overdose_reporting(last_update_time);

    CALL sp_update_dashboard_table();

    UPDATE kenyaemr_etl.etl_script_status SET stop_time=NOW() where  id= update_script_id;
    DELETE FROM kenyaemr_etl.etl_script_status where script_name in ("KenyaEMR_Data_Tool", "scheduled_updates") and start_time < DATE_SUB(NOW(), INTERVAL 12 HOUR);
    SELECT update_script_id;

    END $$
-- DELIMITER ;











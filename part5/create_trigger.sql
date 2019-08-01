create or replace trigger act_io
  instead of insert or update or delete
  on ttm_activities_vw
  for each row
begin
  if inserting then
    insert into ttm_activities
         ( act_prj_id
         , act_start_datetime
         , act_end_datetime
         , act_description
         , act_location
         )
    values
         ( :new.act_prj_id
         , ttm_alg.time2date(:new.act_start_date,:new.act_start_time)
         , ttm_alg.time2date(:new.act_start_date,:new.act_end_time)
         , :new.act_description
         , :new.act_location
         );

  elsif updating then
    update ttm_activities
    set    act_prj_id = :new.act_prj_id
         , act_start_datetime = ttm_alg.time2date(:new.act_start_date,:new.act_start_time) 
         , act_end_datetime   = ttm_alg.time2date(:new.act_start_date,  :new.act_end_time)
         , act_description    = :new.act_description
         , act_location       = :new.act_location
    where  act_id = :new.act_id
    ;    

  elsif deleting then
    delete ttm_activities
    where  act_id = :old.act_id    
    ;
  end if;
end;
/
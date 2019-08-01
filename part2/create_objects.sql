REM Create script for Time Tracking Application
REM Author: Dick Dral
REM Date: 05-07-2019
REM Version 1.1
REM 09-07-2019 Bug in ACT_IO solved that would delete all activities

create sequence ttm_seq;

REM **************************************************************************************
REM Table TTM_PROJECTS
REM
create table ttm_projects
( prj_id   number
, prj_short_name   varchar2(20)
, prj_name   varchar2(100)
, prj_description   varchar2(1000)
, constraint ttm_prj_pk primary key (prj_id) enable
);
comment on column ttm_projects.prj_id          is 'Meaningless key';
comment on column ttm_projects.prj_short_name  is 'Short name for project';
comment on column ttm_projects.prj_name        is 'Project name';
comment on column ttm_projects.prj_description is 'Description of the project';

create or replace trigger ttm_prj_bi
  before insert on ttm_projects
  for each row  
begin   
  if :new.prj_id is null then 
    :new.prj_id := ttm_seq.nextval;
  end if; 
end;
/

REM **************************************************************************************
REM Table TTM_ACTIVITIES
REM
create table ttm_activities
( act_id  number
, act_prj_id   number
, act_start_datetime   date
, act_end_datetime  date
, act_description   varchar2(1000)
, act_location     varchar2(100)
, constraint ttm_act_pk primary key (act_id) enable
, constraint ttm_act_prj foreign key (act_prj_id) references ttm_projects(prj_id) enable
);

comment on column ttm_activities.act_id             is 'Meaningless key';
comment on column ttm_activities.act_prj_id         is 'Reference to project for which the activity is performed';
comment on column ttm_activities.act_start_datetime is 'Date and time when the activity is started';
comment on column ttm_activities.act_end_datetime   is 'Date and time when the activity is ended';
comment on column ttm_activities.act_description    is 'Description of the activity';
comment on column ttm_activities.act_location       is 'Location where the activity takes place';

create or replace trigger ttm_act_bi
  before insert on ttm_activities
  for each row  
begin   
  if :new.act_id is null then 
    :new.act_id := ttm_seq.nextval;
  end if; 
end;
/

REM **************************************************************************************
REM Package TTM_ALG
REM
create or replace package ttm_alg is
-- extract time fraction in format HH24:MI from date
  function date2time
      ( p_date   in  date
      ) return varchar2;
-- combine date and time in format HH24:MI to date with time fraction
  function time2date
      ( p_date   in  date
      , p_time   in  varchar2
      ) return date;
end;
/

create or replace package body ttm_alg is

/*******************************************************************************
 * Function date2time
 * Author: Dick Dral      Date: 05-07-2019
 * This function converts a given date with time fraction to a string displaying
 * the time in the given format HH24:MI
 *               
 * Parameters  : p_date         date with time fraction
 *               return value   time fraction in format HH24:MI
 */
  function date2time
      ( p_date   in  date
      ) return varchar2 is
    l_return     varchar2(10);
  begin
    l_return := to_char(p_date,'hh24:mi');
    return(l_return);
  end;

/*******************************************************************************
 * Function date2time
 * Author: Dick Dral      Date: 05-07-2019
 * This function converts a given date and a given time in the format HH24:MI to 
 * a date value containing the the given date and time.
 *               
 * Parameters  : p_date         date with time fraction
 *               p_time         time in format HH24:MI
 *               return value   given date combined with given time
 */
  function time2date
      ( p_date   in  date
      , p_time   in  varchar2
      ) return date  is
    l_hours      number;
    l_minutes    number;
    l_return     date;
  begin
    -- determine number of hours from time
    if instr(p_time,':') > 0 then
      l_hours     := to_number(substr(p_time,1,instr(p_time,':')-1));
      l_minutes   := substr(p_time,instr(p_time,':')+1);
      if l_minutes is not null then
        l_hours := l_hours + to_number(l_minutes)/60;
      end if;
    else
      -- with empty time the result is a trunced date
      l_hours := nvl(to_number(p_time),0);
    end if;

    -- combine date and time
    l_return := p_date + l_hours/24;

    return(l_return);
  end;

end;
/

REM **************************************************************************************
REM View TTM_ACITIVITIES_VW
REM
create or replace view ttm_activities_vw as
  select act.act_id
     , trunc(act_start_datetime)               as  act_start_date
     , act.act_prj_id
     , prj.prj_name                            as  act_prj_name
     , ttm_alg.date2time(act_start_datetime)   as  act_start_time
     , ttm_alg.date2time(act_end_datetime)     as  act_end_time
     , act_description
     , act_location
from   ttm_activities     act
  join ttm_projects       prj
       on  prj.prj_id = act.act_prj_id
;

REM Create instead of trigger to process time input
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

REM **************************************************************************************
REM Data for TTM_PROJECTS
REM

insert into ttm_projects (prj_id,prj_short_name,prj_name,prj_description) values (1,'TTM','Time Tracker Mobile','Development of a mobile time registration system');
insert into ttm_projects (prj_id,prj_short_name,prj_name,prj_description) values (2,'ADM','Administration','Administration (also has to be done :-( )');
insert into ttm_projects (prj_id,prj_short_name,prj_name,prj_description) values (3,'PRX','Project X','Super Secret Project...');

REM **************************************************************************************
REM Data for TTM_ACTIVITIES
REM

insert into ttm_activities (act_id,act_prj_id,act_start_datetime,act_end_datetime,act_description,act_location) values (4,1,to_date('05-07-2019 09:00','DD-MM-YYYY HH24:MI'),to_date('05-07-2019 10:30','DD-MM-YYYY HH24:MI'),'Create pages','At home');
insert into ttm_activities (act_id,act_prj_id,act_start_datetime,act_end_datetime,act_description,act_location) values (5,2,to_date('05-07-2019 10:30','DD-MM-YYYY HH24:MI'),to_date('05-07-2019 12:00','DD-MM-YYYY HH24:MI'),'Income tax statement','At home');
insert into ttm_activities (act_id,act_prj_id,act_start_datetime,act_end_datetime,act_description,act_location) values (6,3,to_date('05-07-2019 13:00','DD-MM-YYYY HH24:MI'),to_date('05-07-2019 15:30','DD-MM-YYYY HH24:MI'),'Super secret','At home');
insert into ttm_activities (act_id,act_prj_id,act_start_datetime,act_end_datetime,act_description,act_location) values (7,1,to_date('04-07-2019 09:00','DD-MM-YYYY HH24:MI'),to_date('04-07-2019 10:30','DD-MM-YYYY HH24:MI'),'Prepare database','At home');

commit;


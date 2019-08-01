REM Alter the table activities by adding columns for the spatial location

alter table ttm_activities add 
( act_use_location  varchar2(10)
, act_lattitude     number
, act_longitude     number
, act_sdo_location  sdo_geometry
);


REM Alter the trigger on activities to construct the spatial column

create or replace trigger ttm_act_bi
  before insert on ttm_activities
  for each row  
begin   
  if :new.act_id is null then 
    :new.act_id := ttm_seq.nextval;
  end if; 

  if :new.act_use_location = 'Y' then
    :new.act_sdo_location := sdo_geometry(2001,8307,sdo_point_type(:new.act_longitude,:new.act_lattitude,NULL),NULL,NULL);
  end if;
end;
/

REM **************************************************************************************
REM View TTM_ACTIVITIES_VW
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
     , act_lattitude
     , act_longitude
     , act_use_location
     , act_sdo_location
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
         , act_use_location
         , act_lattitude
         , act_longitude
         )
    values
         ( :new.act_prj_id
         , ttm_alg.time2date(:new.act_start_date,:new.act_start_time)
         , ttm_alg.time2date(:new.act_start_date,:new.act_end_time)
         , :new.act_description
         , :new.act_location
         , :new.act_use_location
         , :new.act_lattitude
         , :new.act_longitude
         );

  elsif updating then
    update ttm_activities
    set    act_prj_id = :new.act_prj_id
         , act_start_datetime = ttm_alg.time2date(:new.act_start_date,:new.act_start_time) 
         , act_end_datetime   = ttm_alg.time2date(:new.act_start_date,  :new.act_end_time)
         , act_description    = :new.act_description
         , act_location       = :new.act_location
         , act_use_location   = :new.act_use_location
         , act_lattitude      = :new.act_lattitude
         , act_longitude      = :new.act_longitude
    where  act_id = :new.act_id
    ;    
  
  elsif deleting then
    delete ttm_activities
    where  act_id = :old.act_id
    ;
  end if;
end;
/

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
      
-- last used project
  function last_used_project return number;
  
-- default start time for given date
  function default_start_time
      ( p_date    in  date  default sysdate
      ) return varchar2;

-- check the time format and return an error message
  function check_time
      ( p_time        in  varchar2
      , p_item_name   in  varchar2  default null
      )  return varchar2;

  function check_time2
      ( p_time        in  varchar2
      , p_item_name   in  varchar2  default null
      )  return varchar2;

-- returns location based on GPS coordinates
  function default_location
      ( p_lattitude    in  number
      , p_longitude    in  number
      ) return varchar2;
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
  
/*******************************************************************************
 * Function last_used_project
 * Author: Dick Dral      Date: 08-07-2019
 * This function returns the project of the latest activity
 *               
 * Parameters  : return value   project ID
 */
  function last_used_project return number is
    cursor c is
      select act_prj_id
      from   ttm_activities
      order by act_start_datetime desc
      ;
    l_return   number;
  begin
    open c;
    fetch c into l_return;
    close c;
    return(l_return);
  end;

/*******************************************************************************
 * Function default_start_time
 * Author: Dick Dral      Date: 08-07-2019
 * This function returns latest end time on the given date or the default start time
 * of 9:00
 *               
 * Parameters  : p_date         date for activity
 *               return value   default start time on date
 */
  function default_start_time
      ( p_date    in  date  default sysdate
      ) return varchar2  is
    cursor c is
      select to_char(max(act_end_datetime),'hh24:mi')
      from   ttm_activities
      where  trunc(act_start_datetime) = trunc(p_date)
      ;
    l_return     varchar2(100);
  begin
    open c;
    fetch c into l_return;
    close c;
    
    l_return := nvl(l_return,'9:00');
    return(l_return);
  end;

/*******************************************************************************
 * Function check_time
 * Author: Dick Dral      Date: 08-07-2019
 * This function checks the input time on being a valid time indication of the 
 * form HH24:MI. 
 *               
 * Parameters  : p_time         formatted time string
 *               p_item_name    item name to be used in the error message
 *               return value   default start time on date
 */
  function check_time
      ( p_time        in  varchar2
      , p_item_name   in  varchar2
      )  return varchar2 is 
    l_elem       apex_application_global.vc_arr2;
    l_hours      number;
    l_minutes    number;
    l_return     varchar2(1000);
  begin
    if p_time is null then
      return(null);
    end if;
    
    l_elem := apex_util.string_to_table(p_time,':');  
    
    -- check hour value
    begin
      l_hours := l_elem(1);
    exception
      when others then
        l_return := 'The value for hours "'||l_elem(1)||'" must be numeric';
    end;
    
    if l_return is null 
       and not l_hours between 0 and 24     -- hours between 0 and 24
    then
      l_return := 'The value for hours "'||l_hours||'" must be between 0 and 24.';
    end if;
    
    if     l_return is null 
       and l_hours != trunc(l_hours)         -- hours should be integer
    then
      l_return := 'The value for hours "'||l_hours||'" must be integer';
    end if;
    
    if l_return is null       -- no error until now
       and l_elem.count = 2   -- and split has resulted in two elements
    then

      -- check minute value
      begin
        l_minutes := l_elem(2);
      exception
        when others then
          l_return := 'The value for minutes "'||l_elem(2)||'" must be numeric';
      end;
    
      if l_return is null 
         and not l_minutes between 0 and 59     -- minutes between 0 and 59
      then
        l_return := 'The value for minutes "'||l_minutes||'" must be between 0 and 59.';
      end if;
    
      if     l_return is null 
        and l_minutes != trunc(l_minutes)         -- minutes should be integer
      then
        l_return := 'The value for minutes "'||l_minutes||'" must be integer';
      end if;
      
    end if;
        
    -- prepend item reference if item name given
    if     l_return is not null
       and p_item_name is not null 
    then
      l_return := 'Error in '||p_item_name||': '||l_return;
    end if;

    return(l_return);
  exception
    when others then
      return(nvl(l_return,sqlerrm));
  end;

/*******************************************************************************
 * Function check_time
 * Author: Dick Dral      Date: 08-07-2019
 * This function checks the input time on being a valid time indication of the 
 * form HH24:MI using the Oracle format conversion.
 * This function does not function as good as check_time. 
 *               
 * Parameters  : p_time         formatted time string
 *               p_item_name    item name to be used in the error message
 *               return value   default start time on date
 */
  function check_time2
      ( p_time        in  varchar2
      , p_item_name   in  varchar2
      )  return varchar2 is
    l_char_date    varchar2(100);
    l_date         date;
    l_return       varchar2(1000);
  begin
    l_char_date := to_char(sysdate,'dd-mm-yyyy')||' ';
    l_date := to_date(l_char_date||p_time,'dd-mm-yyyy hh24:mi');
    return(null);
  exception
    when others then
      l_return := 'Error in '||p_item_name||': '||sqlerrm;
      return(l_return);    
  end;
    
/*******************************************************************************
 * Function default_location
 * Author: Dick Dral      Date: 01-08-2019
 * Looks for a location in activities based on the given coordinates. 
 * The activity closest to the coordinates (if any) is selected.
 * The name of the location is returned
 *               
 * Parameters  : p_lattitude    lattitude
 *               p_longitude    longitude
 *               return value   name of the location
 */
  function default_location
      ( p_lattitude    in  number
      , p_longitude    in  number
      ) return varchar2 is
    cursor c is
      select act_location
      from   ttm_activities
      where  act_lattitude is not null 
        and  act_longitude is not null
        and  act_use_location = 'Y'
        and  sdo_geom.within_distance(act_sdo_location,0.2, sdo_geometry(2001,8307,sdo_point_type(p_longitude,p_lattitude,null),null,null),1,'unit=km')   = 'TRUE'
        order by sdo_geom.sdo_distance(act_sdo_location,sdo_geometry(2001,8307,sdo_point_type(p_longitude,p_lattitude,null),null,null),1,'unit=km')
      ;          
    l_return   ttm_activities.act_location%type;
  begin

    if     p_lattitude is not null 
       and p_longitude is not null
    then
      -- select the name of the location of the activity within range which is closest
      open c;
      fetch c into l_return;    
      close c;
    end if;
    
    return(l_return);
  end;
  
end;
/
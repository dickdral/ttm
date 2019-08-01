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
 *               return value   error message if time is not valid
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
 * The messages returned by this function are less clear than the messages from
 * check_time.
 *               
 * Parameters  : p_time         formatted time string
 *               p_item_name    item name to be used in the error message
 *               return value   error message if time is not valid
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
end;
/
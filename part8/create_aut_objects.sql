
create table aut_sessions 
( ses_id number, 
  ses_username varchar2(100 byte), 
  ses_token varchar2(100 byte), 
  ses_valid_until date, 
  ses_created_on date
);

create or replace trigger aut_ses_bi 
  before insert or update
  on aut_sessions
  for each row
begin
  :new.ses_id := ttm_seq.nextval;
  :new.ses_created_on := sysdate;
  :new.ses_valid_until := sysdate + 365;  
end;
/

alter trigger aut_ses_bi enable;

create table aut_users
( usr_username    varchar2(100)
, usr_password    varchar2(100)
);

create or replace package aut_pck is

  function authenticate
      ( p_username        in  varchar2
      , p_password        in  varchar2
      ) return boolean;
      
  function get_username_from_cookie return varchar2;
   
  procedure set_username_in_cookie
       ( p_username      in  varchar2
       , p_remember      in  varchar2
       );
       
  procedure autologin
       ( p_app_id      in  varchar2 default null
       , p_page_id     in  varchar2 default 1
       );
       
  procedure autologout;
   
end;
/

create or replace package body aut_pck is
  g_cookie_name      varchar2(100) := 'APEX_STAY_LOGGED_IN_'||v('APP_ID');

/*******************************************************************************
 * Function    : authenticate
 * Author      : Dick Dral             Date : 07-11-2016
 * Description : Simple and unsafe authentication method (passwords are stored in 
 *               clear text)
 * Parameters  : p_username       Username
 *               p_password       Password
 */
  function authenticate
      ( p_username        in  varchar2
      , p_password        in  varchar2
      ) return boolean is

    cursor c_usr (cp_username  in varchar2)  is
      select *
      from   aut_users
      where  upper(usr_username) = upper(cp_username)
      ;
    r_usr                 c_usr%rowtype;
    l_return              boolean := false;
    
  begin

    if p_password is not null then
    
      open  c_usr(p_username);
      fetch c_usr into r_usr;
      if c_usr%found then   
        l_return := ( r_usr.usr_password = p_password );
      end if;
      close c_usr;
      
    else

      apex_debug.message('Perform Autologin for username '||p_username||', username from cookie='||aut_pck.get_username_from_cookie);
      -- AUTOLOGIN?
      l_return := ( p_username = aut_pck.get_username_from_cookie );
      
    end if;
    
    return(l_return);
    
  exception
    when others then 
      return(false);

  end;
      
/*******************************************************************************
 * Function    : set_username_in_sessions
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Records the username in combination with a generated token in the
 *               table aut_sessions.
 *               The value of the generated token is returned.
 *               
 * Parameters  : p_app_id      application id
 *               return value  the generated token
 */
   function set_username_in_sessions
        ( p_username    in  varchar2
        ) return varchar2 is
    l_token      varchar2(100);
    l_return     varchar2(100);
  begin
    l_token := dbms_random.string('A',30);
    insert into aut_sessions
         ( ses_username    , ses_token)
    values
        ( upper(p_username), l_token  );
    commit;
    return(l_token);
  exception
    when others then
--      logger.log('aut_pck.set_username_in_sesions ERROR:'||sqlerrm);
--      logger.log('location:'||dbms_utility.format_error_backtrace);
      return null;
  end;

/*******************************************************************************
 * Function    : get_username_from_token
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Retrieves the username that belongs to a given token in the
 *               table aut_sessions.
 *               If the token is not found or the records is invalidated a 
 *               null value is returned.
 *               
 * Parameters  : p_token.      the token to be examined
 *               return value  the corresponding username
 */
   function get_username_from_token
       ( p_token    in  varchar2
       ) return varchar2 is
    l_return     varchar2(100);
  begin
    if p_token is not null then
      select ses_username
        into l_return
      from   aut_sessions
      where  ses_token       = p_token
        and  ses_valid_until > sysdate
      ; 
    end if;
    return(l_return);
  exception
    when no_data_found 
    then return(null);
  end;

/*******************************************************************************
 * Function    : get_token_from_cookie
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Retrieves the token from the cookie.
 *               
 * Parameters  : return value  the token stored in the cookie
 */
   function get_token_from_cookie return varchar2 is
    l_cookie     owa_cookie.cookie;
    l_token      aut_sessions.ses_token%type;
  begin
    l_cookie := owa_cookie.get
         ( name     =>  g_cookie_name
         );         

    if nvl(l_cookie.num_vals,0) = 1 then
      l_token  := l_cookie.vals(1);
    end if;
    return(l_token);
  end;

/*******************************************************************************
 * Function    : get_username_from_cookie
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Retrieves the username from the cookie.
 *.              For that first the token is read from the cookie.
 *.              Using the token the corresponding record with username is retrieved
 *.              from the table aut_sessions.
 *               
 * Parameters  : return value     username
 */
   function get_username_from_cookie return varchar2 is
    l_cookie     owa_cookie.cookie;
    l_token      aut_sessions.ses_token%type;
    l_return     varchar2(100);
  begin
    l_token := get_token_from_cookie;

    l_return := get_username_from_token
                       ( p_token   => l_token
                       );
    return(l_return);
  end;

/*******************************************************************************
 * Function    : set_username_in_cookie
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Stores the token in a cookie when:
 *               - p_remember = Y
 *               - user is authenticated (username != 'nobody')
 *               - there is no valid cookie for this user
 *               The token is determined in the function set_username_in_sesions.
 *               
 * Parameters  : p_username    username
 *               p_password    password
 *               p_remember    autologin indicator
 */
   procedure set_username_in_cookie
       ( p_username      in  varchar2
       , p_remember      in  varchar2
       )
       is
    l_cookie_name  varchar2(100);
    l_token        aut_sessions.ses_token%type;
    l_username     varchar2(100);
  begin

    l_cookie_name := g_cookie_name;
    l_username := get_username_from_cookie;

    apex_debug.message('p_username='||p_username);
    apex_debug.message('p_remember='||p_remember);
    apex_debug.message('l_username='||l_username);
    
    if     p_remember   = 'Y'        -- if the user requests autologin
       and p_username   != 'nobody'  -- and the user is authenticated
    then
    
      if     p_username  != l_username -- do not overwrite a valid cookie
         or  l_username  is null
      then  
        l_token := set_username_in_sessions
                        ( p_username    =>  p_username
                        );
        apex_debug.message('Authenticated! l_token='||l_token);
        if l_token is not null then
          owa_util.mime_header('text/html', false);
          owa_cookie.send
               ( name        =>  l_cookie_name
               , value       =>  l_token
               , expires     =>  sysdate + 365
               );
          apex_debug.message('Cookie '||l_cookie_name|| ' written.');
        end if;
        
      else
      
        apex_debug.message('No need to replace valid cookie for user '||l_username);
      end if;
      
    end if;
  exception
    when others then
      null;
  end;

/*******************************************************************************
 * Function    : autologin
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Performs the autologin action:
 *               - get username from cookie, if any
 *               - if username found then
 *                 - login with null password
 *                 - perform standard login and go to given page
 *               
 * Parameters  : p_page_id        page ID for current application
 */
   procedure autologin
       ( p_app_id      in  varchar2 default null
       , p_page_id     in  varchar2 default 1
       ) is
    l_username     varchar2(100);
    l_app_id       varchar2(100);
  begin
    -- check whether a user can be derived from the cookie
    l_username := get_username_from_cookie;
    apex_debug.message('Username from cookie:'||l_username);

    l_app_id := nvl(p_app_id,v('APP_ID'));
    -- if so try the autologin
    if l_username is not null then
      apex_debug.message('Opening page '||p_page_id||' in application '||l_app_id||'.');
      wwv_flow_custom_auth_std.login
           ( p_uname       => l_username
           , p_password    => null
           , p_session_id  => v('APP_SESSION')
           , p_flow_page   => l_app_id||':'||p_page_id
           );
    end if;
  end;

/*******************************************************************************
 * Function    : autologout
 * Author      : Dick Dral             Date : 12-05-2019
 * Description : Performs the autologin action:
 *               - get token from cookie
 *               - remove cookie
 *               - remove corresponding record in aut_sessions 
 *               - redirect to login page
 *               
 */
   procedure autologout is
    l_token         varchar2(100);    
    l_app_id        number;
  begin
    -- get token from cookie
    l_token := get_token_from_cookie;

    -- remove the autologin cookie
    owa_cookie.remove
        ( name   => g_cookie_name
        , val    =>  null
        );

    -- remove the corresponding autologin record
    delete aut_sessions
    where  ses_token = l_token
    ;

  end;

end aut_pck;
/

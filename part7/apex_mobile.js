/**
 * APEX_MOBILE.JS
 * 
 * Useful JS functions for mobile Oracle APEX apps
 * @version: 0.2
 */

/**
 * Places the title of a page in the Top Bar.
 * The title is retrieved from the title element in the head section of the HTML.
 *
 * @author: Dick Dral
 * @created: 07-09-2019
 */
function TitleInTopbar() {
var title = $('head title').text();
$('.t-Header-logo-link').text(title);
}

/**
 * Hide the success message
 * The success message is hidden by setting the height to 0
 *
 * @author: Dick Dral
 * @created: 08-09-2019
 */
function success_message_fade()
{
   apex.message.hidePageSuccess();
   $('#APEX_SUCCESS_MESSAGE').css('height','0');
}

/**
 * Let's the success message fade after 2 secs
 * The code uses setTimeout to delay the hiding of the success message
 * 
 * @author: Dick Dral
 * @params: pTimeout   time in msecs before message disappears
 * @created: 08-09-2019
 */
function set_success_message_fade(pTimeout)
{
    timeout = (pTimeout) ? pTimeout : 2000;
    setTimeout(success_message_fade,timeout);
}

/**
 * Adds a clock icon to the right of the item just like the icon of the data picker
 * 
 * @author: Dick Dral
 * @params: item_name   name of the APEX item
 * @created: 09-09-2019
 */
function add_clock_icon(item_name) {
  $('#'+item_name.toUpperCase()).addClass('has-time-picker');  
  $('#'+item_name.toUpperCase()).after('<div class="a-Button a-Button-inline" style="order: 3;"><i class="fa fa-clock-o"></i></div>');
}

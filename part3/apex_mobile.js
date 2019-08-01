/**
 * APEX_MOBILE.JS
 * 
 * Useful JS functions for mobile Oracle APEX apps
 * @version: 0.1
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
//= require jquery/dist/jquery
//= require popper.js/dist/umd/popper.min
//= require bootstrap/dist/js/bootstrap.bundle.min
//= require jquery.cookie/jquery.cookie.js
//= require waypoints/lib/jquery.waypoints.min.js
//= require jquery.counterup/jquery.counterup.min
//= require owl.carousel/dist/owl.carousel.min
//= require owl.carousel2.thumbs/dist/owl.carousel2.thumbs.min
//= require jquery-parallax.js/parallax.min
//= require bootstrap-select/dist/js/bootstrap-select.min
//= require bootstrap-slider/dist/bootstrap-slider.min
//= require jquery.scrollto/jquery.scrollTo.min
//= require parsleyjs/dist/parsley.min
//= require parsleyjs/dist/i18n/it
//= require system/front
//= require general
//= require shared

////////// INIT  //////////

//######## CONTENT SECTIONS ########//

let loadingSection = $("#loading-sect");
let loginSection = $("#login-sect");

//######## UI COMPONENTS ########//

let logoutButton = $("#logout-btn");
let profileButton = $("#profile-btn");

//######## UI INITIAL SETUP ########//

loginSection.hide();

let authToken = null;
if (authToken != null) {
	loginSection.hide();
} else {
	loginSection.show();
	logoutButton.parent().hide();
	profileButton.parent().hide();
	loadingSection.hide()
}
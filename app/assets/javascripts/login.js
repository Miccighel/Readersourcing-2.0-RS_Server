////////// INIT //////////

//######## CONTENT SECTIONS ########//

let loginForm = $("#login-form");
let successSection = $("#success-sect");
let errorsSection = $("#errors-sect");

//######## UI COMPONENTS ########//

let emailField = $("#email");
let passwordField = $("#password");

let optionsButton = $("#options-btn");
let backButton = $("#back-btn");
let loginButton = $("#login-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");
let alertSuccess = $(".alert-success");

let backIcon = $("#back-icon");
let signInIcon = $("#sign-in-icon");
let reloadIcon = $(".reload-icon");

//######## UI INITIAL SETUP ########//

if (null == null) {
	successSection.hide();
} else {
	successSection.show();
	successSection.find(alertSuccess).append("X");
}

errorsSection.hide();
errorButton.hide();
reloadIcon.hide();
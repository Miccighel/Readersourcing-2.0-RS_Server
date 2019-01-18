////////// INIT  //////////

//######## UI COMPONENTS ########//

let loginButton = $("#login-btn");
let signUpButton = $("#sign-up-btn");

let signInIcon = $("#sign-in-icon");
let signUpIcon = $("#sign-up-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

//######### USER ALREADY LOGGED? HANDLING #########//

let authToken = localStorage.getItem('authToken');
if (authToken != null) {
	window.location.href = "/rate";
} else removePreloader();

//######### GO TO LOGIN HANDLING #########//

loginButton.on("click", () => {
	loginButton.find(signInIcon).toggle();
	loginButton.find(reloadIcons).toggle();
});

//######### GO TO SIGN UP HANDLING #########//

signUpButton.on("click", () => {
	signUpButton.find(signUpIcon.toggle());
	signUpButton.find(reloadIcons).toggle();
});

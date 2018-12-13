////////// INIT  //////////

//######## UI COMPONENTS ########//

let loginButton = $("#login-btn");
let signUpButton = $("#sign-up-btn");

let signUpIcon = $("#sign-up-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

//######### GO TO LOGIN HANDLING #########//

loginButton.on("click", () => {
	loginButton.find(reloadIcons).toggle();
});

//######### GO TO SIGN UP HANDLING #########//

signUpButton.on("click", () => {
	signUpButton.find(signUpIcon.toggle());
	signUpButton.find(reloadIcons).toggle();
});

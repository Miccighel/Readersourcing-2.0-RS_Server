////////// INIT  //////////

//######## UI COMPONENTS ########//

let loginButton = $("#login-btn");
let homeButton = $("#home-btn");

let signInIcon = $("#sign-in-icon");
let homeIcon = $("#home-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

removePreloader();

//######### GO TO LOGIN HANDLING #########//

loginButton.on("click", () => {
	loginButton.find(signInIcon).toggle();
	loginButton.find(reloadIcons).toggle();
});

//######### GO TO HOME HANDLING #########//

homeButton.on("click", () => {
	homeButton.find(homeIcon).toggle();
	homeButton.find(reloadIcons).toggle();
});
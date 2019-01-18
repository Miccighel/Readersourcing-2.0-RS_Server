////////// INIT  //////////

//######## UI COMPONENTS ########//

let loginButton = $("#login-btn");

let signInIcon = $("#sign-in-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

removePreloader();

//######### GO TO LOGIN HANDLING #########//

loginButton.on("click", () => {
	loginButton.find(signInIcon).toggle();
	loginButton.find(reloadIcons).toggle();
});
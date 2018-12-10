////////// INIT  //////////

//######## CONTENT SECTIONS ########//

let loginSection = $("#login-sect");

//######## UI COMPONENTS ########//

let loginButton = $("#login-btn");

let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

//######### GO TO LOGIN HANDLING #########//

loginButton.on("click", () => {
	loginButton.find(reloadIcons).toggle();
});
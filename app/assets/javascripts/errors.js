////////// INIT  //////////

//######## UI COMPONENTS ########//

let goToLoginButton = $("#go-to-login-btn");
let goToHomeButton = $("#go-to-home-btn");

//######## UI INITIAL SETUP ########//

removePreloader();

//######### GO TO LOGIN HANDLING #########//

goToLoginButton.on("click", () => {
	goToLoginButton.find(signInIcons).toggle();
	goToLoginButton.find(reloadIcons).toggle();
});

//######### GO TO HOME HANDLING #########//

goToHomeButton.on("click", () => {
	goToHomeButton.find(homeIcons).toggle();
	goToHomeButton.find(reloadIcons).toggle();
});
////////// INIT  //////////

//######## UI COMPONENTS ########//

let goToHomeButton = $("#go-to-home-btn");

//######## UI INITIAL SETUP ########//

removePreloader();

//######### GO TO HOME HANDLING #########//

goToHomeButton.on("click", () => {
	goToHomeButton.find(homeIcons).toggle();
	goToHomeButton.find(reloadIcons).toggle();
});
////////// INIT  //////////

//######## UI COMPONENTS ########//

let homeButton = $("#home-btn");

let homeIcon = $("#home-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

removePreloader();

//######### GO TO HOME HANDLING #########//

homeButton.on("click", () => {
	homeButton.find(homeIcon).toggle();
	homeButton.find(reloadIcons).toggle();
});
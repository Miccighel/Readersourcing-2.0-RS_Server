////////// INIT  //////////

//######## UI COMPONENTS ########//

let menuLinks = $(".header a");

let homeMenuItem = $("#home-menu-item");
let dashboardMenuItem = $("#dashboard-menu-item");
let itemsMenuItem = $("#items-menu-item");
let aboutMenuItem = $("#about-menu-item");
let userMenuItem = $("#user-menu-item");
let bugMenuItem = $("#bug-menu-item");
let reloadFakeMenuItem = $("#reload-fake-menu-item");

let homeButton = $("#home-btn");
let dashboardButton = $("#dashboard-btn");
let goToPasswordEditButton = $("#go-to-password-edit-btn");
let goToProfileUpdateButton = $("#go-to-profile-update-btn");
let logoutButton = $("#logout-btn");
let loginButton = $("#login-btn");
let signUpButton = $("#sign-up-btn");
let bugButton = $("#bug-btn");

let firstNameValue = $("#first-name-val");
let lastNameValue = $("#last-name-val");
let emailValue = $("#email-val");
let orcidValue = $("#orcid-val");
let subscribeValue = $("#subscribe-val");
let userScoreRSMValue = $("#user-score-rsm-val");
let userScoreTRMValue = $("#user-score-trm-val");

let homeIcons = $(".home-icon");
let pdfIcon = $("#pdf-icon");
let signUpIcons = $(".sign-up-icon");
let signInIcons = $(".sign-in-icon");
let bugIcon = $("#bug-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

homeMenuItem.hide();
dashboardMenuItem.hide();
itemsMenuItem.hide();
aboutMenuItem.hide();
userMenuItem.hide();
signUpButton.hide();
loginButton.hide();
bugMenuItem.hide();

menuLinks.on("click", (event) => event.preventDefault());

let menuSuccessCallback = (data, status, jqXHR) => {
	homeMenuItem.show();
	dashboardMenuItem.show();
	itemsMenuItem.show();
	aboutMenuItem.show();
	userMenuItem.show();
	bugMenuItem.show();
	reloadFakeMenuItem.hide();
};
let menuErrorCallback = (jqXHR, status) => {
	homeMenuItem.show();
	aboutMenuItem.show();
	loginButton.show();
	signUpButton.show();
	bugMenuItem.show();
	reloadFakeMenuItem.hide();
};
menuPromise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, menuSuccessCallback, menuErrorCallback);

////////// USER  //////////

//####### STATUS HANDLING (SCORES, ...) #########//

let authToken = localStorage.getItem('authToken');
if (authToken != null) {
	let successCallback = (data, status, jqXHR) => {
		firstNameValue.text(data["first_name"]);
		lastNameValue.text(data["last_name"]);
		emailValue.text(data["email"]);
		orcidValue.text(data["orcid"]);
		(data["subscribe"]) ? subscribeValue.text("Yes") : subscribeValue.text("No");
		userScoreRSMValue.text((data["score"] * 100).toFixed(2));
		userScoreTRMValue.text((data["bonus"] * 100).toFixed(2));
	};
	let errorCallback = (jqXHR, status) => {
		firstNameValue.text("...");
		firstNameValue.text("...");
		lastNameValue.text("...");
		emailValue.text("...");
		orcidValue.text("...");
		subscribeValue.text("...");
		userScoreRSMValue.text("...");
		userScoreTRMValue.text("...");
	};
	let promise = emptyAjax("POST", "users/info.json", "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
}

//######### GO TO HOME HANDLING #########//

homeButton.on("click", () => {
	homeButton.find(homeIcons).toggle();
	homeButton.find(reloadIcons).toggle();
});

//######### GO TO DASHBOARD HANDLING #########//

dashboardMenuItem.on("click", () => {
	dashboardButton.find(pdfIcon).toggle();
	dashboardButton.find(reloadIcons).toggle();
});

//####### LOGOUT HANDLING #########//

logoutButton.on("click", () => deleteToken().then(() => window.location.href = "/"));

//######### GO TO LOGIN HANDLING #########//

loginButton.on("click", () => {
	loginButton.find(signInIcons).toggle();
	loginButton.find(reloadIcons).toggle();
});

//######### GO TO SIGN UP HANDLING #########//

signUpButton.on("click", () => {
	console.log("hey");
	signUpButton.find(signUpIcons).toggle();
	signUpButton.find(reloadIcons).toggle();
});

//######### BUG REPORT HANDLING #########//

bugButton.on("click", () => {
	bugButton.find(bugIcon).toggle();
	bugButton.find(reloadIcons).toggle();
});


//####### GO TO PASSWORD EDIT HANDLING #########//

goToPasswordEditButton.on("click", () => goToPasswordEditButton.find(reloadIcons).toggle());

//####### GO TO PROFILE UPDATE HANDLING #########//

goToProfileUpdateButton.on("click", () => goToProfileUpdateButton.find(reloadIcons).toggle());
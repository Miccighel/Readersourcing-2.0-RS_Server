////////// INIT  //////////

//######## UI COMPONENTS ########//

let signUpMenuItem = $("#sign-up-menu-item");
let loginMenuItem = $("#login-menu-item");
let logoutMenuItem = $("#logout-menu-item");
let profileMenuItem = $("#profile-menu-item");
let userMenuInfo = $("#user-menu-info");

let homeButton = $("#home-btn");
let logoutButton = $("#logout-btn");
let loginButton = $("#login-btn");
let signUpButton = $("#sign-up-btn");
let goToPasswordEditButton = $("#go-to-password-edit-btn");
let goToProfileUpdateButton = $("#go-to-profile-update-btn");

let firstNameValue = $("#first-name-val");
let lastNameValue = $("#last-name-val");
let emailValue = $("#email-val");
let orcidValue = $("#orcid-val");
let subscribeValue = $("#subscribe-val");
let userScoreRSMValue = $("#user-score-rsm-val");
let userScoreTRMValue = $("#user-score-trm-val");
let publicationScoreRSMValue = $("#publication-score-rsm-val");
let publicationScoreTRMValue = $("#publication-score-trm-val");

let homeIcon = $("#home-icon");
let signUpIcon = $("#sign-up-icon");
let profileIcon = $("#profile-icon");
let signOutIcon = $("#sign-out-icon");
let signInIcon = $("#sign-in-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

signUpMenuItem.hide();
loginMenuItem.hide();
logoutMenuItem.hide();
profileMenuItem.hide();

$(".header a").on("click", (event) => {
	event.preventDefault();
});

let successCallback = (data, status, jqXHR) => {
	signUpMenuItem.hide();
	loginMenuItem.hide();
	profileMenuItem.show();
	logoutMenuItem.show();
	let secondSuccessCallback = (data, status, jqXHR) => {
		userMenuInfo.text(`${data["first_name"]} ${data["last_name"]}`);
	};
	let secondErrorCallback = (jqXHR, status) => {
		userMenuInfo.text("Unknown");
	};
	let promise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, secondSuccessCallback, secondErrorCallback);
};
let errorCallback = (jqXHR, status) => {
	signUpMenuItem.show();
	loginMenuItem.show();
};
menuPromise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, successCallback, errorCallback);

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
	homeButton.find(homeIcon).toggle();
	homeButton.find(reloadIcons).toggle();
});

//####### LOGOUT HANDLING #########//

logoutButton.on("click", () => {
	logoutButton.find(reloadIcons).toggle();
	logoutButton.find(signOutIcon).toggle();
	deleteToken().then(() => window.location.href = "/");
});

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

//####### GO TO PASSWORD EDIT HANDLING #########//

goToPasswordEditButton.on("click", () => {
	goToPasswordEditButton.find(reloadIcons).toggle();
});

//####### GO TO PROFILE UPDATE HANDLING #########//

goToProfileUpdateButton.on("click", () => {
	goToProfileUpdateButton.find(reloadIcons).toggle();
});
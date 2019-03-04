////////// INIT  //////////

//######## UI COMPONENTS ########//

let body = $("body");
let content = $(".content");

let menu = $("#navbar");
let menuLinks = $(".header a");

let homeMenuItem = $("#home-menu-item");
let rateMenuItem = $("#rate-menu-item");
let ratedItemsMenuItem = $("#rated-items-menu-item");
let aboutMenuItem = $("#about-menu-item");
let userMenuItem = $("#user-menu-item");
let bugMenuItem = $("#bug-menu-item");
let reloadFakeMenuItem = $("#reload-fake-menu-item");

let homeButton = $("#home-btn");
let rateButton = $("#rate-btn");
let publicationListButton = $("#publication-list-btn");
let readersListButton = $("#readers-list-btn");
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

let authToken = localStorage.getItem('authToken');
let host = localStorage.getItem('host');

reloadIcons.hide();

homeMenuItem.hide();
rateMenuItem.hide();
ratedItemsMenuItem.hide();
aboutMenuItem.hide();
userMenuItem.hide();
signUpButton.hide();
loginButton.hide();
bugMenuItem.hide();

menuLinks.on("click", (event) => event.preventDefault());

if (authToken != null) {
		let redirected = localStorage['redirected'];
		if (!redirected) {
			localStorage['redirected'] = true;
			window.location.href = "/rate";
		} else {
			homeMenuItem.show();
			rateMenuItem.show();
			ratedItemsMenuItem.show();
			ratedItemsMenuItem.find('ul').addClass("logged");
			aboutMenuItem.show();
			aboutMenuItem.find('ul').addClass("logged");
			userMenuItem.show();
			userMenuItem.find('ul').addClass("logged");
			bugMenuItem.show();
			reloadFakeMenuItem.hide();
			removePreloader()
		}
} else {
	homeMenuItem.show();
	ratedItemsMenuItem.find('ul').removeClass("logged");
	aboutMenuItem.show();
	aboutMenuItem.find('ul').removeClass("logged");
	userMenuItem.find('ul').removeClass("logged");
	loginButton.show();
	signUpButton.show();
	bugMenuItem.show();
	reloadFakeMenuItem.hide();
	removePreloader()

}

////////// MENU //////////

//######### GO TO HOME HANDLING #########//

homeButton.on("click", () => {
	homeButton.find(homeIcons).toggle();
	homeButton.find(reloadIcons).toggle();
});

//######### GO TO RATING HANDLING #########//

rateMenuItem.on("click", () => {
	rateButton.find(pdfIcon).toggle();
	rateButton.find(reloadIcons).toggle();
});

//######### GO TO PUBLICATION LIST HANDLING #########//

rateMenuItem.on("click", () => {
	rateButton.find(pdfIcon).toggle();
	rateButton.find(reloadIcons).toggle();
});

//######### PUBLICATION LIST HANDLING #########//

publicationListButton.on("click", () => {
	let successCallback = (data, status, jqXHR) => {
		content.html(data);
		menu.addClass("bg-gray-dark").find(".nav-item > a:first-child").addClass("color-white");
		menu.find(".active").removeClass("active");
		ratedItemsMenuItem.addClass("active");
		body.removeClass("bg-gray-dark");
		let publicationsTable = $("#publications-table");
		publicationsTable.DataTable({
			dom: 'Bfrtip',
			buttons: [
				'copyHtml5',
				'excelHtml5',
				'csvHtml5',
				'pdfHtml5'
			],
			columnDefs: [
				{"width": "20%", "targets": 1},
				{"width": "20%", "targets": 2},
				{"orderable": false, "targets": 6}
			],
			responsive: true
		});
		removePreloader();
	};
	let errorCallback = (jqXHR, status) => {
		window.location.href = "/unhautorized";
		removePreloader();
	};
	let promise = emptyAjax("POST", "publications/list", "application/json; charset=utf-8", "html", true, successCallback, errorCallback);
});

//######### READERS LIST HANDLING #########//

readersListButton.on("click", () => {
	let successCallback = (data, status, jqXHR) => {
		content.html(data);
		menu.addClass("bg-gray-dark").find(".nav-item > a:first-child").addClass("color-white");
		menu.find(".active").removeClass("active");
		ratedItemsMenuItem.addClass("active");
		body.removeClass("bg-gray-dark");
		let usersTable = $("#users-table");
		usersTable.DataTable({
			dom: 'Bfrtip',
			buttons: [
				'copyHtml5',
				'excelHtml5',
				'csvHtml5',
				'pdfHtml5'
			],
			responsive: true
		});
		removePreloader();
	};
	let errorCallback = (jqXHR, status) => {
		window.location.href = "/unhautorized";
		removePreloader();
	};
	let promise = emptyAjax("POST", "readers/list", "application/json; charset=utf-8", "html", true, successCallback, errorCallback);
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

////////// USER  //////////

//####### STATUS HANDLING (SCORES, ...) #########//

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

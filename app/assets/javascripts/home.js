$(document).on("turbolinks:load", () => {
	////////// USER INTERFACE - GENERAL  //////////

	//######## CONTENT ########//

	let body = $("body");
	let content = $(".content");

	let successSection = $("#success-sect");
	let errorsSection = $(".errors-sect");

	let homePage = $("#home-page");
	let loginPage = $("#login-page");

	//######## MENU ########//

	let menu = $("#navbar");
	let homeMenuItem = $("#home-menu-item");
	let rateMenuItem = $("#rate-menu-item");
	let ratedItemsMenuItem = $("#rated-items-menu-item");
	let aboutMenuItem = $("#about-menu-item");
	let userMenuItem = $("#user-menu-item");
	let loginMenuItem = $("#login-menu-item");
	let signUpMenuItem = $("#sign-up-menu-item");
	let bugMenuItem = $("#bug-menu-item");

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

	//######## PROFILE MODAL ########//

	let firstNameValue = $("#first-name-val");
	let lastNameValue = $("#last-name-val");
	let emailValue = $("#email-val");
	let orcidValue = $("#orcid-val");
	let subscribeValue = $("#subscribe-val");
	let userScoreRSMValue = $("#user-score-rsm-val");
	let userScoreTRMValue = $("#user-score-trm-val");

	//######## ALERTS ########//

	let alert = $(".alert");
	let alertSuccess = $(".alert-success");

	//######## ICONS ########//

	let homeIcons = $(".home-icon");
	let pdfIcon = $("#pdf-icon");
	let signUpIcons = $(".sign-up-icon");
	let signInIcons = $(".sign-in-icon");
	let bugIcon = $("#bug-icon");
	let reloadIcons = $(".reload-icon");

	////////// USER INTERFACE - LOGIN  //////////

	let loginForm = $("#login-form");

	let emailField = $("#email");
	let passwordField = $("#password");

	let doLoginButton = $("#do-login-btn");
	let errorButton = $(".error-btn");

	////////// USER INTERFACE - SETUP //////////

	let authToken = localStorage.getItem('authToken');
	let host = localStorage.getItem('host');
	let message = localStorage.getItem('message');

	if (authToken != null) {
		ratedItemsMenuItem.find('ul').addClass("logged");
		aboutMenuItem.find('ul').addClass("logged");
		userMenuItem.find('ul').addClass("logged");
		signUpMenuItem.hide();
		loginMenuItem.hide();
	} else {
		ratedItemsMenuItem.find('ul').removeClass("logged");
		aboutMenuItem.find('ul').removeClass("logged");
		userMenuItem.find('ul').removeClass("logged");
		rateMenuItem.hide();
		ratedItemsMenuItem.hide();
		userMenuItem.hide();
	}

	reloadIcons.hide();

	errorsSection.hide();
	errorButton.hide();

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

	if (message == null) {
		successSection.hide();
	} else {
		successSection.show();
		successSection.find(alertSuccess).append(message);
		localStorage.removeItem('message')
	}

	////////// FUNCTIONALITIES - MENU   //////////

	//######### PUBLICATION LIST HANDLING #########//

	publicationListButton.on("click", () => {
		let successCallback = (data, status, jqXHR) => {
			content.html(data);
			menu.find(".active").removeClass("active");
			ratedItemsMenuItem.addClass("active");
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
		};
		let errorCallback = (jqXHR, status) => window.location.href = "/unhautorized";
		let promise = emptyAjax("POST", "publications/list", "application/json; charset=utf-8", "html", true, successCallback, errorCallback);
	});

	//######### READERS LIST HANDLING #########//

	readersListButton.on("click", () => {
		let successCallback = (data, status, jqXHR) => {
			content.html(data);
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
		};
		let errorCallback = (jqXHR, status) => window.location.href = "/unhautorized";
		let promise = emptyAjax("POST", "readers/list", "application/json; charset=utf-8", "html", true, successCallback, errorCallback);
	});

	//####### LOGOUT HANDLING #########//

	logoutButton.on("click", () => deleteToken().then(() => window.location.href = "/"));

	////////// FUNCTIONALITIES - LOGIN   //////////

	let validationInstance = loginForm.parsley();

	doLoginButton.on("click", () => {
		if (validationInstance.isValid()) {
			doLoginButton.find(signInIcons).toggle();
			doLoginButton.find(reloadIcons).toggle();
			let data = {email: emailField.val(), password: passwordField.val()};
			let successCallback = (data, status, jqXHR) => {
				//doLoginButton.find(signInIcon).toggle();
				//doLoginButton.find(reloadIcons).toggle();
				localStorage.setItem("authToken", data["auth_token"]);
				window.location.href = "/";
			};
			let errorCallback = (jqXHR, status) => {
				doLoginButton.find(signInIcons).toggle();
				doLoginButton.find(reloadIcons).toggle();
				if (jqXHR.responseText == null) {
					doLoginButton.hide();
					let button = doLoginButton.parent().find(errorButton);
					button.show();
					button.prop("disabled", true)
				} else {
					let errorPromise = buildErrors(jqXHR.responseText).then(result => {
						doLoginButton.parent().find(errorsSection).find(alert).empty();
						doLoginButton.parent().find(errorsSection).find(alert).append(result);
						doLoginButton.parent().find(errorsSection).show();
					});
				}
			};
			// noinspection JSIgnoredPromiseFromCall
			ajax("POST", "authenticate", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
		}
	});

	loginForm.submit(event => event.preventDefault());
});
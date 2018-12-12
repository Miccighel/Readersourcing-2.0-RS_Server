////////// INIT //////////

//######## CONTENT SECTIONS ########//

let registrationForm = $("#sign-up-form");

let errorsSection = $("#errors-sect");

//######## UI COMPONENTS ########//

let firstNameField = $("#first-name");
let lastNameField = $("#last-name");
let emailField = $("#email");
let orcidField = $("#orcid");
let passwordField = $("#password");
let passwordConfirmationField = $("#password-confirmation");

let subscribeCheckbox = $("#subscribe");

let backButton = $("#back-btn");
let registrationButton = $("#sign-up-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");

let backIcon = $("#back-icon");
let signUpIcon = $("#sign-up-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

errorsSection.hide();
errorButton.hide();
reloadIcons.hide();

////////// USER ///////////

//########## REGISTRATION HANDLING ##########//

let validationInstance = registrationForm.parsley();

registrationForm.submit(event => event.preventDefault());

registrationButton.on("click", () => {
	if (validationInstance.isValid()) {
		registrationButton.find(signUpIcon).toggle();
		registrationButton.find(reloadIcons).toggle();
		let data = {
			user: {
				first_name: firstNameField.val(),
				last_name: lastNameField.val(),
				email: emailField.val(),
				orcid: orcidField.val(),
				password: passwordField.val(),
				password_confirmation: passwordConfirmationField.val(),
				subscribe: !!subscribeCheckbox.is(":checked")
			},
		};
		let successCallback = (data, status, jqXHR) => {
			registrationButton.find(reloadIcons).toggle();
			deleteToken().then(() => localStorage.setItem("message", data["message"]), () => window.location.href = "/login");
		};
		let errorCallback = (jqXHR, status) => {
			registrationButton.find(reloadIcons).toggle();
			registrationButton.find(signUpIcon).toggle();
			if (jqXHR.responseText == null) {
				registrationButton.hide();
				let button = registrationButton.parent().find(errorButton);
				button.show();
				button.prop("disabled", true)
			} else {
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					errorsSection.find(alert).empty();
					errorsSection.find(alert).append(result);
					errorsSection.show();
				});
			}
		};
		// noinspection JSIgnoredPromiseFromCall
		ajax("POST", "users.json", "application/json", "json", true, data, successCallback, errorCallback);
	}
});

////////// GENERAL //////////

//########## GO BACK HANDLING #########//

backButton.on("click", () => {
	backButton.find(reloadIcons).toggle();
	backButton.find(backIcon).toggle();
	window.history.back()
});
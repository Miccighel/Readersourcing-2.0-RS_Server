////////// INIT //////////

//######## CONTENT SECTIONS ########//

let signUpForm = $("#sign-up-form");

let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let firstNameField = $("#first-name");
let lastNameField = $("#last-name");
let emailField = $("#email");
let orcidField = $("#orcid");
let passwordField = $("#password");
let passwordConfirmationField = $("#password-confirmation");

let subscribeCheckbox = $("#subscribe");

let doSignUpButton = $("#do-sign-up-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");

//######## UI INITIAL SETUP ########//

errorsSection.hide();
errorButton.hide();

removePreloader();

////////// USER ///////////

//########## REGISTRATION HANDLING ##########//

let validationInstance = signUpForm.parsley();

signUpForm.submit(event => event.preventDefault());

doSignUpButton.on("click", () => {
	if (validationInstance.isValid()) {
		doSignUpButton.find(signUpIcons).toggle();
		doSignUpButton.find(reloadIcons).toggle();
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
			//doSignUpButton.find(reloadIcons).toggle();
			deleteToken().then(() => {
				localStorage.setItem("message", data["message"]);
				window.location.href = "/login";
			});
		};
		let errorCallback = (jqXHR, status) => {
			doSignUpButton.find(reloadIcons).toggle();
			doSignUpButton.find(signUpIcons).toggle();
			if (jqXHR.responseText == null) {
				doSignUpButton.hide();
				let button = doSignUpButton.parent().find(errorButton);
				button.show();
				button.prop("disabled", true)
			} else {
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					doSignUpButton.parent().find(errorsSection).find(alert).empty();
					doSignUpButton.parent().find(errorsSection).find(alert).append(result);
					doSignUpButton.parent().find(errorsSection).show();
				});
			}
		};
		// noinspection JSIgnoredPromiseFromCall
		ajax("POST", "users.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	}
});
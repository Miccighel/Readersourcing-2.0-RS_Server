////////// INIT  //////////

let body = $("body");

//######## CONTENT SECTIONS ########//

let passwordEditForm = $("#password-edit-form");

let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let currentPasswordField = $("#current-password");
let newPasswordField = $("#new-password");
let newPasswordConfirmationField = $("#new-password-confirmation");

let passwordEditButton = $("#password-edit-btn");
let backButton = $("#back-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");

let backIcon = $("#back-icon");
let checkIcon = $("#check-icon");

//######## UI INITIAL SETUP ########//

errorsSection.hide();
errorButton.hide();

let secondSuccessCallback = (data, status, jqXHR) => {
	removePreloader();
};
let secondErrorCallback = (jqXHR, status) => {
	window.location.href = "/unauthorized"
};
let promise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, secondSuccessCallback, secondErrorCallback);

////////// PASSWORD //////////

//######## UPDATE HANDLING ########//

let validationInstance = passwordEditForm.parsley();

passwordEditForm.submit(event => event.preventDefault());

goToPasswordEditButton.on("click", () => {
	validationInstance.validate();
	if (validationInstance.isValid()) {
		passwordEditButton.find(checkIcon).toggle();
		passwordEditButton.find(reloadIcons).toggle();
		let data = {
			current_password: currentPasswordField.val(),
			new_password: newPasswordField.val(),
			new_password_confirmation: newPasswordConfirmationField.val()
		};
		let successCallback = (data, status, jqXHR) => {
			//goToPasswordEditButton.find(reloadIcons).toggle();
			deleteToken().then(() => {
				localStorage.setItem("message", data["message"]);
				window.location.href = "/login";
			});
		};
		let errorCallback = (jqXHR, status) => {
			goToPasswordEditButton.find(checkIcon).toggle();
			goToPasswordEditButton.find(reloadIcons).toggle();
			if (jqXHR.responseText == null) {
				passwordEditButton.hide();
				let button = passwordEditButton.parent().find(errorButton);
				button.show();
				button.prop("disabled", true)
			} else {
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					passwordEditButton.parent().find(errorsSection).find(alert).empty();
					passwordEditButton.parent().find(errorsSection).find(alert).append(result);
					passwordEditButton.parent().find(errorsSection).show();
				});
			}
		};
		// noinspection JSIgnoredPromiseFromCall
		ajax("POST", "update.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	}
});

////////// GENERAL //////////

//########## GO BACK HANDLING #########//

backButton.on("click", () => {
	backButton.find(reloadIcons).toggle();
	backButton.find(backIcon).toggle();
	window.history.back()
});
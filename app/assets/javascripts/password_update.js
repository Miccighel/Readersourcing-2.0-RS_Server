////////// INIT  //////////

let body = $("body");

//######## CONTENT SECTIONS ########//

let passwordEditForm = $("#password-edit-form");

let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let currentPasswordField = $("#current-password");
let newPasswordField = $("#new-password");
let newPasswordConfirmationField = $("#new-password-confirmation");

let doPasswordEditButton = $("#do-password-edit-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");

let checkIcon = $("#check-icon");

//######## UI INITIAL SETUP ########//

errorsSection.hide();
errorButton.hide();

let successCallback = (data, status, jqXHR) => removePreloader();
let errorCallback = (jqXHR, status) => window.location.href = "/unauthorized";
let promise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, successCallback, errorCallback);

////////// PASSWORD //////////

//######## UPDATE HANDLING ########//

let validationInstance = passwordEditForm.parsley();

passwordEditForm.submit(event => event.preventDefault());

doPasswordEditButton.on("click", () => {
	validationInstance.validate();
	if (validationInstance.isValid()) {
		doPasswordEditButton.find(checkIcon).toggle();
		doPasswordEditButton.find(reloadIcons).toggle();
		let data = {
			current_password: currentPasswordField.val(),
			new_password: newPasswordField.val(),
			new_password_confirmation: newPasswordConfirmationField.val()
		};
		let successCallback = (data, status, jqXHR) => {
			//doPasswordEditButton.find(reloadIcons).toggle();
			deleteToken().then(() => {
				localStorage.setItem("message", data["message"]);
				window.location.href = "/login";
			});
		};
		let errorCallback = (jqXHR, status) => {
			goToPasswordEditButton.find(checkIcon).toggle();
			goToPasswordEditButton.find(reloadIcons).toggle();
			if (jqXHR.responseText == null) {
				doPasswordEditButton.hide();
				let button = doPasswordEditButton.parent().find(errorButton);
				button.show();
				button.prop("disabled", true)
			} else {
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					doPasswordEditButton.parent().find(errorsSection).find(alert).empty();
					doPasswordEditButton.parent().find(errorsSection).find(alert).append(result);
					doPasswordEditButton.parent().find(errorsSection).show();
				});
			}
		};
		// noinspection JSIgnoredPromiseFromCall
		ajax("POST", "update.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	}
});
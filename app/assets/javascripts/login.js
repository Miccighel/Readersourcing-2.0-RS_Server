////////// INIT //////////

//######## CONTENT SECTIONS ########//

let loginForm = $("#login-form");
let successSection = $("#success-sect");
let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let emailField = $("#email");
let passwordField = $("#password");

let doLoginButton = $("#do-login-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");
let alertSuccess = $(".alert-success");

//######## UI INITIAL SETUP ########//

let message = localStorage.getItem('message');
if (message == null) {
	successSection.hide();
} else {
	successSection.show();
	successSection.find(alertSuccess).append(message);
	localStorage.removeItem('message')
}

errorsSection.hide();
errorButton.hide();

removePreloader();

//########## LOGIN HANDLING ##########//

let validationInstance = loginForm.parsley();

doLoginButton.on("click", () => {
	if (validationInstance.isValid()) {
		doLoginButton.find(signInIcons).toggle();
		doLoginButton.find(reloadIcons).toggle();
		let data = {email: emailField.val(), password: passwordField.val()};
		let successCallback = (data, status, jqXHR) => {
			//doBugReportButton.find(signInIcon).toggle();
			//doBugReportButton.find(reloadIcons).toggle();
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
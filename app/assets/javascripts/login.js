////////// INIT //////////

//######## CONTENT SECTIONS ########//

let loginForm = $("#login-form");
let successSection = $("#success-sect");
let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let emailField = $("#email");
let passwordField = $("#password");

let backButton = $("#back-btn");
let doLoginButton = $("#do-login-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");
let alertSuccess = $(".alert-success");

let signInIconBody = $("#sign-in-icon-body")
let backIcon = $("#back-icon");

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

//########## GO BACK HANDLING #########//

backButton.on("click", () => {
	backButton.find(reloadIcons).toggle();
	backButton.find(backIcon).toggle();
	window.location.href = "/";
});

//########## LOGIN HANDLING ##########//

let validationInstance = loginForm.parsley();

doLoginButton.on("click", () => {
	if (validationInstance.isValid()) {
		doLoginButton.find(signInIconBody).toggle();
		doLoginButton.find(reloadIcons).toggle();
		let data = {email: emailField.val(), password: passwordField.val()};
		let successCallback = (data, status, jqXHR) => {
			//doLoginButton.find(signInIcon).toggle();
			//doLoginButton.find(reloadIcons).toggle();
			localStorage.setItem("authToken", data["auth_token"]);
			window.location.href = "/";
		};
		let errorCallback = (jqXHR, status) => {
			doLoginButton.find(signInIconBody).toggle();
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
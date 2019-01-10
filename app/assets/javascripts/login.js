////////// INIT //////////

//######## CONTENT SECTIONS ########//

let loginForm = $("#login-form");
let successSection = $("#success-sect");
let errorsSection = $("#errors-sect");

//######## UI COMPONENTS ########//

let emailField = $("#email");
let passwordField = $("#password");

let backButton = $("#back-btn");
let loginButton = $("#login-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");
let alertSuccess = $(".alert-success");

let backIcon = $("#back-icon");
let signInIcon = $("#sign-in-icon");
let reloadIcons = $(".reload-icon");

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
reloadIcons.hide();

//########## GO BACK HANDLING #########//

backButton.on("click", () => {
	backButton.find(reloadIcons).toggle();
	backButton.find(backIcon).toggle();
	window.location.href = "/";
});

//########## LOGIN HANDLING ##########//

let validationInstance = loginForm.parsley();

loginButton.on("click", () => {
	if (validationInstance.isValid()) {
		loginButton.find(signInIcon).toggle();
		loginButton.find(reloadIcons).toggle();
		let data = {email: emailField.val(), password: passwordField.val()};
		let successCallback = (data, status, jqXHR) => {
			loginButton.find(signInIcon).toggle();
			//loginButton.find(reloadIcons).toggle();
			localStorage.setItem("authToken", data["auth_token"]);
			window.location.href = "/rate"
		};
		let errorCallback = (jqXHR, status) => {
			loginButton.find(signInIcon).toggle();
			loginButton.find(reloadIcons).toggle();
			if (jqXHR.responseText == null) {
				loginButton.hide();
				let button = loginButton.parent().find(errorButton);
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
		ajax("POST", "authenticate", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	}
});

loginForm.submit(event => event.preventDefault());
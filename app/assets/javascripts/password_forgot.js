////////// INIT  //////////

//######## CONTENT SECTIONS ########//

let passwordForgotForm = $("#password-forgot-form");

let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let emailField = $("#email");

let backButton = $("#back-btn");
let passwordForgotButton = $("#password-forgot-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");

let backIcon = $("#back-icon");
let checkIcon = $("#check-icon");

//######## UI INITIAL SETUP ########//

errorsSection.hide();
errorButton.hide();

removePreloader();

////////// PASSWORD //////////

//######## FORGOT HANDLING ########//

let validationInstance = passwordForgotForm.parsley();

passwordForgotForm.submit(event => event.preventDefault());

passwordForgotButton.on("click", () => {
	if (validationInstance.isValid()) {
		passwordForgotButton.find(checkIcon).toggle();
		passwordForgotButton.find(reloadIcons).toggle();
		let data = {
			email: emailField.val(),
		};
		let successCallback = (data, status, jqXHR) => {
			//passwordForgotButton.find(reloadIcons).toggle();
			deleteToken().then(() => {
				localStorage.setItem("message", data["message"]);
				window.location.href = "/login";
			});
		};
		let errorCallback = (jqXHR, status) => {
			passwordForgotButton.find(checkIcon).toggle();
			passwordForgotButton.find(reloadIcons).toggle();
			if (jqXHR.responseText == null) {
				passwordForgotButton.hide();
				let button = passwordForgotButton.parent().find(errorButton);
				button.show();
				button.prop("disabled", true)
			} else {
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					passwordForgotButton.parent().find(errorsSection).find(alert).empty();
					passwordForgotButton.parent().find(errorsSection).find(alert).append(result);
					passwordForgotButton.parent().find(errorsSection).show();
				});
			}
		};
		// noinspection JSIgnoredPromiseFromCall
		ajax("POST", "forgot.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	}
});

////////// GENERAL //////////

//########## GO BACK HANDLING #########//

backButton.on("click", () => {
	backButton.find(reloadIcons).toggle();
	backButton.find(backIcon).toggle();
	window.location.href = "/login.html";
});
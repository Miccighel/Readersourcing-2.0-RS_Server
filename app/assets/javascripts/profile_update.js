////////// INIT //////////

let body = $("body");

//######## CONTENT SECTIONS ########//

let signUpForm = $("#sign-up-form");

let errorsSection = $("#errors-sect");

//######## UI COMPONENTS ########//

let firstNameField = $("#first-name");
let lastNameField = $("#last-name");
let orcidField = $("#orcid");

let subscribeCheckbox = $("#subscribe");

let backButton = $("#back-btn");
let updateButton = $("#update-btn");
let errorButton = $(".error-btn");

let alert = $(".alert");

let backIcon = $("#back-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

errorsSection.hide();
errorButton.hide();
reloadIcons.hide();

let validationInstance = signUpForm.parsley();

signUpForm.submit(event => event.preventDefault());

let successCallback = (data, status, jqXHR) => {
	////////// USER ///////////

	//####### STATUS HANDLING (SCORES, ...) #########//

	let authToken = localStorage.getItem('authToken');

	if (authToken != null) {
		let successCallback = (data, status, jqXHR) => {
			firstNameField.val(data["first_name"]);
			lastNameField.val(data["last_name"]);
			orcidField.val(data["orcid"]);
			(data["subscribe"]) === true ? subscribeCheckbox.prop('checked', true) : subscribeCheckbox.prop('checked', false);
		};
		let errorCallback = (jqXHR, status) => {
			firstNameField.val();
			lastNameField.val();
			orcidField.val();
			subscribeCheckbox.prop('checked', false);
		};
		let promise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
	}
};
let errorCallback = (jqXHR, status) => {
	window.location.href = "/unauthorized"
};
let promise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, successCallback, errorCallback);

//########## UPDATE HANDLING ##########//

let authToken = localStorage.getItem('authToken');
if (authToken != null) {
	updateButton.on("click", () => {
		validationInstance.validate();
		if (validationInstance.isValid()) {
			updateButton.find(checkIcon).toggle();
			updateButton.find(reloadIcons).toggle();
			let successCallback = (data, status, jqXHR) => {
				let secondData = {
					user: {
						first_name: firstNameField.val(),
						last_name: lastNameField.val(),
						orcid: orcidField.val(),
						subscribe: !!subscribeCheckbox.is(":checked")
					},
				};
				if (orcidField.val() === "")
					delete secondData.user.orcid;
				let secondSuccessCallback = (data, status, jqXHR) => {
					//updateButton.find(reloadIcons).toggle();
					deleteToken().then(() => {
						localStorage.setItem("message", data["message"]);
						window.location.href = "/login";
					});
				};
				let secondErrorCallback = (jqXHR, status) => {
					updateButton.find(reloadIcons).toggle();
					updateButton.find(checkIcon).toggle();
					if (jqXHR.responseText == null) {
						updateButton.hide();
						let button = updateButton.parent().find(errorButton);
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
				let secondPromise = ajax("PUT", `/users/${data["id"]}.json`, "application/json; charset=utf-8", "json", true, secondData, secondSuccessCallback, secondErrorCallback);
			};
			let errorCallback = (jqXHR, status) => {
				updateButton.find(reloadIcons).toggle();
				updateButton.find(checkIcon).toggle();
				if (jqXHR.responseText == null) {
					updateButton.hide();
					let button = updateButton.parent().find(errorButton);
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
			let promise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
		}
	});
}

////////// GENERAL //////////

//########## GO BACK HANDLING #########//

backButton.on("click", () => {
	backButton.find(reloadIcons).toggle();
	backButton.find(backIcon).toggle();
	window.history.back()
});
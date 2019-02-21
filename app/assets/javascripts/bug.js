////////// INIT //////////

//######## CONTENT SECTIONS ########//

let bugForm = $("#bug-form");
let successSection = $("#success-sect");
let errorsSection = $(".errors-sect");

//######## UI COMPONENTS ########//

let emailField = $("#email");
let messageField = $("#message");

let doBugReportButton = $("#do-bug-btn");
let errorButton = $(".error-btn");

let messageIcon = $("#message-icon");

let alert = $(".alert");
let alertSuccess = $(".alert-success");

//######## UI INITIAL SETUP ########//

successSection.hide();
errorsSection.hide();
errorButton.hide();

removePreloader();

//########## BUG REPORT HANDLING ##########//

let validationInstance = bugForm.parsley();

doBugReportButton.on("click", () => {
	if (validationInstance.isValid()) {
		doBugReportButton.find(messageIcon).toggle();
		doBugReportButton.find(reloadIcons).toggle();
		let data = {email: emailField.val(), message: messageField.val()};
		let successCallback = (data, status, jqXHR) => {
			doBugReportButton.text("Bug Report Sent!");
			doBugReportButton.prop("disabled", true);
			successSection.show();
			successSection.find(alertSuccess).append(data["message"]);
		};
		let errorCallback = (jqXHR, status) => {
			doBugReportButton.find(messageIcon).toggle();
			doBugReportButton.find(reloadIcons).toggle();
			if (jqXHR.responseText == null) {
				doBugReportButton.hide();
				let button = doBugReportButton.parent().find(errorButton);
				button.show();
				button.prop("disabled", true)
			} else {
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					doBugReportButton.parent().find(errorsSection).find(alert).empty();
					doBugReportButton.parent().find(errorsSection).find(alert).append(result);
					doBugReportButton.parent().find(errorsSection).show();
				});
			}
		};
		// noinspection JSIgnoredPromiseFromCall
		ajax("POST", "report", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	}
});

bugForm.submit(event => event.preventDefault());
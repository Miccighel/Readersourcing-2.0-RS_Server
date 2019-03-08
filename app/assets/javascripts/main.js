$(document).on("ready", () => {
	Dropzone.autoDiscover = false;
});

$(document).on("turbolinks:load", () => {

	////////// USER INTERFACE - GENERAL  //////////

	//######## SECTIONS ########//

	let successSection = $("#success-sect");
	let errorsSection = $(".errors-sect");

	//######## MENU ########//

	let menu = $("#navbar");
	let homeMenuItem = $("#home-menu-item");
	let rateMenuItem = $("#rate-menu-item");
	let ratedItemsMenuItem = $("#rated-items-menu-item");
	let aboutMenuItem = $("#about-menu-item");
	let userMenuItem = $("#user-menu-item");
	let loginMenuItem = $("#login-menu-item");
	let signUpMenuItem = $("#sign-up-menu-item");
	let bugMenuItem = $("#bug-menu-item");

	let homeButton = $("#home-btn");
	let rateButton = $("#rate-btn");
	let publicationListButton = $("#publication-list-btn");
	let readersListButton = $("#readers-list-btn");
	let goToPasswordEditButton = $("#go-to-password-edit-btn");
	let goToProfileUpdateButton = $("#go-to-profile-update-btn");
	let logoutButton = $("#logout-btn");
	let loginButton = $("#login-btn");
	let signUpButton = $("#sign-up-btn");
	let bugButton = $("#bug-btn");

	//######## PROFILE MODAL ########//

	let firstNameValue = $("#first-name-val");
	let lastNameValue = $("#last-name-val");
	let emailValue = $("#email-val");
	let orcidValue = $("#orcid-val");
	let subscribeValue = $("#subscribe-val");
	let userScoreRSMValue = $("#user-score-rsm-val");
	let userScoreTRMValue = $("#user-score-trm-val");

	//######## ALERTS ########//

	let alert = $(".alert");
	let alertSuccess = $(".alert-success");

	//######## ICONS ########//

	let homeIcons = $(".home-icon");
	let pdfIcon = $("#pdf-icon");
	let signUpIcons = $(".sign-up-icon");
	let signInIcons = $(".sign-in-icon");
	let bugIcon = $("#bug-icon");
	let reloadIcons = $(".reload-icon");

	////////// USER INTERFACE - LOGIN  //////////

	let loginForm = $("#login-form");

	let emailField = $("#email");
	let passwordField = $("#password");

	let doLoginButton = $("#do-login-btn");
	let errorButtons = $(".error-btn");

	////////// USER INTERFACE - SIGN UP  //////////

	let signUpForm = $("#sign-up-form");

	let firstNameField = $("#first-name");
	let lastNameField = $("#last-name");
	// let emailField = $("#email");
	let orcidField = $("#orcid");
	// let passwordField = $("#password");
	let passwordConfirmationField = $("#password-confirmation");
	let subscribeCheckbox = $("#subscribe");
	let doSignUpButton = $("#do-sign-up-btn");

	////////// USER INTERFACE - PASSWORD FORGOT  //////////

	let passwordForgotForm = $("#password-forgot-form");

	//let emailField = $("#email");

	let passwordForgotButton = $("#password-forgot-btn");
	//let errorButton = $(".error-btn");

	//let alert = $(".alert");

	let checkIcon = $("#check-icon");

	////////// USER INTERFACE - BUG  //////////

	let bugForm = $("#bug-form");
	//let successSection = $("#success-sect");
	//let errorsSection = $(".errors-sect");

	//let emailField = $("#email");
	let messageField = $("#message");

	let doBugReportButton = $("#do-bug-btn");
	//let errorButton = $(".error-btn");

	let messageIcon = $("#message-icon");

	//let alert = $(".alert");
	//let alertSuccess = $(".alert-success");

	////////// USER INTERFACE - RATING WEB  //////////

	let body = $("body");

	//######## SECTIONS ########//

	let ratingSection = $("#rating-sect");
	let ratingSectionSubControls = $(".rating-sect-sub");
	let undetectedPublicationSection = $("#undetected-publication-sect");
	let undetectedPublicationDetails = $(".undetected-publication-details");
	//let errorsSection = $(".errors-sect");
	let loadingSection = $("#loading-sect");

	//######## MODALS ########//

	let modalConfigure = $("#modal-configuration");
	let modalRefresh = $("#modal-refresh");
	let modalAllow = $("#modal-allow");

	//######## UI COMPONENTS ########//

	let rateForm = $("#rate-form");

	let loadRateButton = $("#load-rate-btn");
	let voteButton = $("#vote-btn");
	let voteSuccessButton = $("#vote-success-btn");
	let configureButton = $("#configure-btn");
	let configureSaveButton = $("#configuration-save-btn");
	let loadSaveButton = $("#load-save-btn");
	let saveButton = $("#save-btn");
	let downloadButton = $("#download-btn");
	let refreshButton = $("#refresh-btn");
	let reloadButton = $("#reload-btn");
	let goToRatingButton = $("#go-to-rating-btn");
	let modalRefreshButton = $("#modal-refresh-btn");
	let modalAllowButton = $("#modal-allow-btn");

	//let alert = $(".alert");

	let publicationUrlField = $("#publication-url");

	let annotatedPublicationDropzone = $("#annotated-publication-dropzone");
	let annotatedPublicationDropzoneSuccess = $("#dropzone-success");
	let annotatedPublicationDropzoneError = $("#dropzone-error");

	let ratingInfo = $("#rating-info");
	let ratingCaption = $("#rating-caption");
	let ratingSubCaption = $("#rating-subcaption");
	let ratingSlider = $("#rating-slider");

	let ratingText = $("#rating-text");

	let buttonsCaption = $("#buttons-caption");

	let anonymizeCheckbox = $("#anonymize-check");

	let goToRatingIcon = $("#go-to-rating-icon");

	////////// USER INTERFACE - RATING PAPER  //////////

	let ratePaperForm = $("#new_rating");

	let votePaperButton = $("#vote-paper-btn");

	//let ratingSlider = $("#rating-slider");

	//let ratingText = $("#rating-text");

	let authTokenUserField = $("#authTokenUser");

	////////// USER INTERFACE - PASSWORD UPDATE  //////////

	let passwordEditForm = $("#password-edit-form");

	//let errorsSection = $(".errors-sect");

	let currentPasswordField = $("#current-password");
	let newPasswordField = $("#new-password");
	let newPasswordConfirmationField = $("#new-password-confirmation");

	let doPasswordEditButton = $("#do-password-edit-btn");
	//let errorButton = $(".error-btn");

	//let alert = $(".alert");

	//let checkIcon = $("#check-icon");

	////////// USER INTERFACE - PROFILE UPDATE  //////////

	let profileUpdatePage = $("#profile-update-page");

	//let signUpForm = $("#sign-up-form");

	//let errorsSection = $(".errors-sect");

	//let firstNameField = $("#first-name");
	//let lastNameField = $("#last-name");
	//let orcidField = $("#orcid");

	//let subscribeCheckbox = $("#subscribe");

	let backButton = $("#back-btn");
	let updateButton = $("#update-btn");
	//let errorButton = $(".error-btn");

	//let alert = $(".alert");

	//let checkIcon = $("#check-icon");

	////////// USER INTERFACE - SUCCESS, ERRORS & HALTED  //////////

	let goToHomeButton = $("#go-to-home-btn");
	let goToLoginButton = $("#go-to-login-btn");

	////////// USER INTERFACE - SETUP //////////

	//######### GENERAL #########//

	let authToken = localStorage.getItem('authToken');
	let message = localStorage.getItem('message');

	reloadIcons.hide();

	successSection.hide();
	errorsSection.hide();
	errorButtons.hide();

	if (authToken != null) {
		ratedItemsMenuItem.find('ul').addClass("logged");
		aboutMenuItem.find('ul').addClass("logged");
		userMenuItem.find('ul').addClass("logged");
		signUpMenuItem.hide();
		loginMenuItem.hide();
		let link = publicationListButton.attr("href");
		publicationListButton.attr("href", `${link}${authToken}`);
		link = readersListButton.attr("href");
		readersListButton.attr("href", `${link}${authToken}`);
		link = rateButton.attr("href");
		rateButton.attr("href", `${link}${authToken}`);
		link = goToPasswordEditButton.attr("href");
		goToPasswordEditButton.attr("href", `${link}${authToken}`);
		link = goToProfileUpdateButton.attr("href");
		goToProfileUpdateButton.attr("href", `${link}${authToken}`);
	} else {
		ratedItemsMenuItem.find('ul').removeClass("logged");
		aboutMenuItem.find('ul').removeClass("logged");
		userMenuItem.find('ul').removeClass("logged");
		rateMenuItem.hide();
		ratedItemsMenuItem.hide();
		userMenuItem.hide();
	}

	if (authToken != null) {
		let successCallback = (data, status, jqXHR) => {
			firstNameValue.text(data["first_name"]);
			lastNameValue.text(data["last_name"]);
			emailValue.text(data["email"]);
			orcidValue.text(data["orcid"]);
			(data["subscribe"]) ? subscribeValue.text("Yes") : subscribeValue.text("No");
			userScoreRSMValue.text((data["score"] * 100).toFixed(2));
			userScoreTRMValue.text((data["bonus"] * 100).toFixed(2));
		};
		let errorCallback = (jqXHR, status) => {
			firstNameValue.text("...");
			firstNameValue.text("...");
			lastNameValue.text("...");
			emailValue.text("...");
			orcidValue.text("...");
			subscribeValue.text("...");
			userScoreRSMValue.text("...");
			userScoreTRMValue.text("...");
		};
		let promise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
	}

	if (message == null) {
		successSection.hide();
	} else {
		successSection.show();
		successSection.find(alertSuccess).append(message);
		localStorage.removeItem('message')
	}

	//######### RATING WEB #########//

	downloadButton.hide();
	refreshButton.hide();
	saveButton.hide();
	loadRateButton.show();
	loadSaveButton.show();
	voteButton.hide();
	configureButton.hide();
	voteSuccessButton.hide();
	//errorButtons.hide();
	ratingCaption.hide();
	ratingSubCaption.hide();
	undetectedPublicationSection.hide();
	loadingSection.hide();
	ratingText.show();
	ratingSection.show();
	ratingSectionSubControls.hide();
	annotatedPublicationDropzoneSuccess.hide();
	annotatedPublicationDropzoneError.hide();
	goToRatingButton.hide();
	errorsSection.hide();

	Dropzone.autoDiscover = false;

	//######### RATING PAPER #########//

	ratingText.text("50");
	ratingSlider.slider({});

	if (authToken != null) authTokenUserField.val(authToken);

	//######### PROFILE UPDATE #########//

	if (profileUpdatePage.is(":visible")) {

		firstNameField.hide();
		lastNameField.hide();
		orcidField.hide();
		subscribeCheckbox.hide();
		backButton.find(reloadIcons).hide();
		updateButton.find(reloadIcons).hide();

		updateButton.prop("disabled", true);

		signUpForm.submit(event => event.preventDefault());

		if (authToken != null) {
			let thirdSuccessCallback = (data, status, jqXHR) => {
				firstNameField.val(data["first_name"]);
				firstNameField.show();
				firstNameField.parent().parent().find(reloadIcons).hide();
				lastNameField.val(data["last_name"]);
				lastNameField.show();
				lastNameField.parent().parent().find(reloadIcons).hide();
				orcidField.val(data["orcid"]);
				orcidField.show();
				orcidField.parent().parent().find(reloadIcons).hide();
				(data["subscribe"]) === true ? subscribeCheckbox.prop('checked', true) : subscribeCheckbox.prop('checked', false);
				subscribeCheckbox.show();
				subscribeCheckbox.parent().parent().find(reloadIcons).hide();
				updateButton.prop("disabled", false);
				removePreloader();
			};
			let thirdErrorCallback = (jqXHR, status) => {
				firstNameField.val();
				lastNameField.val();
				orcidField.val();
				subscribeCheckbox.prop('checked', false);
				updateButton.prop("disabled", false);
				removePreloader();
			};
			let thirdPromise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, thirdSuccessCallback, thirdErrorCallback);
		}
	}

	////////// FUNCTIONALITIES - MENU   //////////

	//####### LOGOUT HANDLING #########//

	logoutButton.on("click", () => deleteToken().then(() => window.location.href = "/"));

	////////// FUNCTIONALITIES - LOGIN   //////////

	doLoginButton.on("click", () => {
		let validationInstance = loginForm.parsley();
		if (validationInstance.isValid()) {
			doLoginButton.find(signInIcons).toggle();
			doLoginButton.find(reloadIcons).toggle();
			let data = {email: emailField.val(), password: passwordField.val()};
			let successCallback = (data, status, jqXHR) => {
				//doLoginButton.find(signInIcon).toggle();
				//doLoginButton.find(reloadIcons).toggle();
				localStorage.setItem("authToken", data["auth_token"]);
				window.location.href = "/";
			};
			let errorCallback = (jqXHR, status) => {
				doLoginButton.find(signInIcons).toggle();
				doLoginButton.find(reloadIcons).toggle();
				if (jqXHR.responseText == null) {
					doLoginButton.hide();
					let button = doLoginButton.parent().find(errorButtons);
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
			ajax("POST", "/authenticate", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
		}
	});

	loginForm.submit(event => event.preventDefault());

	////////// FUNCTIONALITIES - SIGN UP   //////////

	//########## SIGN UP HANDLING ##########//

	signUpForm.submit(event => event.preventDefault());

	doSignUpButton.on("click", () => {
		let validationInstance = signUpForm.parsley();
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
					let button = doSignUpButton.parent().find(errorButtons);
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
			ajax("POST", "/users.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
		}
	});

	////////// FUNCTIONALITIES - PASSWORD FORGOT   //////////

	//######## FORGOT HANDLING ########//

	passwordForgotForm.submit(event => event.preventDefault());

	passwordForgotButton.on("click", () => {
		let validationInstance = passwordForgotForm.parsley();
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
					let button = passwordForgotButton.parent().find(errorButtons);
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
			ajax("POST", "/password/forgot.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
		}
	});

	////////// FUNCTIONALITIES - BUG   //////////

	//########## BUG REPORT HANDLING ##########//

	doBugReportButton.on("click", () => {
		let validationInstance = bugForm.parsley();
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
					let button = doBugReportButton.parent().find(errorButtons);
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

	////////// FUNCTIONALITIES - RATING WEB   //////////

	////////// PUBLICATION //////////

	//#########  STATUS HANDLING (EXISTS ON THE DB, RATED BY THE LOGGED IN USER, SAVED FOR LATER...) #########//

	authToken = localStorage.getItem('authToken');
	if (authToken != null) {
		publicationUrlField.change(() => {
			let validationInstance = rateForm.parsley();
			validationInstance.validate();
			if (validationInstance.isValid()) {
				ratingSection.hide();
				loadingSection.show();
				let currentUrl = publicationUrlField.val();
				if (currentUrl !== "") {
					let data = {
						publication: {
							pdf_url: currentUrl
						}
					};
					// data ---> secondData because of visibility clash with "lookup" call.
					let successCallback = (secondData, status, jqXHR) => {
						// 1.2 Publication exists, so it may be rated by the user
						let successCallback = (data, status, jqXHR) => {
							// 2.2 Publication has been rated by the user, so it is not necessary to check if it has been annotated
							let secondSuccessCallback = (data, status, jqXHR) => {
								validationInstance.reset();
								loadRateButton.hide();
								loadSaveButton.hide();
								voteButton.hide();
								configureButton.hide();
								downloadButton.hide();
								refreshButton.hide();
								saveButton.hide();
								ratingSection.show();
								ratingSectionSubControls.show();
								buttonsCaption.hide();
								loadingSection.hide();
								voteSuccessButton.show();
								voteSuccessButton.prop("disabled", true);
								ratingText.parent().removeClass("mt-3");
								ratingCaption.hide();
								ratingInfo.hide();
								ratingSubCaption.show();
								ratingSlider.slider('destroy');
								ratingSlider.hide();
								ratingText.text(data["score"]);
							};
							// 2.3 Publication has not been rated by the user
							let secondErrorCallback = (jqXHR, status) => {
								loadingSection.hide();
								loadRateButton.hide();
								voteSuccessButton.hide();
								ratingSubCaption.hide();
								ratingInfo.hide();
								ratingSection.show();
								ratingSectionSubControls.show();
								loadingSection.hide();
								buttonsCaption.show();
								ratingCaption.show();
								ratingText.text("50");
								ratingSlider.slider({});
								voteButton.show();
								configureButton.show();
								// 3.1 The rated publication was also annotated
								let thirdSuccessCallback = (data, status, jqXHR) => {
									loadSaveButton.hide();
									saveButton.hide();
									downloadButton.show();
									downloadButton.attr("href", data["pdf_download_url_link"]);
									refreshButton.show();
								};
								// 3.2 The rated publication was not annotated
								let thirdErrorCallback = (jqXHR, status) => {
									loadSaveButton.hide();
									downloadButton.hide();
									refreshButton.hide();
									saveButton.show();
								};
								// 3.1 Does the rated publication has been already annotated?
								let thirdPromise = emptyAjax("GET", `/publications/${data["id"]}/is_saved_for_later.json`, "application/json; charset=utf-8", "json", true, thirdSuccessCallback, thirdErrorCallback);
							};
							// 2.1 Does the publication has been rated by the logged user?
							let secondPromise = emptyAjax("GET", `/publications/${data["id"]}/is_rated.json`, "application/json; charset=utf-8", "json", true, secondSuccessCallback, secondErrorCallback);
						};
						// 1.3 Publication was never rated, so it does not exists on the database
						let errorCallback = (jqXHR, status) => {
							loadingSection.hide();
							loadRateButton.hide();
							loadSaveButton.hide();
							voteSuccessButton.hide();
							ratingSection.show();
							ratingSectionSubControls.show();
							saveButton.show();
							configureButton.show();
							voteButton.show();
							ratingCaption.show();
							ratingInfo.hide();
							ratingSubCaption.hide();
							ratingText.text("50");
							ratingSlider.slider({});
							ratingSlider.on("slide", slideEvt => ratingText.text(slideEvt.value));
						};
						// 1.1 Does the publication exists on the database?
						let promise = ajax("POST", "/publications/lookup.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
					};
					let errorCallback = (jqXHR, status) => {
						ratingSection.hide();
						ratingSectionSubControls.hide();
						let errorPromise = buildErrors(jqXHR.responseText).then(result => {
							undetectedPublicationDetails.parent().find(errorsSection).find(alert).empty();
							undetectedPublicationDetails.parent().find(errorsSection).find(alert).append(result);
							undetectedPublicationDetails.parent().find(errorsSection).show();
							undetectedPublicationSection.show();
							loadingSection.hide()
						});
					};
					let promise = ajax("POST", "/publications/is_fetchable.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
				}
			}
		});
	}

	//########## RELOAD HANDLING #########//

	authToken = localStorage.getItem('authToken');
	if (authToken != null) {
		reloadButton.on("click", () => {
			undetectedPublicationSection.hide();
			ratingSection.show();
		});
	}

	//######### SAVE FOR LATER HANDLING #########//

	authToken = localStorage.getItem('authToken');
	if (authToken != null) {
		saveButton.on("click", () => {
			validationInstance.validate();
			if (validationInstance.isValid()) {
				let currentUrl = publicationUrlField.val();
				let data = {
					publication: {
						pdf_url: currentUrl
					}
				};
				saveButton.find('span').text("Downloading...");
				saveButton.find(reloadIcons).toggle();
				// 1.2 Publication fetched, hide save for later button and show the download one
				let successCallback = (data, status, jqXHR) => {
					saveButton.find(reloadIcons).toggle();
					saveButton.hide();
					downloadButton.show();
					downloadButton.attr("href", data["pdf_download_url_link"]);
					refreshButton.show();
					let pdfWindow = window.open(data["pdf_download_url_link"], '_blank');
					if (pdfWindow) {
						pdfWindow.focus();
					} else {
						modalAllow.modal('show');
					}
				};
				// 1.3 Error during publication fetching, hide save for later and download buttons
				let errorCallback = (jqXHR, status) => {
					saveButton.find(reloadIcons).toggle();
					saveButton.hide();
					let errorButton = saveButton.parent().find(errorButtons);
					errorButton.show();
					errorButton.prop("disabled", true);
					let errorPromise = buildErrors(jqXHR.responseText).then(result => {
						saveButton.parent().find(errorsSection).find(alert).empty();
						saveButton.parent().find(errorsSection).find(alert).append(result);
						saveButton.parent().find(errorsSection).show();
					});
				};
				// 1.1 Fetch and annotate the publication
				let promise = ajax("POST", "/publications/fetch.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
			}
		});
	}

	modalAllowButton.on("click", () => {
		modalAllow.modal('hide')
	});

	//######### EXTRACT HANDLING #########//

	if (annotatedPublicationDropzone.is(":visible")) {

		$('.dropzone').each(function () {
			let dropzoneControl = $(this)[0].dropzone;
			if (dropzoneControl) {
				dropzoneControl.destroy();
			}
		});

		Dropzone.options.annotatedPublicationDropzone = {
			paramName: "file", // The name that will be used to transfer the file
			acceptedFiles: "application/pdf",
			maxFiles: 1,
			headers: {
				"Authorization": authToken
			}
		};

		annotatedPublicationDropzone = new Dropzone("#annotated-publication-dropzone");

		authToken = localStorage.getItem('authToken');
		if (authToken != null) {
			annotatedPublicationDropzone.on("sending", (file, xhr, formData) => xhr.setRequestHeader("Authorization", authToken));
			annotatedPublicationDropzone.on("success", (file, data) => {
				annotatedPublicationDropzoneSuccess.show();
				annotatedPublicationDropzoneSuccess.text(data["message"]);
				goToRatingButton.show();
				goToRatingButton.prop("href", data["baseUrl"]);
				let ratingPageWindow = window.open(data["baseUrl"], '_blank');
				if (ratingPageWindow) {
					ratingPageWindow.focus();
				} else {
					modalAllow.modal('show');
				}
			});
			annotatedPublicationDropzone.on('error', (file, response, xhr) => {
				if (response.hasOwnProperty('errors')) annotatedPublicationDropzoneError.text(response["errors"][0]); else annotatedPublicationDropzoneError.text(response)
				annotatedPublicationDropzoneError.show();
			});
		}
	}

	///######### REFRESH HANDLING #########//

	modalRefreshButton.click(event => event.preventDefault());

	modalRefresh.on('show.bs.modal', function (e) {
		validationInstance.validate();
		if (!validationInstance.isValid()) {
			e.stopPropagation();
		}
	});

	refreshButton.on("click", () => {
		modalRefresh.modal("show");
	});

	modalRefreshButton.on("click", () => {
		modalRefresh.modal("hide");
		downloadButton.hide();
		refreshButton.hide();
		loadSaveButton.find('span').text("Downloading...");
		loadSaveButton.show();
		let currentUrl = publicationUrlField.val();
		let data = {
			publication: {
				pdf_url: currentUrl
			}
		};
		// 1.2 Publication exists, so it is safe to refresh it
		let successCallback = (data, status, jqXHR) => {
			// 2.2 Publication refreshed, so it it safe to show the download button
			let secondSuccessCallback = (data, status, jqXHR) => {
				loadSaveButton.hide();
				downloadButton.show();
				downloadButton.attr("href", data["pdf_download_url_link"]);
				refreshButton.show();
				let pdfWindow = window.open(data["pdf_download_url_link"], '_blank');
				if (pdfWindow) {
					pdfWindow.focus();
				} else {
					modalAllow.modal('show');
				}
			};
			// 2.3 Error during publication refresh, it is not safe to show the download button
			let secondErrorCallback = (jqXHR, status) => {
				loadSaveButton.hide();
				let errorButton = downloadButton.parent().find(errorButtons);
				errorButton.show();
				errorButton.prop("disabled", true);
				let errorPromise = buildErrors(jqXHR.responseText).then(result => {
					loadSaveButton.parent().find(errorsSection).find(alert).empty();
					loadSaveButton.parent().find(errorsSection).find(alert).append(result);
					loadSaveButton.parent().find(errorsSection).show();
				});
			};
			// 2.1 Refresh the publication
			let secondPromise = emptyAjax("GET", `/publications/${data["id"]}/refresh.json`, "application/json; charset=utf-8", "json", true, secondSuccessCallback, secondErrorCallback);
		};
		// 1.3 Publication was never rated, so it does not exists on the database
		let errorCallback = function (jqXHR, status) {
			loadSaveButton.hide();
			let errorButton = downloadButton.parent().find(errorButtons);
			errorButton.show();
			errorButton.prop("disabled", true);
			let errorPromise = buildErrors(jqXHR.responseText).then(result => {
				loadSaveButton.parent().find(errorsSection).find(alert).empty();
				loadSaveButton.parent().find(errorsSection).find(alert).append(result);
				loadSaveButton.parent().find(errorsSection).show();
			});
		};
		// 1.1 Does the publication exists on the database?
		let promise = ajax("POST", "/publications/lookup.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
	});

	////////// RATING //////////

	//#######  SLIDER HANDLING #########//

	ratingSlider.on("slide", slideEvt => ratingText.text(slideEvt.value));

	//#######  ACTION HANDLING #########//

	let validationInstance = rateForm.parsley();

	rateForm.submit(event => event.preventDefault());

	authToken = localStorage.getItem('authToken');
	if (authToken != null) {
		voteButton.on("click", () => {
			validationInstance.validate();
			if (validationInstance.isValid()) {
				let currentUrl = publicationUrlField.val();
				voteButton.find(reloadIcons).toggle();
				let score = ratingSlider.val();
				let data = {
					rating: {
						score: score,
						pdf_url: currentUrl,
						anonymous: anonymizeCheckbox.is(':checked')
					}
				};
				// 1.2 Rating created successfully
				let successCallback = (data, status, jqXHR) => {
					let secondData = {
						publication: {
							pdf_url: currentUrl
						}
					};
					let secondSuccessCallback = (data, status, jqXHR) => {
						voteButton.find(reloadIcons).toggle();
						voteButton.hide();
						configureButton.hide();
						buttonsCaption.hide();
						downloadButton.hide();
						saveButton.hide();
						refreshButton.hide();
						ratingCaption.hide();
						ratingSlider.slider('destroy');
						ratingSlider.hide();
						ratingText.parent().removeClass("mt-3");
						ratingSubCaption.show();
						voteSuccessButton.show();
						voteSuccessButton.prop("disabled", true);
					};
					let secondErrorCallback = (jqXHR, status) => {
						voteButton.find(reloadIcons).toggle();
						voteButton.hide();
						configureButton.hide();
						voteSuccessButton.show();
						voteSuccessButton.prop("disabled", true);
					};
					let secondPromise = ajax("POST", "/publications/lookup.json", "application/json; charset=utf-8", "json", true, secondData, secondSuccessCallback, secondErrorCallback);
					let thirdSuccessCallback = (data, status, jqXHR) => {
						userScoreRSMValue.text((data["score"] * 100).toFixed(2));
						userScoreTRMValue.text((data["bonus"] * 100).toFixed(2));
					};
					let thirdErrorCallback = (jqXHR, status) => {
						userScoreRSMValue.text("...");
						userScoreTRMValue.text("...");
					};
					let promise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, thirdSuccessCallback, thirdErrorCallback);
				};
				// 1.3 Error during rating creation
				let errorCallback = (jqXHR, status) => {
					voteButton.hide();
					configureButton.hide();
					let errorButton = voteButton.parent().find(errorButtons);
					errorButton.show();
					errorButton.prop("disabled", true);
					let errorPromise = buildErrors(jqXHR.responseText).then(result => {
						voteButton.parent().find(errorsSection).find(alert).empty();
						voteButton.parent().find(errorsSection).find(alert).append(result);
						voteButton.parent().find(errorsSection).show();
					});
				};
				// 1.1 Create a new rating with the selected score
				let promise = ajax("POST", "/ratings.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
			}
		});
	}

	//######### CONFIGURATION HANDLING #########//

	configureSaveButton.on("click", () => modalConfigure.modal("hide"));

	////////// RATING //////////

	////////// FUNCTIONALITIES - RATING PAPER  //////////

	ratingSlider.on("slide", slideEvt => ratingText.text(slideEvt.value));

	//#######  ACTION HANDLING #########//

	votePaperButton.on("click", () => {
		let validationInstance = ratePaperForm.parsley();
		validationInstance.validate();
		if (validationInstance.isValid()) {
			votePaperButton.find(reloadIcons).toggle();
		}
	});

	////////// FUNCTIONALITIES - PASSWORD UPDATE  //////////

	passwordEditForm.submit(event => event.preventDefault());

	doPasswordEditButton.on("click", () => {
		let validationInstance = passwordEditForm.parsley();
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
			ajax("POST", "/password/update.json", "application/json; charset=utf-8", "json", true, data, successCallback, errorCallback);
		}
	});

	////////// FUNCTIONALITIES - PROFILE UPDATE  //////////

	authToken = localStorage.getItem('authToken');
	if (authToken != null) {
		updateButton.on("click", () => {
			let validationInstance = signUpForm.parsley();
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
							let button = updateButton.parent().find(errorButtons);
							button.show();
							button.prop("disabled", true)
						} else {
							let errorPromise = buildErrors(jqXHR.responseText).then(result => {
								updateButton.parent().find(errorsSection).find(alert).empty();
								updateButton.parent().find(errorsSection).find(alert).append(result);
								updateButton.parent().find(errorsSection).show();
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
						let button = updateButton.parent().find(errorButtons);
						button.show();
						button.prop("disabled", true)
					} else {
						let errorPromise = buildErrors(jqXHR.responseText).then(result => {
							updateButton.parent().find(errorsSection).find(alert).empty();
							updateButton.parent().find(errorsSection).find(alert).append(result);
							updateButton.parent().find(errorsSection).show();
						});
					}
				};
				let promise = emptyAjax("POST", "/users/info.json", "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
			}
		});
	}

	////////// FUNCTIONALITIES - PUBLICATION LIST  //////////

	let publicationsTable = $("#publications-table");
	publicationsTable.DataTable({
		dom: 'Bfrtip',
		buttons: [
			'copyHtml5',
			'excelHtml5',
			'csvHtml5',
			'pdfHtml5'
		],
		columnDefs: [
			{"width": "20%", "targets": 1},
			{"width": "20%", "targets": 2},
			{"orderable": false, "targets": 6}
		],
		responsive: true
	});

	////////// FUNCTIONALITIES - READERS LIST  //////////

	let usersTable = $("#users-table");
	usersTable.DataTable({
		dom: 'Bfrtip',
		buttons: [
			'copyHtml5',
			'excelHtml5',
			'csvHtml5',
			'pdfHtml5'
		],
		responsive: true
	});

	////////// FUNCTIONALITIES - SUCCESS, HALTED & ERRORS  //////////

	goToHomeButton.on("click", () => {
		goToHomeButton.find(homeIcons).toggle();
		goToHomeButton.find(reloadIcons).toggle();
	});

	goToLoginButton.on("click", () => {
		goToLoginButton.find(signInIcons).toggle();
		goToLoginButton.find(reloadIcons).toggle();
	});
});
////////// INIT  //////////

//######## CONTENT SECTIONS ########//

let buttonsSections = $("#buttons-sect");
let loadingSection = $("#loading-sect");
let loginSection = $("#login-sect");
let undetectedPublicationSection = $("#undetected-publication-sect");
let ratingSection = $("#rating-sect");
let publicationScoreSection = $("#publication-score-sect");
let userScoreSection = $("#user-score-sect");

//######## MODALS ########//

let modalConfigure = $("#modal-configuration");
let modalRefresh = $("#modal-refresh");

//######## UI COMPONENTS ########//

let optionsButton = $("#options-btn");
let loginButton = $("#login-btn");
let logoutButton = $("#logout-btn");
let profileButton = $("#profile-btn");
let signUpButton = $("#sign-up-btn");
let loadRateButton = $("#load-rate-btn");
let voteButton = $("#vote-btn");
let voteSuccessButton = $("#vote-success-btn");
let configureButton = $("#configure-btn");
let configureSaveButton = $("#configuration-save-btn");
let loadSaveButton = $("#load-save-btn");
let saveButton = $("#save-btn");
let downloadButton = $("#download-btn");
let refreshButton = $("#refresh-btn");
let errorButtons = $(".error-btn");
let passwordEditButton = $("#password-edit-btn");
let modalRefreshButton = $("#modal-refresh-btn");

let ratingCaption = $("#rating-caption");
let ratingSubCaption = $("#rating-subcaption");
let ratingSlider = $("#rating-slider");
let ratingText = $("#rating-text");
let buttonsCaption = $("#buttons-caption");
let undetectedPublicationSubcaption = $("#undetected-publication-subcaption");

let firstNameValue = $("#first-name-val");
let lastNameValue = $("#last-name-val");
let emailValue = $("#email-val");
let orcidValue = $("#orcid-val");
let subscribeValue = $("#subscribe-val");
let userScoreRSMValue = $("#user-score-rsm-val");
let userScoreTRMValue = $("#user-score-trm-val");

let publicationScoreRSMValue = $("#publication-score-rsm-val");
let publicationScoreTRMValue = $("#publication-score-trm-val");

let anonymizeCheckbox = $("#anonymize-check");

let signInIcon = $("#sign-in-icon");
let signOutIcon = $("#sign-out-icon");
let signUpIcon = $("#sign-up-icon");
let profileIcon = $("#profile-icon");
let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

// loginSection.hide();
// ratingSection.hide();
// undetectedPublicationSection.hide();
// publicationScoreSection.hide();
// downloadButton.hide();
// refreshButton.hide();
// saveButton.hide();
// loadRateButton.show();
// loadSaveButton.show();
// voteButton.hide();
// configureButton.hide();
// voteSuccessButton.hide();
// errorButtons.hide();
// reloadIcons.hide();
// ratingCaption.hide();
// ratingSubCaption.hide();
// ratingSlider.hide();
// ratingText.show();

let authToken = localStorage.getItem('authToken');
if (authToken != null) {

} else {
	loginSection.show();
	buttonsSections.show();
	logoutButton.hide();
	profileButton.hide();
	ratingSection.hide();
	publicationScoreSection.hide();
	undetectedPublicationSection.hide();
	loadingSection.hide()
}

//####### LOGOUT HANDLING #########//

logoutButton.on("click", () => {
	logoutButton.find(reloadIcons).toggle();
	logoutButton.find(signOutIcon).toggle();
	deleteToken().then(() => window.location.href = "/login");
});
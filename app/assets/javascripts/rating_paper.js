////////// INIT  //////////

let body = $("body");

//######## UI COMPONENTS ########//

let rateForm = $("#new_rating");

let voteButton = $("#vote-btn");

let ratingSlider = $("#rating-slider");

let ratingText = $("#rating-text");

//######## UI INITIAL SETUP ########//

ratingText.text("50");
ratingSlider.slider({});

removePreloader();

////////// RATING //////////

//#######  SLIDER HANDLING #########//

ratingSlider.on("slide", slideEvt => ratingText.text(slideEvt.value));

//#######  ACTION HANDLING #########//

let validationInstance = rateForm.parsley();

voteButton.on("click", () => {
	validationInstance.validate();
	if (validationInstance.isValid()) {
		voteButton.find(reloadIcons).toggle();
	}
});


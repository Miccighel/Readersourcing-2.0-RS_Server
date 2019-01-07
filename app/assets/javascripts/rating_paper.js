////////// INIT  //////////

let body = $("body");

//######## UI COMPONENTS ########//

let voteButton = $("#vote-btn");

let ratingSlider = $("#rating-slider");

let ratingText = $("#rating-text");

let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

ratingText.text("50");
ratingSlider.slider({});

////////// RATING //////////

//#######  SLIDER HANDLING #########//

ratingSlider.on("slide", slideEvt => ratingText.text(slideEvt.value));

//#######  ACTION HANDLING #########//

voteButton.on("click", () => voteButton.find(reloadIcons).toggle());


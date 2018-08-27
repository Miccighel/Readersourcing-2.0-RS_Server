////////// INIT  //////////

//######## UI COMPONENTS ########//

let ratingSlider = $("#rating-slider");

let reloadIcons = $(".reload-icon");

//######## UI INITIAL SETUP ########//

reloadIcons.hide();

ratingSlider.slider({});
ratingSlider.on("slide", function (slideEvt) {
    $("#rating-text").text(slideEvt.value);
});

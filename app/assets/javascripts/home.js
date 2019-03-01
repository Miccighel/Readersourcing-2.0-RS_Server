////////// INIT  //////////

//######## UI COMPONENTS ########//

//######## UI INITIAL SETUP ########//

let successCallback = (data, status, jqXHR) => {
	let redirected = localStorage['redirected'];
	if (!redirected) {
		localStorage['redirected'] = true;
		window.location.href = "/rate";
	} else {
		removePreloader()
	}
};
let errorCallback = (jqXHR, status) => {
	removePreloader();
};
promise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, successCallback, errorCallback);



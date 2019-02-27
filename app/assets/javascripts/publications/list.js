////////// INIT //////////

//######## CONTENT SECTIONS ########//

//######## UI COMPONENTS ########//

//######## UI INITIAL SETUP ########//

////////// USER ///////////

//####### STATUS HANDLING (SCORES, ...) #########//

let successCallback = (data, status, jqXHR) => removePreloader();
let errorCallback = (jqXHR, status) => window.location.href = "/unauthorized";
let promise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
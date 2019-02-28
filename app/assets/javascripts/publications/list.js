////////// INIT //////////

//######## CONTENT SECTIONS ########//

//######## UI COMPONENTS ########//

let datatables = $(".datatable");

//######## UI INITIAL SETUP ########//

datatables.DataTable({
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
	]
});


let successCallback = (data, status, jqXHR) => removePreloader();
let errorCallback = (jqXHR, status) => window.location.href = "/unauthorized";
let promise = emptyAjax("POST", '/request_authorization.json', "application/json; charset=utf-8", "json", true, successCallback, errorCallback);
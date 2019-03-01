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
	]
});

removePreloader();
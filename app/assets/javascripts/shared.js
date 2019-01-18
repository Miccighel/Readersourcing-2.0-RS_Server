////////// NETWORKING SECTION //////////

async function deleteToken() {
	localStorage.removeItem('authToken');
}

async function ajax(type, url, contentType, dataType, crossDomain, data, success, error) {
	let authToken = localStorage.getItem('authToken');
	$.ajax({
		type: type,
		url: `${url}`,
		contentType: contentType,
		dataType: dataType,
		crossDomain: crossDomain,
		data: JSON.stringify(data),
		success: success,
		error: error,
		headers: {
			"Authorization": authToken
		}
	})
}

async function emptyAjax(type, url, contentType, dataType, crossDomain, success, error) {
	let authToken = localStorage.getItem('authToken');
	$.ajax({
		type: type,
		url: `${url}`,
		contentType: contentType,
		dataType: dataType,
		crossDomain: crossDomain,
		success: success,
		error: error,
		headers: {
			"Authorization": authToken
		},
	})
}

////////// UTILITY SECTION //////////

async function buildErrors(errors) {
	let parsedErrors = JSON.parse(errors);
	let element = "";
	Object.keys(parsedErrors).forEach((attribute, index) => {
		element = `<span>${element}${attribute}:</span><ul>`;
		let messages = parsedErrors[attribute];
		Object.values(messages).forEach((message, index) => {
			element = `${element}<li>${message}</li>`;
		});
		element = `${element}</ul>`;
	});
	return element;
}

function removePreloader() {
	$('.preloader-wrapper').fadeOut(1500);
	$('body').removeClass('preloader');
	$('.preloader').css('overflow','visible');
}
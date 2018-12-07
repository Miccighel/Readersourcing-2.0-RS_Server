////////// NETWORKING SECTION //////////

function deleteToken() {
    chrome.storage.sync.remove(['authToken']);
}

function ajax(type, url, contentType, dataType, crossDomain, data, success, error) {
    chrome.storage.sync.get(['authToken'], result => {
        let authToken = result.authToken;
        chrome.storage.sync.get(['host'], result => {
            $.ajax({
                type: type,
                url: `${result.host}${url}`,
                contentType: contentType,
                dataType: dataType,
                crossDomain: crossDomain,
                data: JSON.stringify(data),
                success: success,
                error: error,
                headers: {
                    "Authorization": authToken
                },
            });
        });
    });
}

function emptyAjax(type, url, contentType, dataType, crossDomain, success, error) {
    chrome.storage.sync.get(['authToken'], result => {
        let authToken = result.authToken;
        chrome.storage.sync.get(['host'], result => {
            $.ajax({
                type: type,
                url: `${result.host}${url}`,
                contentType: contentType,
                dataType: dataType,
                crossDomain: crossDomain,
                success: success,
                error: error,
                headers: {
                    "Authorization": authToken
                },
            });
        });
    });
}

////////// UTILITY SECTION //////////

function buildErrors(errors) {
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
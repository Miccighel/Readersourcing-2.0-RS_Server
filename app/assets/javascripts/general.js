Parsley.addMessages('it', {
    defaultMessage: "Questo valore sembra essere non valido.",
    type: {
        email: "Questo valore deve essere un indirizzo email valido.",
        url: "Questo valore deve essere un URL valido.",
        number: "Questo valore deve essere un numero valido.",
        integer: "Questo valore deve essere un numero valido.",
        digits: "Questo valore deve essere di tipo numerico.",
        alphanum: "Questo valore deve essere di tipo alfanumerico."
    },
    notblank: "Questo valore non deve essere vuoto.",
    required: "Questo valore &egrave; richiesto.",
    pattern: "Questo valore non &egrave; corretto.",
    min: "Questo valore deve essere maggiore di %s.",
    max: "Questo valore deve essere minore di %s.",
    range: "Questo valore deve essere compreso tra %s e %s.",
    minlength: "Questo valore &egrave; troppo corto. La lunghezza minima &egrave; di %s caratteri.",
    maxlength: "Questo valore &egrave; troppo lungo. La lunghezza massima &egrave; di %s caratteri.",
    length: "La lunghezza di questo valore deve essere compresa fra %s e %s caratteri.",
    mincheck: "Devi scegliere almeno %s opzioni.",
    maxcheck: "Devi scegliere al pi&ugrave; %s opzioni.",
    check: "Devi scegliere tra %s e %s opzioni.",
    equalto: "Questo valore deve essere identico."
});

Parsley.addValidator('orcid', {
    requirementType: 'regexp',
    validateString: function (value) {
        return /[0-9]{4}-[0-9]{4}-[0-9]{4}-([0-9]{3}X|[0-9]{4})/.test(value);
    },
    messages: {
        en: 'This value is an invalid ORCID.',
        it: 'Il valore inserito non &egrave; un ORCID valido.'
    }
});

Parsley.addValidator('doi', {
    requirementType: 'regexp',
    validateString: function (value) {
        let firstRegex = /\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/;
        let secondRegex = /\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])[[:graph:]])+)\b/;
        return (firstRegex.test(value) || secondRegex.test(value));
    },
    messages: {
        en: 'This value is an invalid DOI.',
        it: 'Il valore inserito non &egrave; un DOI valido.'
    }
});

Parsley.addValidator('password', {
    requirementType: 'regexp',
    validateString: function (value) {
        return /^(?=.*[a-z])(?=.*[A-Z]).*$/.test(value);
    },
    messages: {
        en: 'Your password must contain at least (1) lowercase and (1) uppercase letter.',
        it: 'La tua password deve contenere almeno (1) maiuscola e (1) maiuscola.'
    }
});

Parsley.setLocale('it');

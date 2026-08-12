# Postman collection

`Readersourcing_2.0.postman_collection.json` is the versioned source of the public RS_Server collection.
It follows the organization of the original collection and documents the Rails routes exposed by RS_Server.
The published documentation is available through the [Postman documenter](https://documenter.getpostman.com/view/4632696/2sBY4WpHYd).

The collection uses variables for the server address, reader credentials, resource identifiers, confirmation and password
tokens, and the durable reference embedded in an annotated PDF. Their sensitive values are intentionally empty. Set them
only in your local Postman workspace and do not include their current values in an exported or published collection.

To use the collection:

1. import the JSON file into Postman;
2. set `host`, `email`, and `password` for the RS_Server instance being tested;
3. run `Authentication (Authenticate)` to populate `authToken`;
4. set the identifiers required by the requests you want to exercise.

API requests send the token as `Bearer {{authToken}}`. Browser workflows instead use the encrypted Rails session retained
by Postman's cookie jar. The paper rating workflow also requires `paperReference`, which is obtained from the link or QR
Code embedded in an annotated publication. Open `Ratings (Rate Paper)` before submitting `Ratings (Load)`, so the durable
reference is stored in the same reader session.

The source file contains a small set of fictitious examples covering authentication, publication lookup, rating creation,
validation, and request limits. They contain no personal data, reusable credentials, session cookies, CSRF values, or
generated HTML. Collection scripts report missing variables before a request is sent and check the essential form of these
API responses.

Operations that regenerate an annotated publication or change the reader's subscription preference use `POST`. The
unsubscribe link included in rating emails opens a confirmation page; the preference changes only when the authenticated
reader submits that form.

## Publishing an update

The public collection is updated through the Postman API. Create an API key in your Postman account and keep it outside
this repository. Then set `POSTMAN_API_KEY` and `POSTMAN_COLLECTION_UID` in your
local shell and run:

```console
bin/update_postman_collection
```

For the currently published collection, the UID is `4632696-d8e16efa-6272-4f7c-a6f6-837931c0550d`. The command first
reads the remote collection and applies its identifiers to the versioned source before replacing its contents. This keeps
the existing collection and its published documentation associated with the same Postman resource. The API key is read
only from the process environment and is never written to the collection or to the repository.

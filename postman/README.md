# Postman collection

`Readersourcing_2.0.postman_collection.json` is the versioned source of the public RS_Server collection.
It preserves the organization of the original collection while keeping its requests aligned with the current Rails routes.
The published documentation is available through the [Postman documenter](https://documenter.getpostman.com/view/4632696/2sBY4WpHKV).

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
code embedded in an annotated publication. Open `Ratings (Rate Paper)` before submitting `Ratings (Load)`, so the durable
reference is stored in the same reader session.

Historical response snapshots are not stored in the source file. They belonged to the original Rails stack and contained
expired JWTs, session cookies, CSRF values, and generated HTML. The small set of current examples is instead composed of
fictitious data and covers authentication, publication lookup, rating creation, validation, and request limits. Collection
scripts report missing variables before a request is sent and check the essential form of these API responses.

## Publishing an update

Update the existing Postman collection through the Postman API instead of importing another copy. Create an API key in
your Postman account and keep it outside this repository. Then set `POSTMAN_API_KEY` and `POSTMAN_COLLECTION_UID` in your
local shell and run:

```console
bin/update_postman_collection
```

For the currently published collection, the UID is `4632696-fb2ca8e7-e295-43cd-9cfd-03d4f20ea65c`. The command first
reads the remote collection and applies its identifiers to the versioned source before replacing its contents. This keeps
the existing collection and its published documentation associated with the same Postman resource. The API key is read
only from the process environment and is never written to the collection or to the repository.

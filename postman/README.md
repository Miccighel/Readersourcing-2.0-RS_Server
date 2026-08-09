# Postman collection

`Readersourcing_2.0.postman_collection.json` is the versioned source of the public RS_Server collection.
It preserves the organization of the original collection while keeping its requests aligned with the current Rails routes.
The published documentation is available through the [Postman documenter](https://documenter.getpostman.com/view/4632696/2sBY4VLy5Q).

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
expired JWTs, session cookies, CSRF values, and generated HTML. Current response examples can be recorded against the
deployment selected through `host` after confirming that they contain no credentials or personal data.

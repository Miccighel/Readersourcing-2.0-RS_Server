# Local integration check

The check performed on 6 October 2026 used the development branches of RS_Server and RS_Rate, with RS_PDF 2.0.0 bundled in the server image. The domain models and the PDF preparation workflow were not changed.

## Environment

The server ran from a locally built production image with Ruby 3.4.10, Java 21, and PostgreSQL 17. A separate Compose project supplied disposable readers, publication storage, a PDF publisher, and an SMTP simulator. HTTP ports were bound to the loopback interface. No real email was sent and no public service was deployed.

The SMTP simulator supported authentication and STARTTLS with a certificate trusted explicitly by the test environment. Private network retrieval was enabled only in this environment so that RS_PDF could reach the local publisher. Production configuration was not relaxed. A 20 second total PDF budget and a slower source were used to verify deadline enforcement.

## Results

| Path | Result |
| --- | --- |
| Production configuration and readiness | Deployment checks passed; anonymous publication API requests were refused. |
| Registration and confirmation | SMTP failure retained the unconfirmed account. Signing in allowed confirmation delivery to be retried without authorizing the reader prematurely. |
| Registration limits | Repeated attempts for the same account returned 429 with a Retry-After header. |
| Remote PDF preparation | The original matched the source bytes. The annotated copy contained one additional rating page and the expected rating URL. |
| Reader copies | Two readers retained separate filenames, storage paths, and rating references for the same publication. |
| Source failures | Protected access, a response containing HTML, and an expired processing budget produced the documented preparation states. |
| Original PDF upload | The API and web interface prepared the uploaded original when the publisher required browser access. |
| Failed replacement | An invalid upload did not replace the reader's previous prepared copy. |
| Rating URL extraction | The API and web interface extracted the owning reader's URL; another reader was refused. |
| Printed QR Code | The decoded image matched the PDF link. The web form saved a rating of 51, which was verified through the API. |
| Logout | Authentication was revoked without invalidating the prepared PDF. Reopening its rating URL required login and then correctly reported an existing rating. |
| Password recovery | The reset form accepted the mailed link, consumed it once, and revoked previous credentials. Registered and unknown addresses received the same public response. |
| Browser request protection | A form submission without a CSRF token was refused. |

The web check found a preparation error that remained visible after a successful retry or upload. Both interfaces now clear that error in their existing success handler. Regression tests cover the handler, and the server correction was verified in the rebuilt production image. No errors were recorded in the web console during these checks.

The Rails suite passed 271 tests with 2,154 assertions. RS_Rate passed 38 tests; both browser builds passed the asset checks. Firefox lint reported no errors and retained its 21 documented warnings.

## Remaining validation

RS_Rate has not yet been exercised interactively in Chromium and Firefox during this check. Its builds and automated tests do not replace that validation. The intended browser test uses separate temporary profiles and access to the local server only.

Postman publication, Docker Hub publication, and a public deployment were not performed. The documented node-forge finding remains open, without an audit exception. The local check does not replace container vulnerability assessment, backup verification, or validation of the eventual production host and SMTP provider.

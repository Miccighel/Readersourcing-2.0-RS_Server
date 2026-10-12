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

The web check found a preparation error that remained visible after a successful retry or upload. Both interfaces clear that error in their existing success handler. Regression tests cover the handler, and the server correction was verified in the rebuilt production image. No errors were recorded in the web console during these checks.

The Rails suite passed 271 tests with 2,154 assertions. RS_Rate passed 38 tests; both browser builds passed the asset checks. Firefox lint reported no errors and retained its 21 documented warnings.

## RS_Rate in Edge

On 8 October 2026, RS_Rate 2.0.0 was loaded from the local Chromium build into a separate temporary Edge profile. The extension requested permission for the configured local server. The server used a new disposable database, publication storage, a local PDF publisher, and an SMTP simulator. Production configuration, readiness, and SMTP checks passed.

The extension popup authenticated a test reader and retained the session when reopened. Preparing the publication displayed the processing state and opened an annotated PDF containing eight pages instead of the original seven. Reopening the popup on the source displayed `PDF ready` and the `Open` control. A rating of 51 submitted from the popup was verified in the database for that reader.

A source returning HTTP 403 produced `Browser access required`, a retry control, and the original PDF upload area. The upload check identified a duplicated `Authorization` header and an error handler that displayed `[object Object]`. The duplicated value caused the server to refuse the multipart request with HTTP 422 because CSRF validation failed. A separate multipart request to the reader information endpoint confirmed HTTP 200 with a single token and HTTP 422 with the duplicated value.

Dropzone configuration supplies the authentication header once for each upload. Repeated calls to `XMLHttpRequest.setRequestHeader` append values, as described in the [XMLHttpRequest documentation](https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/setRequestHeader). Both upload error handlers select a textual server message or a message describing the failed operation. Numeric HTTP status values are not used as preparation states. Server CSRF protection was not changed.

Selecting the original PDF through the native file chooser completed preparation with HTTP 201, opened the annotated copy containing eight pages, and displayed `PDF ready` when the popup was reopened on the source. Uploading a PDF without an annotation to the extraction control returned HTTP 422 and displayed `The PDF file does not contain a rating URL to extract.` Uploading the test reader's annotated PDF returned HTTP 200 and opened its rating URL; the server correctly reported the reader's existing rating. RS_Rate passed 67 tests, including 24 upload regression cases and five message style checks. Both builds passed the asset checks; Firefox lint retained its 21 warnings and reported no errors.

A source returning HTML with HTTP 200 was refused during preparation with HTTP 415. The popup displayed `PDF not found`, the server's explanation, a retry control, and the original PDF upload area.

A source taking 25 seconds to respond exceeded the configured 20 second processing budget. The request returned HTTP 422 after approximately 20 seconds. The popup displayed `PDF operation timed out`, explained that the operation had stopped, and offered a retry or an original PDF upload.

Logout from the popup returned HTTP 200 and displayed the login form with empty fields. The server revoked the credential issued for that session. Both previously prepared PDFs remained available and retained their SHA-256 hashes; neither failed preparation attempt created a publication or replaced those copies.

Popup messages use the corresponding dark Bootstrap text color for information, success, warning, and error states, including nested titles and descriptions. Their backgrounds and layout are unchanged. Stylesheet checks verified all four color pairs against the [4.5:1 text contrast threshold](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). A local preview using the Chromium build styles confirmed the applied colors visually and through computed styles. The actual Edge popup also displayed readable information, success, warning, and error messages during the browser checks. The personal Edge profile was not used.

On 9 October 2026, the current Chromium build was checked in a new temporary Edge profile against the retained test database and publication storage. Login through the toolbar popup succeeded, and reopening it retained the session. Uploading the original PDF for the protected publisher returned HTTP 200 and opened its annotated copy containing eight pages. Both file choosers worked in the existing popup.

Extraction refused the original PDF with HTTP 422 and a textual explanation. The owning reader's annotated PDF returned HTTP 200 and opened the web page reporting the existing rating of 50. An HTML source returned HTTP 415 and displayed `PDF not found`. A slow source returned HTTP 422 after approximately 20 seconds and displayed `PDF operation timed out`, with retry and original upload controls.

Logout displayed an empty login form and revoked that extension session's credential. The failed preparation attempts did not create publications. The original and annotated files for both tested publications retained their SHA-256 hashes after logout. Optional diagnostic data was disabled and verified in the temporary Edge profile; the personal profile was not used.

## RS_Rate in Firefox

On 8 October 2026, the local Firefox build was loaded temporarily into a separate Firefox 157.0.1 profile. It used the same isolated server and publisher as the Edge check. The personal Firefox profile was not used.

Firefox refused the initial host permission pattern because it included a port. Its permission pattern now contains the selected protocol and hostname without a port, as required by the [Firefox match pattern rules](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Match_patterns). Access to the local hostname on all ports was explicitly authorized for this check. API requests retained the configured server address on port 3300.

Firefox did not retain the authentication token in the extension page's cookies when the popup was reopened. The token now uses the extension's [session storage](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/storage/session). Controllers wait for token storage or removal before navigating. It is shared by extension pages during the browser session and is not synchronized or retained across browser restarts.

A browser web session cookie also caused a subsequent login request to fail CSRF validation. Firefox API requests use an [anonymous XMLHttpRequest](https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/XMLHttpRequest) that omits automatic cookies and HTTP credentials while retaining the explicit extension token. Server CORS and CSRF protections were not changed.

The test reader signed in through the extension's actual login view in a regular tab. The popup then retained the authenticated session when reopened on the publisher's PDF. A browser restart required a new login while preserving the configured server address. Preparation from the popup opened an annotated PDF containing eight pages instead of seven and displayed `PDF ready`. A rating of 50 submitted from the popup was verified in the database for that reader. A source returning HTTP 403 displayed `Browser access required` and offered an original PDF upload.

A source returning HTML was refused with HTTP 415 and displayed `PDF not found`. A source exceeding the 20 second processing budget was stopped with HTTP 422 and displayed `PDF operation timed out`. Both states offered a retry and an original PDF upload. The warning text remained readable in the actual popup.

The popup's file chooser did not open successfully with either automatic control or manual selection. An upload through the separate extension tab returned HTTP 201 and opened an annotated PDF, but it was associated with that tab rather than the publisher. That tab was closed before repeating the popup check. This behavior is consistent with the [reported Firefox panel limitation](https://bugzilla.mozilla.org/show_bug.cgi?id=1378527). Mozilla describes using a normal extension page as a [workaround](https://bugzilla.mozilla.org/show_bug.cgi?id=1658694).

The Firefox upload controls open the existing forms in a normal extension tab. Original PDF uploads retain the publisher's address in session storage rather than selecting the active upload tab as the publication. Extraction does not look up a publisher address. Closing an upload tab removes its context without removing the authentication token. Tests cover separate publication contexts, cleanup, invalid references, and the existing publication actions.

Logout from the actual popup displayed the login form with empty fields. The server removed the credential for that session. A new login issued a separate credential.

On 9 October 2026, the check continued in a new temporary Firefox profile using the retained test database and publication storage. Both upload controls were opened from the actual toolbar popup. The native file chooser worked in the normal extension tabs without manual intervention.

The original PDF upload returned HTTP 200 for the existing publication whose source was `http://127.0.0.1:38082/protected.pdf`. Its reader copy matched the source bytes, and the annotated PDF opened successfully. The upload tab displayed that publisher address and `PDF ready`. Closing the tab and reopening the popup on the source retained the authenticated session and displayed the prepared copy.

Uploading the original PDF to extraction returned HTTP 422 and displayed `The PDF file does not contain a rating URL to extract.` Uploading the test reader's annotated PDF returned HTTP 200 and opened its rating URL. The web interface required login; reopening the extracted link after login correctly reported the reader's existing rating. The database retained the score of 50. Reloading the extraction tab retained its context, and a further annotated upload returned HTTP 200 while a web session cookie was present.

After closing the upload tabs, logout from the actual popup displayed an empty login form and revoked that extension session's credential. The original and annotated files for both tested publications retained their SHA-256 hashes.

Upload preview filenames and file sizes use dark gray text on their existing light surfaces. The correction applies to the details and their nested text without changing layout, backgrounds, or icons. The stylesheet check verified contrast of at least 4.5:1 against both preview surfaces. Actual file uploads confirmed readable preview text in a normal Firefox extension tab and the Edge toolbar popup.

RS_Rate passed 92 tests, including session storage, authenticated requests, host permissions, upload tab contexts, message and preview contrast, and preservation of the Chromium storage and request behavior. Both builds passed the asset checks. Firefox lint reported no errors and retained its 21 documented warnings. Both extension archives matched their build assets and excluded development dependencies.

## Backup and recovery

On October 9, 2026, `bin/backup` created a database archive and a publication archive from the isolated browser check.
`bin/restore_backup --confirm` restored them into a separate Compose project with a new database and new publication
volume. The source contained only synthetic readers. No production data or public service was used.

All six database table fingerprints and all 30 stored file hashes matched immediately after restoration. The restored
data contained two readers, three publications, two ratings, and five pairs of original and annotated reader copies.
The readiness endpoint returned HTTP 200, and `deployment:check` passed, including authenticated SMTP with the local
simulator. No real email was sent.

Recovery retained the original signing secret and canonical `PUBLIC_BASE_URL`. The restored web service was reached
on a different loopback port for the check, without changing the public origin embedded in the prepared PDFs. The
backup archives do not contain the secret; it was supplied through the private test configuration.

An unauthenticated request to an existing paper rating reference required login. After authentication, four original
and annotated PDF downloads returned HTTP 200 and matched the restored file hashes. Annotated PDF extraction returned
HTTP 200 with the original rating reference. Its owning reader reached the existing rating of 50 without changing the
score. Logout revoked the test credential, and the same reference required login again. The original database and
storage remained unchanged; the restored database and all five PDF pairs also remained unchanged after these requests.

A modified database archive failed checksum validation. A publication archive containing a path outside its extraction
directory was also refused, even with a matching checksum. Both failures occurred before the restore wrote to the
target service. The backup and recovery instructions are in [backups.md](backups.md).

## RS_Rate signed Firefox installation

RS_Rate 2.0.0 was submitted to Mozilla on October 9, 2026 through the existing extension entry, retaining its original
identifier `rs-rate@readersourcing.com`. The submission used the unlisted channel for Firefox desktop and included
the corresponding source archive. Mozilla reported no validation errors and 21 warnings, approved the version, and
returned a signed XPI. No new version was published in the public catalog. The signed package was installed through
the Add-ons Manager in the separate regular Firefox 157.0.1 profile and appeared active. No signature enforcement
preference overrides were found. Private window access was reported as disabled during manual configuration, but
automatic control could not confirm the updated setting.

The signed package's functional check completed later on October 9. The user operated the temporary Firefox
profile; HTTP responses, synthetic reader records, and publication copies were checked independently on the local
server. Login created an active session and remained available after closing and reopening the toolbar popup.
Original PDF upload returned HTTP 200 and opened an annotated copy containing eight pages rather than seven.
The stored original matched the selected file byte for byte and remained associated with
`http://127.0.0.1:38082/protected.pdf`.

Extraction refused the original PDF with HTTP 422 and a textual explanation. The annotated copy returned HTTP 200
and opened the corresponding publication's rating page. No rating was submitted. A complete Firefox restart cleared
the extension login while retaining `http://127.0.0.1:3300` as the selected server. After a new login, logout returned
HTTP 200 and removed that precise session record; reopening the popup displayed the login view. Both synthetic
readers and all existing rating records remained unchanged.

The check also identified overlapping popup and upload views, a narrow form in the normal tab, and loading icons
that remained visible. The development source closes only an actual Firefox popup after opening the upload tab,
centers the tab's form within its available width, and preserves the original icon elements while Font Awesome adds
its SVGs. A browser fixture using the bundled library reproduced disconnected icon references with replacement and
retained working show and hide operations with nesting. A synthetic API preview verified the form at widths of 300
and 1,280 pixels, hidden idle indicators, and the unchanged 300 pixel popup width. These revisions are not part of the
signed XPI just checked.

## RS_Rate development interface in Firefox

On 11 October 2026, the development build at commit `74d1740` was loaded through `about:debugging` in a separate
Firefox 157.0.1 profile. API requests used the isolated server on port 3300. The personal profile, signature
enforcement, retained signed XPI, and source submitted to Mozilla were not changed.

Login remained active when the toolbar popup was reopened. The profile dialog displayed the synthetic reader's
values, and the profile form retrieved its values without submitting an update. The original upload control opened
a centered extension tab, closed the popup, and retained the publisher address on port 38082. During upload, the
preparation section displayed `Preparing the PDF` while the rest of the view remained visible. Completion displayed
`PDF ready` and opened the annotated copy containing eight pages. The original copy retained the fixture's SHA-256 hash.

The extraction control opened only its own form. It refused the original PDF with a readable error and extracted
the annotated copy's rating URL for the same publication on the local server. The rating page required a separate
web login; no rating was submitted. Logout removed the checked authentication session, and reopening the popup
displayed the signed-out actions. The users, publications, and ratings retained their complete database fingerprints.

Native clicks on some popup controls were unreliable; keyboard navigation completed those checks. Screenshots
record the visible states, but do not measure the first render frame by frame. The controller initialization tests
cover the content gate, upload layout selection, redirects, and initialization errors. RS_Rate passed 120 tests;
both builds passed the asset checks, and Firefox lint reported no errors with the 21 documented library warnings.

A separate rendering check on the same date used the built publication view and bundled libraries with synthetic
responses rather than the server. Session retrieval, the active tab read, and the publication lookup were delayed
to observe the intermediate frames. The checking section remained visible and rating controls stayed hidden until
the lookup completed. Navigation remained available throughout initialization. At a width of 300 pixels, a long
synthetic email wrapped within the profile box without changing or truncating its text.

This check measures the controlled page, not the native Firefox toolbar popup. Automatic control returned
inconsistent window observations and did not confirm reloading the revised temporary extension. The updated source
passed 125 tests and both build checks, with no Firefox lint errors and the same 21 library warnings. No server,
dependency declaration, retained distribution archive, or signed package was changed by these interface corrections.

## RS_Rate 2.0.1 Firefox distribution

On October 11, 2026, both RS_Rate manifests and `package.json` were aligned at version 2.0.1. The Firefox declaration
omits the unsupported `version_name` field while Chromium retains it. Reloading the temporary Firefox build removed
the manifest warning, and its background script appeared running. The extension identifier, dependency declarations,
domain actions, and server interfaces remain unchanged.

The versioned unsigned archives contain 90 assets each, matching their unpacked builds and excluding development
dependencies. RS_Rate passed 127 tests and both build checks. Firefox lint reported no errors or notices and retained
the 21 documented library warnings. The historical version 2.0.0 archives remain unchanged.

The updated Chromium build was checked in a separate Edge profile against the isolated server. Login remained active
when the popup was reopened, the long synthetic email wrapped within the profile box, and the verified eight-page
PDF opened. Logout displayed the empty login form and revoked the issued credential. The complete user, publication,
and rating fingerprints remained unchanged. This brief check did not repeat the earlier upload and extraction cases.

The submitted source was installed into a separate directory using the unchanged lockfile and local immutable
cache with network access disabled. The new installation passed all 127 tests and reproduced the 90 assets in
each unsigned package. All 47 bundled library assets matched version 2.0.0 byte for byte.

Mozilla approved version 2.0.1 on the existing entry's unlisted channel for Firefox desktop. Its version identifier
is `6565662`, and its file identifier is `5109799`. Validation reported no errors and the same 21 warnings. The source
returned by Mozilla matched the submitted archive's hash. The signed package retained all application assets and
manifest values, with Mozilla's signature files added. The exact files and their hashes are recorded in RS_Rate's
`docs/firefox.md`. No new version was published in the public catalog.

The returned XPI was installed through the Add-ons Manager in the separate regular Firefox 157.0.1 profile and
appeared active as version 2.0.1. The manager confirmed that private window access was disabled. Login, reopening
the authenticated popup, and profile reads completed with the synthetic reader. Original upload opened a centered
extension tab, closed the popup, and retained the publisher address. The annotated copy opened with eight pages;
the stored seven-page original matched the fixture's SHA-256 hash. Extraction refused the original with a readable
explanation and extracted the prepared copy's rating URL for the same publication on the local server. The rating
page required a separate web login; no rating or profile update was submitted.

A complete restart cleared the extension's local authentication token while retaining the server address. The new
login issued a separate credential, and logout revoked precisely that credential. The empty login form appeared,
and reopening the popup displayed the actions for an unauthenticated reader. The browser restart did not revoke
the earlier server credential; it remains subject to the server's expiry and revocation rules. The complete user,
publication, and rating fingerprints remained unchanged. No signature enforcement preference overrides were found.

Installation checks completed for the exact signed version 2.0.1. Some native controls required keyboard navigation
or the user's assistance to focus the temporary Firefox window and confirm the file chooser. The extraction cases
used separate form loads. These observations verify interactions and visible states rather than frame-by-frame
timing of the popup.

## Remaining validation

Version 2.0.1 has been signed and its installation checks completed in a regular Firefox release.
The historical version 2.0.0 archives remain unchanged. The Firefox Add-ons Manager confirmed that private window
access was disabled for the version 2.0.1 check. Neither the signed functional check nor the synthetic interface
preview constitutes validation of a public deployment.

The earlier browser and recovery checks did not publish to Postman or Docker Hub, and no public service was deployed.
The documented `node-forge` and `shell-quote` findings remain open in the RS_Rate development audit, without exceptions.
Application dependency audits and the container assessment are recorded in [security.md](security.md). The local results do not replace
validation of the eventual production host, SMTP provider, external backup storage, or production recovery time.

## Container validation

On October 9, 2026, replacement production images were built for `linux/arm64` and `linux/amd64`. They retain Ruby
3.4.10, Debian Trixie, the application dependency declarations, and the bundled RS_PDF JAR. Both contain current Debian
packages and use the locked JSON version 2.21.2 for Ruby commands both inside and outside Bundler. The native JSON
parser and generator were checked in each image, including the `amd64` image under emulation.

Both candidates started successfully in the separate recovery project, with `amd64` running under emulation.
Readiness and `deployment:check` passed in each, including authenticated SMTP with the local simulator. Four original and
annotated downloads returned HTTP 200 and matched their stored hashes. Annotated PDF extraction returned the original
rating reference; its reader reached the existing score of 50. Logout revoked the issued credential, and anonymous
access to the same rating reference required login again. The source database and storage, the restored database, and
all five restored PDF pairs were unchanged after the requests.

The Rails suite passed 271 tests with 2,154 assertions against a separate disposable PostgreSQL database. The checks
above were repeated for both candidates; they do not repeat every earlier browser scenario. The two image identities,
scan results, and remaining findings are in [security.md](security.md). The original browser check services were not replaced. The same candidate
contents were subsequently published on Docker Hub as `v2.0.2`; the `v2.0.1` tag remains unchanged. Registry
configuration digests match the assessed image IDs. No public service was deployed.

Both platforms were pulled from the published version tag. Runtime JSON checks outside Bundler passed in each
downloaded image, including the lockfile version, absence of older JSON specifications, and a parsing and generation
round trip. The registry digests and checks are retained in [the publication record](container-release-2026-10-09.json).

### Validation of October 12, 2026

The local resolver candidates recorded in [security.md](security.md) passed 21 production rehearsal checks. Ruby
remained at 3.4.10, with `json` 2.21.2 and `resolv` 0.7.2. The native `arm64` and emulated `amd64` application containers
used an unprivileged user, a read only root file system, dropped capabilities, no new privileges, and the configured
memory and process limits. The databases had no published host port. The preexisting browser check services and
their volumes were not used or replaced.

Requests reached Rails through a loopback HTTPS proxy with certificate verification, `FORCE_SSL=true`, and
`ASSUME_SSL=true`. The local SMTP simulator required authenticated STARTTLS, with certificate verification active.
Registration, email confirmation, authentication, private profile access, and password recovery passed. Session
cookies carried Secure, HttpOnly, and SameSite=Lax attributes. Browser session requests without a CSRF token were
refused, while requests with the token from the authenticated view succeeded. Password reset links were single use
and password changes revoked earlier authentication tokens.

The publisher simulator returned an accessible PDF, a document requiring browser authentication, and a response
that was not a PDF. The API reported the corresponding availability states and rejected excessive DNS labels.
Remote retrieval and the local upload alternative each prepared the committed Reader.pdf fixture from seven to
eight pages. Extraction returned the embedded rating reference, while another reader could not use it. Logout and
password recovery did not invalidate the paper reference; its owner could use it after authenticating again.

The backup scripts captured the database and private publication archive while requests were blocked by the
maintenance proxy. A restore into an empty, separate project retained the signing secret and application origin.
The local restore completed in eight seconds. This measures the small synthetic rehearsal, not a production
recovery time or the availability of an external backup provider.

Readiness and `deployment:check` passed after restoration on both architectures. Original and annotated downloads
matched the archived hashes, extraction retained the same paper references, and the existing rating remained 50.
Reader, publication, and rating fingerprints were unchanged during these read, extraction, and logout checks. PDF
contents and copy metadata also remained unchanged. Issuing new bounded download URLs renewed only their operational
retention leases; the checks required monotonic deadlines within the configured lifetime and retirement grace.
Authentication token issuance and revocation were expected operational changes, separate from domain fingerprints.
The source database and private storage remained unchanged by recovery.

A separate `amd64` case retrieved, annotated, and refreshed a PDF for the second synthetic reader. Deleting that
account removed its private PDF directory and revoked its authentication. Private network access was enabled only
for the local publisher cases. With the default restriction enabled, the API refused that same private destination
and the local upload alternative still succeeded.

The [validation record](production-check-2026-10-12.json) contains the image IDs, completed checks, backup hashes,
domain fingerprints, and restored PDF hashes. The synthetic backup and its private configuration were retained
outside the repository; the disposable services and volumes were removed after recording the results. No image was
published and no public service was deployed. Production DNS, certificates, ingress capacity, SMTP, and external
backup storage still require validation on the selected host. The remaining security findings stay open.

### Container publication of October 12, 2026

The same resolver candidates were published as `miccighel/rs_server:v2.0.3` without rebuilding. The registry
configuration digests match the image IDs used for the production rehearsal. Both `linux/amd64` and `linux/arm64`
were pulled from the common version tag. JSON and DNS checks passed inside and outside Bundler in the downloaded
images, including the locked library versions, removal of the older default implementations, excessive DNS label
rejection, and bounded handling of unknown DNS resource and service parameter types. The 180 tracked application
files checked in each image matched the source. No private environment file, master key, or reader PDF was present
in the checked locations.

The previous `v2.0.2` and `v2.0.1` manifests remain unchanged. Compose and the scheduled scan now refer to `v2.0.3`.
The [publication record](container-release-2026-10-12.json) retains registry digests and checks. Publication does not
resolve the remaining operating system findings and does not validate an external production host. No public
service was deployed, and `master` was not changed.

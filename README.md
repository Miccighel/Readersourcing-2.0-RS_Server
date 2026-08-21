[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/Naereen/StrapDown.js/graphs/commit-activity)
![Maintainer](https://img.shields.io/badge/maintainer-Miccighel-blue)
[![Github all releases](https://img.shields.io/github/downloads/Miccighel/Readersourcing-2.0-RS_Server/total.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/releases/)
[![GitHub stars](https://badgen.net/github/stars/Miccighel/Readersourcing-2.0-RS_Server)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/stargazers/)
[![GitHub watchers](https://badgen.net/github/watchers/Miccighel/Readersourcing-2.0-RS_Server/)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/watchers/)
[![GitHub contributors](https://img.shields.io/github/contributors/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/graphs/contributors/)
[![GitHub issues](https://img.shields.io/github/issues/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/issues/)
[![GitHub issues-closed](https://img.shields.io/github/issues-closed/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/pull/)
[![GitHub pull-requests closed](https://img.shields.io/github/issues-pr-closed/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/pull/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

Readersourcing 2.0: _An independent, third-party, no-profit, academic project aimed at quality rating of scholarly literature and scholars._

<h1>Info</h1>

This is the official repository of **RS_Server**, which is part of the **Readersourcing 2.0** ecosystem. 
This repository is a [Git Submodule](https://git-scm.com/book/it/v2/Git-Tools-Submodules) of the main project, 
whose components can be found by taking advantage of the links below.

The current development line is version **2.0.0**.

<h1>Useful Links</h1>

- <a href="https://readersourcing.com">Readersourcing 2.0 (Web Interface)</a>
- <a href="https://github.com/Miccighel/Readersourcing-2.0">Readersourcing 2.0 (GitHub)</a>
- <a href="https://link.springer.com/chapter/10.1007/978-3-030-11226-4_21">Original Article (Springer Link)</a>
- <a href="https://zenodo.org/record/1446468">Original Article (Zenodo)</a>
- <a href="https://zenodo.org/record/1452397">Technical Documentation (Zenodo)</a>
- <a href="https://github.com/Miccighel/Readersourcing-2.0-TechnicalDocumentation"> Technical Documentation (GitHub)</a>
- <a href="https://documenter.getpostman.com/view/4632696/2sBYApzDQN">RESTful API Interface</a>
- <a href="https://doi.org/10.5281/zenodo.1442630">Zenodo Record</a>

The source of the Postman collection is versioned in
[`postman/Readersourcing_2.0.postman_collection.json`](postman/Readersourcing_2.0.postman_collection.json). Its validation
and publication procedure is described in [`postman/README.md`](postman/README.md).

<h1>Description</h1>

**RS_Server** is the server component which has the task of collecting and aggregating the ratings given by readers and using the ```Readersourcing``` models to compute quality scores for
readers and publications.
It is deployed together with an instance of <a href="https://github.com/Miccighel/Readersourcing-2.0-RS_PDF">RS_PDF</a>.
RS_Server exposes a RESTful API Interface and provides a standalone web interface to interact directly with the APIs.

Readers can also communicate with the APIs from different browsers by using
an instance of <a href="https://github.com/Miccighel/Readersourcing-2.0-RS_Rate">RS_Rate</a>, that is, a browser extension.
Thus, every interaction between human readers and the APIs exposed by RS_Server can be carried out through clients installed on readers' browsers or by using the standalone web
interface provided. These clients handle the registration and authentication of readers, the rating action and the download action of annotated publications.

When a reader asks to save a publication for later, RS_Server retrieves the source once, applies the configured size and
network limits, and opens the received content as a PDF. The declared content type is treated as an indication rather than
as proof. RS_PDF then adds the rating page, after which RS_Server verifies both the additional page and the embedded rating
URL before publishing the prepared copy. The web interface reports the current preparation state throughout this operation.
If the publication host requires access through the reader's browser session or cannot be reached, the original PDF can be
uploaded through the same interface and follows the same validation, annotation, and verification procedure.

<h1>Deploy</h1>

There are two main modalities that can be used to deploy a working instance of RS_Server in the **development** or **production** environment.
The former environment must be used if there is the need to:

- add custom ```Readersourcing``` models;
- extend/modify the current implementation of RS_Server;
- simply to test it in a safe way.

In the following, both deployment modalities are described along with their requirements. The manual installation allows
RS_Server to run directly on the local machine while its source code is edited. Docker Compose builds the application and
starts it together with PostgreSQL using the Rails **production** settings.

Please, be sure to read the section dedicated to the **environment variables**, since RS_Server will not work properly without them.

<h2>Modality 1: Manual</h2>

This modality allows to manually download and initialize RS_Server's codebase in a local machine.
This is the most demanding modality in terms of prerequisites since it assumes having a full and working installation of
```Ruby```, ```JDK``` (Java Development Kit) and ```PostgreSQL```. Despite that, it provides more flexibility.

<h3>Requirements</h3>

- <a href="https://www.ruby-lang.org/en/downloads/">Ruby</a> == 3.4.10;
- a Java 21 runtime, required by RS_PDF;
- <a href="https://www.postgresql.org/download/">PostgreSQL</a> >= 17;
- Node.js >= 18, used to install the browser assets.

<h3>How To</h3>

Clone this repository and navigate to its main directory using a command line prompt (you should see ```app```, ```bin```, ```config```, etc., folders with an ```ls``` or ```dir``` command)
then type ```gem install bundler```. This gem (dependency) provides a consistent environment for Ruby projects, as RS_Server, by tracking and installing the exact gems (dependencies) and versions
needed.

To fetch all Ruby dependencies required by RS_Server, type ```bundle install``` and wait for the process to complete.
Then type ```node .yarn/releases/yarn-3.6.3.cjs install --immutable``` to install the existing browser assets.

Copy ```.env.example``` to ```.env```, then set the required environment variables as explained later. Ensure that the ```PostgreSQL``` service is started and ready to accept connections on port ```5432```. Type ```bin/rails db:create```
and then ```bin/rails db:migrate```.
Optionally, you can type ```bin/rails db:seed``` to seed some sample data in the database. After these commands, everything is ready to launch RS_Server in _development_ or _production_ mode.

To do that, type ```bin/rails server -b 127.0.0.1 -p 3000 -e development```
with the proper values for ```-b```, ```-p``` and ```-e``` options. If the sample values are used, RS_Server will be started and bound
on the ```127.0.0.1``` IP address with port ```3000``` and ```development``` environment.
Every HTTP request, therefore, must be sent to the ```http://127.0.0.1:3000``` address.

<h3>Quick Cheatsheet</h3>

- ```cd``` to main directory;
- ```gem install bundler```;
- ```bundle install```;
- ```node .yarn/releases/yarn-3.6.3.cjs install --immutable```;
- copy ```.env.example``` to ```.env``` and populate it;
- ```bin/rails db:create```;
- ```bin/rails db:migrate```;
- ```bin/rails db:seed``` (optional);
- ```bin/rails server -b <your_ip_address> -p <your_port> -e development``` or ```bin/rails server -b <your_ip_address> -p <your_port> -e production```.

<h2>Modality 2: Manual (using Docker)</h2>

This modality allows to download and initialize RS_Server's codebase in a local machine using a faster and less frustrating approach
based on Docker, despite being less flexible. Docker is a project which allows automating the deployment phase by distributing an _image_ of an application inside a _container_.

An _image_ is a lightweight, standalone, and executable package of software that includes everything needed to run an application: code, runtime, tools, libraries and settings.
This means that there is no need to manually install the runtimes/libraries/dependencies needed to run an application since the Docker Engine will automatically initialize everything.

A _container_ is a standard unit of software that packages up code and all its dependencies so the application runs quickly and reliably from one computing environment to another.
Only a working installation of **Docker Desktop CE (Community Edition)** is required.

<h3>Requirements</h3>

- <a href="https://www.docker.com/products/docker-desktop">Docker Desktop CE (Community Edition)</a>.

<h3>How To</h3>

Clone this repository and move inside its main directory using a command line prompt.
Now, type ```ls``` or ```dir```; you should see a ```docker-compose.yml``` file and a ```Dockerfile```.
If you do not see them, please be sure to be in the main directory of the cloned repository.

Copy ```.env.example``` to ```.env``` and replace its placeholder values. Before proceeding, _be sure that your Docker Engine is running_, otherwise the following commands will not work.
The current Compose configuration builds RS_Server locally using Ruby 3.4 and starts PostgreSQL 17. Type
```docker compose up --build``` and wait for the image build and database health check to complete. A dedicated setup
service runs ```bin/rails db:prepare``` and must complete before the application starts. Seeding remains optional.

RS_Server will be bound to port ```3000``` in the ```production``` environment. Every HTTP request must therefore be sent to
```http://localhost:3000```. To seed sample data, type
```docker compose run --rm rs_server_webapp bin/rails db:seed```. To stop the containers, type ```docker compose down```.
The named volumes retain both the PostgreSQL data and the prepared publications when the containers are recreated.
The application container runs as an unprivileged user with a read only root file system. Temporary directories and the
private publication volume are the only writable application locations.

<h4>Quick Cheatsheet</h4>

- ```cd``` to main directory;
- copy ```.env.example``` to ```.env``` and populate it;
- ```docker compose up --build```;
- ```docker compose run --rm rs_server_webapp bin/rails db:seed``` (optionally);
- ```docker compose down``` (to stop and undeploy).

<h3>Environment Variables</h3>

Regardless of the chosen deployment modality, the developer must provide values for (at least a portion of) the _environment variables_,
as they cannot be checked into a repository due to safety reasons. In the following, each of these available variables is described
along with an explanation of which deployment modality requires their usage.

| Environment Variable      | Description                                                                              | Deploy Modality | Environment                         | Where To Set    |
|---------------------------|------------------------------------------------------------------------------------------|-----------------|-------------------------------------|-----------------|
| ```SECRET_DEV_KEY```      | Rails secret used to sign and encrypt development data, including paper rating references. | 1             | ```development```                   | ```.env``` file |
| ```SECRET_PROD_KEY```     | Rails secret used to sign and encrypt production data. Keep it stable while issued paper rating references must remain usable. | 1 - 2 | ```production``` | ```.env``` file |
| ```POSTGRES_USER```       | Username of the database user when a full connection URL is not supplied.                | 1 - 2           | all database environments           | ```.env``` file |
| ```POSTGRES_PASSWORD```   | Password of the database user.                                                           | 1 - 2           | all database environments           | ```.env``` file |
| ```POSTGRES_DB```         | Development or production database name. The default is ```rs_server```.                 | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```POSTGRES_TEST_DB```    | Test database name. The default is ```rs_server_test```.                                 | 1               | ```test```                          | ```.env``` file |
| ```POSTGRES_HOST```       | Database host. Compose supplies ```database```; the default elsewhere is ```localhost```. | 1 - 2          | all database environments           | ```.env``` file |
| ```DATABASE_URL```        | Full PostgreSQL connection string. It overrides the individual ```POSTGRES_``` variables. | 1 - 2          | ```development```, ```production``` | ```.env``` file |
| ```TEST_DATABASE_URL```   | Full PostgreSQL connection string for the test database.                                 | 1               | ```test```                          | ```.env``` file |
| ```SMTP_USERNAME```       | Username of the SMTP mail server.                                                        | 1 - 2           | ```production```                    | ```.env``` file |
| ```SMTP_PASSWORD```       | Password of the SMTP mail server.                                                        | 1 - 2           | ```production```                    | ```.env``` file |
| ```SMTP_DOMAIN_NAME```    | Domain of the SMTP mail server.                                                          | 1 - 2           | ```production```                    | ```.env``` file |
| ```SMTP_DOMAIN_ADDRESS``` | Full address of the SMTP mail server.                                                    | 1 - 2           | ```production```                    | ```.env``` file |
| ```EMAIL_BUG_REPORT```    | Email address to receive bug reports.                                                    | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```EMAIL_ADMIN```         | Email address to receive general questions.                                              | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```RAILS_LOG_TO_STDOUT``` | When present, forces the application to write its logs to the standard output.           | 1 - 2           | ```production```                    | ```.env``` file |
| ```RAILS_MAX_THREADS```   | Maximum thread count and database connection pool size. The default is 5.                | 1 - 2           | all environments                    | ```.env``` file |
| ```PUBLIC_BASE_URL```     | Public HTTP or HTTPS origin used for external links and allowed host validation. Required in production. | 1 - 2 | ```production``` | ```.env``` file |
| ```ADDITIONAL_ALLOWED_HOSTS``` | Additional accepted request hosts, separated by commas. Use only for trusted proxies or internal checks that cannot call ```/up```. | 1 - 2 | ```production``` | ```.env``` file |
| ```CORS_ALLOWED_ORIGINS``` | Origins allowed to call the API, separated by commas. In production, an omitted value disables requests from other origins. | 1 - 2 | ```production``` | ```.env``` file |
| ```FORCE_SSL```           | Set to ```true``` when the public instance is served through HTTPS.                      | 1 - 2           | ```production```                    | ```.env``` file |
| ```RS_PDF_MAX_DOWNLOAD_BYTES``` | Maximum accepted publication size in bytes. The default is 52428800 (50 MiB).     | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_OPEN_TIMEOUT``` | Maximum number of seconds allowed to open a publication connection. The default is 5.    | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_READ_TIMEOUT``` | Maximum number of seconds allowed while reading a publication response. The default is 20. | 1 - 2         | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_PROCESS_TIMEOUT``` | Maximum RS_PDF execution time in seconds. The default is 60.                          | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_ALLOW_PRIVATE_NETWORKS``` | Set to ```true``` only when publications must be fetched from a trusted private network. | 1 - 2 | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_STORAGE_ROOT``` | Private directory used for prepared publications. The default is ```storage/publications```. | 1 - 2 | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_DOWNLOAD_URL_TTL``` | Lifetime in seconds of a signed publication download URL. The default is 300.       | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```RS_AUTHENTICATION_RATE_LIMIT``` | Maximum authentication attempts from one IP address in three minutes. The default is 10. | 1 - 2 | ```development```, ```production``` | ```.env``` file |
| ```RS_PASSWORD_RECOVERY_IP_RATE_LIMIT``` | Maximum password recovery requests from one IP address in fifteen minutes. The default is 5. | 1 - 2 | ```development```, ```production``` | ```.env``` file |
| ```RS_PASSWORD_RECOVERY_ACCOUNT_RATE_LIMIT``` | Maximum password recovery requests for one normalized email address in thirty minutes. The default is 3. | 1 - 2 | ```development```, ```production``` | ```.env``` file |
| ```RS_CONTACT_RATE_LIMIT``` | Maximum contact messages from one IP address in ten minutes. The default is 5.          | 1 - 2           | ```development```, ```production``` | ```.env``` file |
| ```RS_PDF_PROCESSING_RATE_LIMIT``` | Maximum combined publication download, inspection, extraction, and annotation requests for one reader in one hour. The default is 30. | 1 - 2 | ```development```, ```production``` | ```.env``` file |

<h3>Setting Variables</h3>

To set the environment variables, copy `.env.example` to `.env` inside the main directory of RS_Server. Then replace the example values using the `key=value` form.

For a manual production installation connected through `DATABASE_URL`, the `.env` file can take the following form.

```
SECRET_PROD_KEY=your_secret_prod_key_value
DATABASE_URL=your_postgresql_database_connection_string
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
SMTP_DOMAIN_NAME=your_smtp_domain_name
SMTP_DOMAIN_ADDRESS=your_smtp_domain_address
EMAIL_BUG_REPORT=your_bug_report_mail
EMAIL_ADMIN=your_contact_mail
PUBLIC_BASE_URL=https://your-readersourcing-domain.example
```

When using the supplied Compose configuration, replace `DATABASE_URL` with `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_DB`. Compose supplies `POSTGRES_HOST=database` to RS_Server so that it can reach the database container.

`PUBLIC_BASE_URL` must contain only the public origin of RS_Server, including the scheme and optional port, without a path,
query string, fragment, or credentials. Production refuses to start without this value and accepts that host by default.
For a public instance, set `FORCE_SSL=true` after HTTPS has been configured.
Set `CORS_ALLOWED_ORIGINS` to the exact origins of web clients that may call the API, separated by
commas. RS_Rate requests browser permission for the selected RS_Server origin and therefore does not depend on its
generated extension origin being listed here. Supplying `CORS_ALLOWED_ORIGINS=*` permits requests from every origin and
should be reserved for deployments that deliberately need it.

Rate limit counters use the configured Rails cache store. The supplied Puma configuration runs one process and uses a
store in memory. A deployment with multiple server processes or replicas must use a shared Active Support cache store so
that every instance contributes to the same counters.

The web interface keeps its authentication token only in the encrypted Rails session, whose cookie is marked `HttpOnly`.
Its JSON requests carry the Rails CSRF token and do not expose the JWT to browser scripts. The `authenticate` response
still returns the JWT so that RS_Rate, RS_Py, and other API clients can send it through `Authorization`. Requests that use
this header remain stateless.

Publication records are shared among readers. The API therefore exposes their creation and retrieval, together with the
dedicated fetching and refresh operations, but does not expose generic update or deletion routes.

Prepared publications are stored outside the public asset directory. The `pdf_download_url` and
`pdf_download_url_link` response fields contain signed URLs that are bound to one reader, publication, variant, and file
name. They expire after five minutes by default and are returned with private, non cacheable response headers. This keeps
the existing browser and RS_Rate workflow, which opens the annotated file in a new tab without adding an authorization
header. Logging out does not revoke a URL that has already been issued; its remaining lifetime is deliberately short.
The `pdf_storage_path` and `pdf_download_path` fields remain logical compatibility metadata and are not public file paths.

An installation that still keeps prepared files under `public/user` can move them to the private directory once by
running `bin/rails publications:migrate_private_storage`. The task stops if the destination already exists, so it does not
merge two storage trees implicitly. Files can instead be prepared again if the old copies are no longer required.

The endpoint `GET /up` reports whether Rails can boot successfully and can be used for local or load balancer health
checks. Database preparation is not part of the server entrypoint. On a container platform, run `bin/rails db:prepare`
once as a separate deployment task before starting or replacing the application process.

The publication preparation API returns a stable `status` for recoverable failures, including unavailable sources,
authentication requirements, size limits, malformed or encrypted PDFs, RS_PDF failures, and final verification failures.
`POST /publications/fetch_upload.json` provides the local file alternative and retains `publication[pdf_url]` as the stable
identifier of the publication. The source Postman collection documents both preparation methods.

RS_Server sends a Content Security Policy with every response. Browser scripts, styles, and fonts are installed through
Yarn and served by the Rails asset pipeline. Their direct versions are declared in `package.json`, while `yarn.lock`
records the complete dependency graph. The visual dependencies remain within the compatibility lines required by the
interface. DataTables, JSZip, and js-cookie use versions that address their known registry advisories while preserving the
APIs used here. Pdfmake uses the 0.2 compatibility line required by the DataTables integration. Tables, icons, typography,
and exports consequently retain their behaviour.

The views contain a small number of style attributes, so styles declared directly in a page remain permitted
while scripts declared in the page remain disabled. Pdfmake and its font data are loaded only on the authenticated
publication and reader list pages, where they provide the PDF export behaviour without allowing dynamic code
evaluation. The policy also prevents framing, external form targets, and object content.
Access to browser capabilities is disabled for the camera, screen capture, location, microphone, payment, and USB
interfaces. Rails adds HSTS only when `FORCE_SSL=true`.

<h3>Sending Mails</h3>

RS_Server supports any mail server compatible with SMTP to send emails for tasks such as confirming user registration, reporting bugs,
or recovering forgotten passwords. Password recovery emails contain a link that remains valid for four hours and can be used
once to choose a new password; passwords themselves are never sent by email.

Understanding the values used to populate the `SMTP_` environment variables can sometimes lead to ambiguity. Let's consider
the case of [Twilio Sendgrid](https://sendgrid.com/). After creating an account, you need to verify a single
sender address or a whole domain using the provided DNS records. To integrate the service into an instance of RS_Server
you must use a supported [SMTP configuration](https://app.sendgrid.com/guide/integrate/langs/smtp).
Thus, the values of the environment variables must be in this form:

- ```SMTP_USERNAME```: ```apikey```
- ```SMTP_PASSWORD```: ```<your_api_key_value>```
- ```SMTP_DOMAIN_NAME```: ```<your_domain_address>```
- ```SMTP_DOMAIN_ADDRESS```: ```smtp.sendgrid.net```

<h3>Connecting To The Database</h3>

A full connection string to a PostgreSQL database provided through the `DATABASE_URL` variable **takes precedence** over
each `POSTGRES_` variable. It is thus important to provide the former environment variable or the set of the latter ones.
This holds for both the _development_ and _production_ environments. Indeed, the final connection string is built as such:

```
<%= ENV['DATABASE_URL'] || "postgresql://#{ENV['POSTGRES_USER'] || 'postgres'}:#{ENV['POSTGRES_PASSWORD']}@#{ENV['POSTGRES_HOST'] || 'localhost'}/#{ENV['POSTGRES_DB'] || 'rs_server'}" %>
```

<h3>Logging To The Standard Output</h3>

An instance of RS_Server deployed in development writes its logs to the standard output as the default behavior.
In a _production_ environment, on the other hand, the logs are written in the `log/production.log` file. Thus,
forcing Rails to write logs in the standard output using the `RAILS_LOG_TO_STDOUT` variable can be useful for quick
debugging purposes when testing the _production_ environment.

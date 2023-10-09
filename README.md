[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/Naereen/StrapDown.js/graphs/commit-activity)
![Maintainer](https://img.shields.io/badge/maintainer-Miccighel-blue)
[![Github all releases](https://img.shields.io/github/downloads/Miccighel/Readersourcing-2.0-RS_Server/total.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/releases/)
[![GitHub stars](https://badgen.net/github/stars/Miccighel/Readersourcing-2.0-RS_Server)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/stargazers/)
[![GitHub watchers](https://badgen.net/github/watchers/Miccighel/Readersourcing-2.0-RS_Server/)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/watchers/)
[![GitHub contributors](https://img.shields.io/github/contributors/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/graphs/contributors/)[![GitHub
issues](https://badgen.net/github/issues/Miccighel/Readersourcing-2.0-RS_Server/)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/issues/)
[![GitHub issues](https://img.shields.io/github/issues/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/issues/)
[![GitHub issues-closed](https://img.shields.io/github/issues-closed/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/pull/)
[![GitHub pull-requests closed](https://img.shields.io/github/issues-pr-closed/Miccighel/Readersourcing-2.0-RS_Server.svg)](https://GitHub.com/Miccighel/Readersourcing-2.0-RS_Server/pull/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

Readersourcing 2.0: _An independent, third-party, no-profit, academic project aimed at quality rating of scholarly literature and scholars._

<h1>Info</h1>

This is the official repository of **RS_Server**, which is part of the **Readersourcing 2.0** ecosystem.
This repository is a <a href="https://git-scm.com/book/it/v2/Git-Tools-Submodules">Git Submodule</a> of the main project,
whose components can be found by taking advantage of the links below.

<h1>Useful Links</h1>

- <a href="https://readersourcing.org">Readersourcing 2.0 (Web Interface)</a>
- <a href="https://github.com/Miccighel/Readersourcing-2.0">Readersourcing 2.0 (GitHub)</a>
- <a href="https://link.springer.com/chapter/10.1007/978-3-030-11226-4_21">Original Article (Springer Link)</a>
- <a href="https://zenodo.org/record/1446468">Original Article (Zenodo)</a>
- <a href="https://zenodo.org/record/1452397">Technical Documentation (Zenodo)</a>
- <a href="https://github.com/Miccighel/Readersourcing-2.0-TechnicalDocumentation"> Technical Documentation (GitHub)</a>
- <a href="https://documenter.getpostman.com/view/4632696/RWTiwfV4?version=latest">RESTful API Interface</a>
- <a href="https://doi.org/10.5281/zenodo.1442630">Zenodo Record</a>
- <a href="https://cloud.docker.com/repository/docker/miccighel/rs_server">Docker Hub</a>

<h1>Description</h1>

**RS_Server** is the server-side component which has the task of collecting and aggregating the ratings given by readers and using the ```Readersourcing```-based models to compute quality scores for readers and publications.
It is deployed together with an instance of <a href="https://github.com/Miccighel/Readersourcing-2.0-RS_PDF">RS_PDF</a>.
The server-side component exposes a RESTful API Interface and provides a stand-alone web interface to interact directly with the APIs.
Furthermore, there can be different browsers along with their end-users that communicate with the APIs of the server-side component by using
an instance of <a href="https://github.com/Miccighel/Readersourcing-2.0-RS_Rate">RS_Rate</a>, that is, a browser extension.
Thus, every interaction between human readers and the APIs exposed by RS_Server can be carried out through clients installed on readers' browsers or by using the stand-alone web
interface provided. These clients handle the registration and authentication of readers, the rating action and the download action of link-annotated publications.

<h1>Deploy</h1>

There are three main modalities that can be used to deploy a working instance of RS_Server in the **development** or **production** environment.
The former environment must be used if there is the need to:
- add custom ```Readersourcing```-based models;
- extend/modify the current implementation of RS_Server;
- simply to test it in a safe way.

In the following, three deployment modalities to obtain a working instance of RS_Server are described, along with their requirements.
The first two modalities allow both to start RS_Server on the local machine allowing editing of its source code and to
build a Docker image which can be deployed by local containers in a **production**-ready environment.
The third modality allows for deploying RS_Server as a Heroku application.

Please, be sure to read the section dedicated to the **environment variables**, since RS_Server will not work properly without them.

<h2>Modality 1: Manual</h2>

This modality allows to manually download and initialize RS_Server's codebase in a local machine.
This is the most demanding modality in terms of prerequisites since it assumes having a full and working installation of
```Ruby```, ```JDK``` (Java Development Kit) and ```PostgreSQL```. Despite that, it provides more flexibility.

<h3>Requirements</h3>

 - <a href="https://www.ruby-lang.org/en/downloads/">Ruby</a> == 2.7.8;
 - <a href="https://www.oracle.com/it/java/technologies/javase/jdk11-archive-downloads.html">JDK (Java Development Kit)</a> == 11.0.19;
 - <a href="https://www.postgresql.org/download/">PostgreSQL</a> > == 11.2.
 
 <h3>How To</h3>

 Clone this repository and move inside its main directory using a command line prompt
 (with an ```ls``` or ```dir``` command you should see ```app```, ```bin```, ```config```, etc. folders) and type ```gem install bundler```.
 This gem (dependency) will provide a consistent environment for Ruby-based projects (as RS_Server) by tracking and installing the exact gems (dependencies) and versions needed.
 To fetch all those required by RS_Server type ```bundle install``` and wait for the process to complete.
 The next two commands are required only before the first startup of RS_Server because they will create and set up the database.
 Please, be sure that your PostgreSQL service is started up and ready to accept connections on port ```5432```.
 Type ```rails db:create``` to create the database and ```rails db:migrate``` to create the required schema.
 Optionally, you can type ```rails db:seed``` to seed some sample data in the database.
 After these commands, everything is ready to launch RS_Server in _development_ or _production_ mode.
 To do that, just type ```cd bin``` to move inside ```bin``` directory and then type ```rails server -b 127.0.0.1 -p 3000 -e development```
 with the proper values for ```-b```, ```-p``` and ```-e``` options. If the sample values are used, RS_Server will be started and bound
 on the ```127.0.0.1```IP address with port ```3000``` and ```development``` environment.
 Every HTPP request, therefore, must be sent to the ```http://127.0.0.1:3000``` address.

<h3>Quick Cheatsheet</h3>

- ```cd``` to main directory;
- ```gem install bundler```;
- ```bundle install```;
- ```rails db:create```;
- ```rails db:migrate```;
- ```rails db:seed``` (optional);
- ```cd bin```;
- ```rails server -b <your_ip_address> -p <your_port> -e development``` or ```rails server -b <your_ip_address> -p <your_port> -e production```.

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
Before proceeding, _be sure that your Docker Engine is running_, otherwise the following commands will not work.
At this point, two different scenarios can take place.

<h4>Scenario 1: Deploy With Remote Images</h4>

If there is no need to edit the source code of RS_Server, the _Docker Engine_ can fetch the dependencies required in the ```docker-compose.yml``` file and initialize the application.
The dependencies specified in the file are an image of PostgreSQL for the database and one of RS_Server itself, released on the <a href="https://cloud.docker.com/repository/docker/miccighel/rs_server">Docker Hub</a> by myself.
To do this, open the ```docker-compose.yml``` file and uncomment the following section:
```
----------- SCENARIO 1: DEPLOY WITH REMOTE IMAGES ----------
...
----------- END OF SCENARIO 1: DEPLOY WITH REMOTE IMAGES ----------
```
and comment on the remaining lines of code. Next, from the command line prompt type ```docker-compose up``` and wait for the process to finish. Note that it may take different minutes.
Once the Docker Engine completes the process, a container with a working instance of RS_Server will be started up.
Optionally, you can type ```docker-compose run rails db:seed``` to seed some sample data in the database.
RS_Server will be started and bound on ```0.0.0.0```IP address with port ```3000``` and ```production``` environment.
Every HTTP request, therefore, must be sent to the ```http://0.0.0.0:3000``` address.
As can be seen, there is no need to manually start the server by specifying its IP address, port and environment, or to create and migrate the database.
The Docker Engine will perform that automatically. If you want to set a custom IP address or port or switch to the _production_ environment,
edit the ```command``` key inside the ```docker-compose.yml``` file. To stop the container, simply type ```docker-compose down```.

<h4>Scenario 2: Deploy With Local Build</h4>

If the source code of RS_Server has been edited the application must be built from scratch by the Docker Engine according to the structure specified in the ```Dockerfile```.
After the image build phase, the Docker Engine can fetch the required dependencies outlined in the ```docker-compose.yml``` file and initialize RS_Server, as in the previous scenario.
To do this, open the ```docker-compose.yml``` file and uncomment the following section:
```
-----------  SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------
...
----------- END OF SCENARIO 2: DEPLOY WITH LOCAL BUILD -----------
```
and comment on the remaining lines of code. Next, from the command line prompt type ```docker-compose up``` and wait for the process to finish.
Note that it may take different minutes. Once the Docker Engine completes the process, a container with a working instance of RS_Server will be started
and bound on ```0.0.0.0```IP address with port ```3000``` and ```production``` environment. Therefore, every request must be sent to ```http://0.0.0.0:3000``` address.
Similarly to the previous scenario, there is no need to manually start the server by specifying its IP address, port and environment, or to create and migrate the database.
If you want to set a custom IP address or port or switch to the _production_ environment,
edit the ```command``` key inside the ```docker-compose.yml``` file. To stop the container, simply type ```docker-compose down```.

<h4>Quick Cheatsheet</h3>

- ```cd``` to main directory;
- ```docker-compose up```;
- ```docker-compose run rails db:seed``` (optional);
- ```docker-compose down``` (to stop and undeploy).

<h2>Modality 3: Deploy on Heroku</h2>

**Heroku** is a cloud platform-as-a-service (PaaS) that allows developers to build, deploy, and scale web applications and services with ease.
This deploy modality allows for using its container registry to perform a Docker-based production-ready deployment of RS_Server on the platform using
the **Heroku Command Line Interface (CLI)**. Note that such a modality can be used only with the _production_ environment of the application.
Regarding the prerequisites of this modality, the developer must create an `app` on Heroku.
Then, it has to be _provisioned_ with two addons, namely <a href="https://elements.heroku.com/addons/heroku-postgresql">PostgreSQL</a>
for the database and one for the mail-related functionalities, such as <a href="https://elements.heroku.com/addons/sendgrid">Twilio SendGrid</a>.
The Heroku tutorials provide an adequate overview of the platform. Also, a working installation of **Docker Desktop CE (Community Edition)** on the machine used to perform the deployment is required.

<h3>Requirements</h3>

- Heroku account;
- Heroku application provisioned with:
-  - <a href="https://elements.heroku.com/addons/heroku-postgresql">PostgreSQL</a> addon;
-  - a mail-related addon such as <a href="https://elements.heroku.com/addons/sendgrid">Twilio SendGrid</a>.;
- <a href="https://devcenter.heroku.com/articles/heroku-cli">Heroku CLI</a>;
- <a href="https://www.docker.com/products/docker-desktop">Docker Desktop CE (Community Edition)</a>. 

<h3>How To</h3>

Clone this repository and move inside the main directory using a command line prompt. Now, type ```ls``` or ```dir```; you should see a ```Dockerfile```.
If you do not see them, please be sure to be in the main directory of the cloned repository.
Before proceeding, _be sure that your Docker Engine is running_, otherwise the following commands will not work.
Log in using your credentials by typing ```heroku login```. Next, log in to the Heroku container registry by typing ```heroku container:login```.
To build and upload your instance of RS_Server using Docker type ```heroku container:push web --app your-app-name```
and when the process terminates type ```heroku container:release web``` to make it publicly accessible.
Optionally, you can type ```heroku run rails db:seed``` to seed some sample data in the database.
and ```heroku open``` to open the browser and be redirected to the homepage of the ```<your_app_name>``` application.
 Similarly to the previous modality, there is no need to manually start the server by specifying its IP address, port and environment, or to create and migrate the database,
 since Heroku (through the Docker Engine) will take care of that for you.

<h4>Quick Cheatsheet</h3>

- ```cd``` to main directory;
- ```heroku login```;
- ```heroku container:login```;
- ```heroku container:push web --app <your-app-name>```;
- ```heroku container:release web --app <your-app-name>```;
- ```heroku open --app <your-app-name>``` (optional);

<h3>Environment Variables</h3>

Regardless of the chosen deployment modality, the developer must provide values for (at least part of) the
_environment variables_, as they cannot be checked into a repository due to safety reasons. In the following,
each of these available variables is described along with an explanation of which deployment modality requires their usage.

| Environment Variable | Description   | Deploy Modality | Environment   | Where To Set  |
|----------------------| ------------- | -------------   | ------------- | ------------- |
| ```SECRET_DEV_KEY```      | Private key used to encrypt strings in the ```development``` environment.         | 1 - 2     | ```development```                   | ```.env``` file             |
| ```SECRET_PROD_KEY```     | Private key used to encrypt strings in the ```production``` environment.          | 1 - 2 - 3 | ```production```                    | ```.env``` file, Heroku app |
| ```POSTGRES_USER```       | Username the admin user of the database.                                          | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```POSTGRES_PASSWORD```   | Password of the admin user of the database.                                       | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```POSTGRES_DB```         | Name of the database.                                                             | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```POSTGRES_HOST```       | Hosting address of the database.                                                  | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```DATABASE_URL```        | Full connection PostgreSQL connection string of the database.                     | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```SMTP_USERNAME```       | Username of the SMTP mail server.                                                 | 1 - 2 - 3 | ```production```                    | ```.env``` file, Heroku app |
| ```SMTP_PASSWORD```       | Password of the SMTP mail server.                                                 | 1 - 2 - 3 | ```production```                    | ```.env``` file, Heroku app |
| ```SMTP_DOMAIN_NAME```    | Domain of the SMTP mail server.                                                   | 1 - 2 - 3 | ```production```                    | ```.env``` file, Heroku app |
| ```SMTP_DOMAIN_ADDRESS``` | Full address of the SMTP mail server.                                             | 1 - 2 - 3 | ```production```                    | ```.env``` file, Heroku app |
| ```EMAIL_BUG_REPORT```    | Email address to receive bug reports.                                             | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```EMAIL_ADMIN```         | Email address to receive general questions.                                       | 1 - 2 - 3 | ```development```, ```production``` | ```.env``` file, Heroku app |
| ```RAILS_LOG_TO_STD```    | When ```true```, forces the application to write its logs to the standard output. | 1 - 2 - 3 | ```production```                    | ```.env``` file, Heroku app |

<h4>Additional Remarks</h4>

<h5>Sending Mails</h5>

RS_Server supports any SMTP-based mail server to send emails to confirm user registration, report bugs, recover forgotten passwords, etc.
Often, understanding which values are used to populate the ```SMTP_``` environment variables can lead to ambiguity. Let us consider the case of the proposed add-on,
<a href="https://sendgrid.com/">Twilio Sendgrid</a>. After creating the account, you have to verify a single sender address or a whole domain using the provided DNS records. Then,
to integrate the service in an instance of RS_Server deployed anywhere outside Heroku, a supported <a href="https://app.sendgrid.com/guide/integrate/langs/smtp">SMTP configuration</a> must be used.
In this case, the values of the environment variables must be in this form:

- ```SMTP_USERNAME```: ```apikey```
- ```SMTP_PASSWORD```: ```<your_api_key_value>```
- ```SMTP_DOMAIN_NAME```: ```<your_domain_address>```
- ```SMTP_DOMAIN_ADDRESS```: ```smtp.sendgrid.net```
However, while using the <a href="https://elements.heroku.com/addons/sendgrid">addon provided by Heroku</a>, the values provided for the environment variables need to be slightly different:
- ```SMTP_USERNAME```: ```<your_sendgrid_account_username>```
- ```SMTP_PASSWORD```: ```<your_sengrid_password_account>```
- ```SMTP_DOMAIN_NAME```: ```<your_domain_address>```
- ```SMTP_DOMAIN_ADDRESS```: ```smtp.sendgrid.net```

<h5>Connecting To The Database</h5>

A full connection string to a PostgreSQL database provided through the ```DATABASE_URL``` variable  _takes precedence_ over each ```POSTGRES_``` variable.
It is thus important to provide the former environment variable or the set of the latter ones. This holds for both the _development_ and _production_ environments.
Indeed, the final connection string is built as such:
```
<%= ENV['DATABASE_URL'] || "postgresql://#{ENV['POSTGRES_USER'] || 'postgres'}:#{ENV['POSTGRES_PASSWORD']}@#{ENV['POSTGRES_HOST'] || 'localhost'}/#{ENV['POSTGRES_DB'] || 'rs_server'}" %>
```
<h5>Logging To The Standard Output</h5>

An instance of RS_Server deployed in development writes its logs to the standard output as the default behaviour.
In a production environment, on the other hand, the logs are written in the ```logs/production.log``` file.
Thus, forcing Rails to write logs in the standard output using the ```RAILS_LOG_TO_STD``` variable can be useful for quick debugging purposes when testing the _production_ environment.

<h4>Setting Variables</h4>

To set an environment variable in a local ```.env``` file, create it inside the main directory of RS_Server. Then, populate it in a ```key=value``` fashion.
To provide an example, the following is the content of a valid ```.env``` file.ß
To set an environment variable in a Heroku app, simply follow <a href="https://devcenter.heroku.com/articles/config-vars">this guide</a>.
In Heroku terminology, environment variables are called ```config vars```.

```
SECRET_PROD_KEY=your_secret_prod_key_value
DATABASE_URL=your_postgresql_database_connection_string
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
SMTP_DOMAIN_NAME=your_smtp_domain_name
SMTP_DOMAIN_ADDRESS=your_smtp_domain_address
EMAIL_BUG_REPORT=your_bug_report_mail
EMAIL_ADMIN=your_contact_mail
```
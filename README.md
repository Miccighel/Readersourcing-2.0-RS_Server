<h1>Info</h1>

This is the official repository of the **Readersourcing 2.0 ecosystem** which has been presented for the first time during the <a href="https://ircdl2019.isti.cnr.it/">IRCDL 2019</a> conference. The original article can be freely read on <a href="https://zenodo.org/record/1446468">Zenodo</a>. This repository is an aggregation of <a href="https://git-scm.com/book/it/v2/Git-Tools-Submodules">Git Submodules</a>, which means that each of three folders is a pointer to a different repository, where each of them is a software component of Readersourcing 2.0. This README is an aggregation of the READMEs of these software components, so it is possible to consult it here in its entirety or independently in the aggregated repositories. 

<h1>RS_Server</1>

<h2>Read this!</h2>

Please, note that this is an early alpha release and it is not ready for the use in a production environment.

<h2>Useful Links</h2>

- <a href="https://zenodo.org/record/1446468">Original Article</a>
- <a href="https://zenodo.org/record/1452397">Technical Documentation (Zenodo)</a>
- <a href="https://github.com/Miccighel/Readersourcing-2.0-TechnicalDocumentation"> Technical Documentation (GitHub)</a>
- <a href="https://web.postman.co/collections/4632696-c26fc049-7021-4691-beb3-97cebfb60adb?workspace=8a3ef37e-60b1-4b49-8782-e73d2a6e3a8c">RESTful API Interface</a>
- <a href="https://doi.org/10.5281/zenodo.1442630">Zenodo Record</a>

<h2>Description</h2>

RS_Server is the server-side application which has the task to collect and aggregate the ratings given by readers and to use the Readersourcing models to compute quality scores for readers and publications. An instance of RS_Server is deployed along one of <a href="https://github.com/Miccighel/Readersourcing-2.0-RS_PDF">RS_PDF</a>. Then, there are up to n different browsers along with their end-users, which communicate with the server-side application itself; each of them is characterized by an instance of <a href="https://github.com/Miccighel/Readersourcing-2.0-RS_Rate">RS_Rate</a>. This setup means that every interaction between readers and server can be carried out through clients installed on readers' browsers or by using the stand-alone web interface provided by RS_Server and these clients have to handle the registration and authentication of readers, the rating action and the download action of link-annotated publications.

<h2>Deploy</h2>

There are three main modalities that can be exploited to deploy a working instance of RS_Server in **development** or **production** environment. The former environment must be used if there is the need to add custom Readersourcing model, to extend/modify the current implementation of RS_Server or simply to test it in a safe way and it is allowed only by deploy modalities 1 and 2, while the latter must be used if RS_Server is about to be used in production as it is and it is allowed by every deploy modality. In the following these three  deploy modalities are described, along with their requirements. Please, be sure to read also the section dedicated to the **environment variables**, since if they are not set RS_Server will not work properly.

<h3>1: Manual Way</h3>

This deploy modality allows to manually downwload and start RS_Server locally to a machine chosen as a server. This is the most demading modality regarding is requirements since it assumes that you have a full and working installation of **Ruby**, **JRE** (Java Runtime Environment) and **PostgreSQL** and everything must be set up manually, but it allows more flexibility if a particular setup is required for any reason. 

<h4>Requirements</h4>

 - <a href="https://www.ruby-lang.org/en/downloads/">Ruby</a> >= 2.4.4;
 - <a href="https://www.java.com/it/download/">JRE (Java Runtime Environment)</a> >= 1.8.0;
 - <a href="https://www.postgresql.org/download/">PostgreSQL</a> >= 10.5.
 
 <h4>How To</h4>

Clone this repository and move inside its main directory using a command line prompt (with an ```ls``` or ```dir``` command you should see ```app```, ```bin```, ```config```, etc. folders) and type ```gem install bundler```. This gem (dependency) will provides a consistent environment for Ruby projects (like RS_Server) by tracking and installing the exact gems (dependencies) and versions that are needed. To fetch all those required by RS_Server type ```bundle install``` and wait for the process to complete. The next two commands _are required only before the first startup of RS_Server_  because they will create and set up the database, so please be sure that the  PostgreSQL service is started up and ready to accept connections on port 5432. Type ```rake db:create``` to create the database and ```rake db:migrate``` to create the required tables inside it. After these commands, everything is ready to launch RS_Server in development or production mode. To do that, just type ```cd bin``` to move inside ```bin``` directory and then ```rails server -b 127.0.0.1 -p 3000 -e development``` with the proper values for ```-b```, ```-p``` and ```-e``` options. If the previous values are used, RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```development``` environment. Every request, therefore, must be sent to ```https://127.0.0.1:3000``` address.  

<h4>Quick Cheatsheet</h4>

- ```cd``` to main directory;
- ```gem install bundler```;
- ```bundle install```;
- ```rake db:create``` (only before first startup);
- ```rake db:migrate``` (only before first startup);
- ```cd bin```;
- ```rails server -b x.x.x.x -p x -e development``` or ```rails server -b x.x.x.x -p x -e production```.

<h3>2: Manual Way (But Faster)</h3>

This deploy modality allows to downwload and start RS_Server locally to a machine chosen as a server like the first one, but in a way which is faster and less frustrating, despite being less flexible. Moreover, this deploy modality have less demanding requirements, since only a working installation of **Docker Desktop CE (Community Edition)** is required. Docker is a project which allows to automate the deployment phase by distributing an _image_ of an application inside a _container_. A container is a standard unit of software that packages up code and all its dependencies so the application runs quickly and reliably from one computing environment to another. A Docker container image is a lightweight, standalone, executable package of software that includes everything needed to run an application: code, runtime, system tools, system libraries and settings. This means that there is no need to manually install the runtimes/libraries/dependencies needed to run an application since the Docker Engine will automatically fetch, install and setup them.

<h4>Requirements</h4>

- <a href="https://www.docker.com/products/docker-desktop">Docker Desktop CE (Community Edition)</a>. 

<h4>How To</h4>

Clone this repository and move inside its main directory using a command line prompt. Now, type ```ls``` or ```dir```; you should see a ```docker-compose.yml``` file and a ```Dockerfile```. If you do not see them, please be sure to be in the main directory of the cloned repository. Before proceeding, _be sure that your Docker Engine has been started up, otherwise the following commands will not work_. At this point two different scenarions could happen, which are outlined in the following. 

<h5>Scenario 1: Deploy With Remote Images</h5>

If there is no need to edit the source code of RS_Server the _Docker Engine_ can simply fetch the dependencies required in the ```docker-compose.yml``` file and set up the application. To do this, open the ```docker-compose.yml``` file and uncomment the section between the ```----------- SCENARIO 1: DEPLOY WITH REMOTE IMAGES ----------``` and ```----------- END OF SCENARIO 1: DEPLOY WITH REMOTE IMAGES ----------``` comments and comment back the remaining lines of code. Next, from the command line prompt type ```docker-compose up``` and wait for the processing to finish. Note that it may take different minutes. Once the Docker Engine completes the process, the container with a working instance of RS_Server will be started up. _If the first startup of the application is being done_ type also ```docker-compose run rake db:create``` to create the database and ```docker-compose run rake db:migrate``` to create the required tables inside it. RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```production``` environment. Every request, therefore, must be sent to ```https://127.0.0.1:3000``` address. As it can be seem, there is no need to start the server by specifing its ip address, port and environment, since the Docker Engine will take care of that. If you want to set a custom ip address or port or switch to the _development_ environent, edit the ```command``` key inside ```docker-compose.yml``` file. To shutdown and undeploy the container, simply type ```docker-compose down```.

<h5>Scenario 2: Deploy With Local Build</h5>

If the source code of RS_Server has been edited the application must be built locally by the Docker Engine according to the structure specified in the ```Dockerfile```. After this build phase the Docker Engine itself can simply fetch the required dependencies outlined in the ```docker-compose.yml``` file and set RS_Server up. To do this, open the ```docker-compose.yml``` file and uncomment the section between the ```-----------  SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------``` and ```----------- END OF SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------- ``` comments and comment back the remaining lines of code. Now, from the command line prompt type ```docker-compose up``` and wait for the process to finish. Note that it may take different minutes. Once the Docker Engine completes the process, the container with a working instance of RS_Server will be ready. _If the first startup of the application is being done_ type also ```docker-compose run rake db:create``` to create the database and ```docker-compose run rake db:migrate``` to create the required tables inside it. RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```production``` environment. Therefore, every request must be sent to ```https://127.0.0.1:3000``` address. As it can be seen, there is no need to start the server by specifing its ip address, port and environment, since the Docker Engine will take care of that. If you want to set a custom ip address or port or switch to the _development_ environent, edit the ```command``` key inside ```docker-compose.yml``` file. To shutdown and undeploy the container, simply type ```docker-compose down```.

<h4>Quick Cheatsheet</h4>

- ```cd``` to main directory;
- ```docker-compose up```;
- ```docker-compose run rake db:create``` (only at first startup);
- ```docker-compose run rake db:migrate``` (only at first startup);
- ```docker-compose down``` (to shutdown and undeploy).

<h3>3: Heroku Deploy</h3>

This deploy modality allows to exploit the container registry of **Heroku** to perform a docker-based production-ready deploy of RS_Server through a working installation of the **Heroku Command Line Interface (CLI)**. Note that this modality can be used only if you choose to use RS_Server in _production_ environment. Heroku is Platform-as-a-Service (PaaS) that enables developers to build, run, and operate applications entirely in the cloud. Regarding the requirements of this modality, an _app_ on Heroku must be created and _provisioned_ with two addons, namely _PostgreSQL_ for the database and _SendGrid_ for the mailing functionalities. Follow Heroku tutorials if you do not know it and its concepts. Also, a working installation of **Docker Desktop CE (Community Edition)** on the machine used to perform the deploy is required.

<h4>Requirements</h4>

- Heroku account;
- Heroku application (PostgreSQL + SendGrid Addons);
- <a href="https://devcenter.heroku.com/articles/heroku-cli">Heroku CLI</a>;
- <a href="https://www.docker.com/products/docker-desktop">Docker Desktop CE (Community Edition)</a>. 

<h4>How To</h4>

Clone this repository and move inside the main directory using a command line prompt. Now, type ```ls``` or ```dir```; you should see a ```Dockerfile```. If you do not see it, please be sure to be in the main directory of the cloned repository. Before proceeding, _be sure that your Docker Engine has been started up, otherwise the following commands will not work_. Log in to your Heroku account by typing ```heroku login``` and insert your credentials. Next, log in to Heroku container registry by typing ```heroku container:login```. To build and upload your instance of RS_Server type ```heroku container:push web --app your-app-name``` and when the process terminates type ```heroku container:release web``` to make it publicy accessible. Optionally, you can type ```heroku open``` to open the browser and be redirected on the homepage of  ```your_app_name``` application. To create and set up the database type ```heroku run rake db:create``` and ```heroku run rake db:migrate```. As you can see, there is no need to start the server by specifing its ip address, port and environment, since Heroku (through the Docker Engine) will take care of that for you.

<h4>Quick Cheatsheet</h4>

- ```cd``` to main directory;
- ```heroku login```;
- ```heroku container:login```;
- ```heroku container:push web --app your-app-name```;
- ```heroku container:release web --app your-app-name```;
- ```heroku open --app your-app-name``` (optional);
- ```heroku run rake db:create --app your-app-name```;
- ```heroku run rake db:migrate --app your-app-name```.

<h3>Environment Variables</h3>

Regardless of the chosen deploy modality, there is the need to set some environment variables which cannot be checked into a repository as a safety measure. In the following each of these environment variables is described along with an explanation of where to set them on the basis of the chosen deploy modality/environment. 

| Environment Variable  | Description | Deploy Modality | Environment | Where To Set |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| SECRET_DEV_KEY  | Private key used to encrypt some strings  | 1 - 2 (Scenario 1, Scenario 2) | development | ```.env``` file |
| SECRET_PROD_KEY  | Private key used to encrypt some strings  | 1 - 2 (Scenario 1, Scenario 2) - 3 | production | ```.env``` file, Heroku App |
| SENDGRID_USERNAME  | Username of your SendGrid account | 1 - 2 (Scenario 1, Scenario 2) - 3 | development, production | ```.env``` file , Heroku App|
| SENDGRID_PASSWORD  | Password of your SendGrid account | 1 - 2 (Scenario 1, Scenario 2) - 3 | development, production | ```.env``` file , Heroku App|
| SENDGRID_API_KEY  | API key of your SendGrid account | 1 - 2 (Scenario 1, Scenario 2) - 3 | development, production | ```.env``` file , Heroku App|
| SENDGRID_DOMAIN  | A domain registered within your SendGrid account | 1 - 2 (Scenario 1, Scenario 2) - 3 | development, production | ```.env``` file , Heroku App|
| RECAPTCHA_SECRET_KEY  | Private key used by Google ReCAPTCHA v2 within a registered domain | 1 - 2 (Scenario 1, Scenario 2) - 3 | development, production | ```.env``` file , Heroku App|
| RECAPTCHA_SITE_KEY  | API key of your Google ReCAPTCHA v2 account | 1 - 2 (Scenario 1, Scenario 2) - 3 | development, production | ```.env``` file , Heroku App|
| RAILS_LOG_TO_STD  | If set to ```true```, Rails writes its logs to the standard output. Useful for debugging purposes. | 3 | production | ```.env``` file, Heroku App |

<h4>.env File</h4>
 
 To set an environment variable in a local ```.env``` file, create it inside the main directory of RS_Server. Then, populate it in a ```key=value``` fashion. To provide an example, the following is the content of a valid ```.env``` file:

```
SECRET_DEV_KEY=your_secret_dev_key
SENDGRID_USERNAME=your_sendgrid_username
SENDGRID_PASSWORD=your_sendgrid_password
SENDGRID_DOMAIN=your_sendgrid_domain
SENDGRID_API_KEY=your_sendgrid_secret_api_key
```

<h4>Heroku App</h4>

To set an environment variabile in an Heroku app, simply follow <a href="https://devcenter.heroku.com/articles/config-vars">this guide</a>. In Heroku terminology environment variables are called ```config vars```.

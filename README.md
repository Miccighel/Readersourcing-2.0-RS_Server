<h1>Read this!</h1>

Please, note that this is an early alpha release and it is not ready for the use in a production environment.

<h1>Useful Links</h1>

- Original article: https://zenodo.org/record/1446468
- Technical documentation: https://zenodo.org/record/1452397

<h1>Description</h1>

RS_Server is the server-side component of Readersourcing 2.0 which has the task to aggregate the ratings given by readers and to use the RSM and TRM models to compute quality scores for readers and publications. An instance of RS_PDF is deployed along one of RS_PDF. Then, there are up to n different browsers of as many users which communicate with the server and every one of them has an instance of RS_Rate, which is the true client. Both RS_PDF and RS_Rate will be described in the following. This setup means that every interaction between readers and server is carried out through clients installed on readers' browsers and these clients have to handle the registration and authentication of readers, the rating action and the download action of edited publications.

<h1>Deploy</h1>

There are three main modalities that can be exploited to deploy a working instance of RS_Server in **development** or **production** environment. The former must be used if there is the need to add custom Readersourcing model, to extend/modify the current implementation of RS_Server or simply to test it in a safe way. The latter must be used if RS_Server is about to be used in production as it is. In the following these three modalities are described, along with their requirements. 

<h2>1: Manual Way</h2>

This deploy modality allows to manually downwload and start RS_Server locally to a machine chosen as a server. This is the most demading modality regarding is requirements since it assumes that you have a full and working installation of **Ruby**, **JRE** (Java Runtime Environment) and **PostgreSQL** and everything has to be set-up manually, but it allows more flexibility if a particular setup is required for any reason. 

<h3>Requirements</h3>

 - Ruby >= 2.4.4
 - JRE (Java Runtime Environment) >= 1.8.0
 - PostgreSQL >= 10.5
 
 <h3>How To</h3>

Clone this repository and move inside the main directory using a command line prompt (with an ```ls``` or ```dir``` command you should see ```app```, ```bin```, ```config```, etc. folders) and type ```gem install bundler```. This gem (a.k.a., dependency) will provides a consistent environment for Ruby projects by tracking and installing the exact gems (a.k.a., dependencies) and versions that are needed. Then, to fetch all those required by RS_Server type ```bundle install``` and wait for the process to complete. The next two commands _are required only before the first startup of RS_Server_  because they will create and set up the database, so please be sure that the  PostgreSQL service is started up and ready to accept connections on port 5432. To proceed, type ```rake db:create``` to create the database and ```rake db:migrate``` to create the required tables in its inside. Once done that, everything is ready to launch RS_Server in development or production mode. To do that, just type ```cd bin``` to move inside ```bin``` directory and then ```rails server -b 127.0.0.1 -p 3000 -e development``` with the proper values for ```-b```, ```-p``` and ```-e``` options. If the previous values are used, RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```development``` environment. Therefore, every request must be sent to ```https://127.0.0.1:3000``` address.  

<h3>Quick Cheatsheet</h3>

- ```cd``` to main directory
- ```gem install bundler```
- ```bundle install```
- ```rake db:create``` (only before first startup)
- ```rake db:migrate``` (only before first startup)
- ```cd bin```
- ```rails server -b x.x.x.x -p x -e development``` or ```rails server -b x.x.x.x -p x -e production```

<h2>2: Manual Way (But Faster)</h2>

This deploy modality allows to downwload and start RS_Server locally to a machine chosen as a server like the first one, but in a way which is faster and less frustrating, despite being less flexible. Also, it have less demanding requirements, since only a working installation of Docker Desktop CE (Community Edition) is required. Docker is a Platform-as-a-Service project which allows to automate the deployment phase by distributing an _image_ of an application inside a _container_. A container is a standard unit of software that packages up code and all its dependencies so the application runs quickly and reliably from one computing environment to another. A Docker container image is a lightweight, standalone, executable package of software that includes everything needed to run an application: code, runtime, system tools, system libraries and settings. This means that there is not the need to manually install the runtimes/libraries/dependencies needed to run an application since the Docker Engine will automatically fetch, install and setup them.

<h3>Requirements</h3>

- Docker Desktop CE (Community Edition) 

<h3>How To</h3>

Clone this repository and move inside the main directory using a command line prompt. Now, type ```ls``` or ```dir```; you should see a ```docker-compose.yml``` file and a ```Dockerfile```. If you do not see them, please be sure to be in the main directory of the cloned repository. Before proceeding, _be sure that your Docker Engine has been started up, otherwise the following commands will not work_. At this point two different scenarions could happen, which are outlined in the following. 

<h4>Scenario 1: RS_Server is about to be used as it is (deploy with remote images)</h4>

If there is not the need to edit the source code of RS_Server the Docker Engine can simply fetch the required dependencies outlined in the ```docker-compose.yml``` file and set-up the application. To do this, open the ```docker-compose.yml``` file and uncomment the section between the ```----------- SCENARIO 1: DEPLOY WITH REMOTE IMAGES ----------``` and ```----------- END OF SCENARIO 1: DEPLOY WITH REMOTE IMAGES ----------``` comments and comment back the remaining lines of code. Now, from the command line prompt type ```docker-compose up``` and wait for the processing to finish. Note that it may take different minutes. Once the Docker Engine completes the process, the container with a working instance of RS_Server will be ready. _If the first startup of the application is being done_ type also ```docker-compose run rake db:create``` and ```docker-compose run rake db:migrate``` to set-up the required database. RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```production``` environment. Therefore, every request must be sent to ```https://127.0.0.1:3000``` address. If you want to set a custom ip address, port or the ```development``` environent, edit the ```command``` key inside ```docker-compose.yml``` file. To shutdown and undeploy the container, simply type ```docker-compose down```.

<h4>Quick Cheatsheet</h3>

- ```cd``` to main directory
- ```docker-compose up```
- ```docker-compose run rake db:create``` (only at first startup)
- ```docker-compose run rake db:migrate``` (only at first startup)
- ```docker-compose down``` (to shutdown and undeploy)

<h4>Scenario 2: The source code of RS_Server has been edited (deploy with local build)</h4>

If the source code of RS_Server has been edited the application must be built locally by the Docker Engine according to the structure specified in the ```Dockerfile```. After this build phase the Docker Engine itself can simply fetch the required dependencies outlined in the ```docker-compose.yml``` file and set RS_Server up. To do this, open the ```docker-compose.yml``` file and uncomment the section between the ```-----------  SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------``` and ```----------- END OF SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------- ``` comments and comment back the remaining lines of code. Now, from the command line prompt type ```docker-compose up``` and wait for the processing to finish. Note that it may take different minutes. Once the Docker Engine completes the process, the container with a working instance of RS_Server will be ready. _If the first startup of the application is being done_ type also ```docker-compose run rake db:create``` and ```docker-compose run rake db:migrate``` to set-up the required database. RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```production``` environment. Therefore, every request must be sent to ```https://127.0.0.1:3000``` address. If you want to set a custom ip address, port or the ```development``` environment, edit the ```command``` key inside ```docker-compose.yml``` file and mirror the changes to the ```CMD``` key inside the ```Dockerfile```. To shutdown and undeploy the container, simply type ```docker-compose down```.

<h4>Quick Cheatsheet</h3>

- ```cd``` to main directory
- ```docker-compose up```
- ```docker-compose run rake db:create``` (only at first startup)
- ```docker-compose run rake db:migrate``` (only at first startup)
- ```docker-compose down``` (to shutdown and undeploy)

<h2>3: Heroku Deploy</h2>

<h2>Environment Variables</h2>

TO DO 
 
 

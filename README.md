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

This deploy modality allows to manually downwload and start RS_Server locally to a machine chosen as a server. This is the most demading modality regarding is requirements since it assumes that you have a full and working installation of **Ruby**, **JRE** (Java Runtime Environment) and **PostgreSQL** but it allows more flexibility, if a particular setup is required for any reason.

<h3>Requirements</h3>

 - Ruby >= 2.4.4
 - JRE (Java Runtime Environment) >= 1.8.0
 - PostgreSQL >= 10.5
 
 <h3>How To</h3>

Clone this repository and move inside the main directory using a command line prompt (with an ```ls``` or ```dir``` command you should see ```app```, ```bin```, ```config```, etc. folders) and type ```gem install bundler```. This gem (a.k.a., dependency) will provides a consistent environment for Ruby projects by tracking and installing the exact gems (a.k.a., dependencies) and versions that are needed. Then, to fetch all those required by RS_Server type ```bundle install``` and wait for the process to complete. The next two commands _are required only before the first startup of RS_Server_  because they will create and set up the database, so please be sure that the  PostgreSQL service is started up and ready to accept connections. To proceed, type ```rake db:create``` to create the database and ```rake db:migrate``` to create the required tables in its inside. Once done that, everything is ready to launch RS_Server in development or production mode. To do that, just type ```cd bin``` or ```dir bin``` to move inside ```bin``` directory and then ```rails server -b 127.0.0.1 -p 3000 -e development``` with the proper values for ```-b```, ```-p``` and ```-e``` options. If the previous values are used, RS_Server will be started and bound on ```127.0.0.1``` ip address with port ```3000``` and ```development``` environment. Therefore, every request to RS_Sever must be sent to ```https://127.0.0.1:3000``` address.  

<h3>Quick Cheatsheet</h3>

- ```ls``` or ```dir``` (to main directory)
- ```gem install bundler```
- ```bundle install```
- ```rake db:create``` (only before first startup)
- ```rake db:migrate``` (only before first startup)
- ```cd bin``` or ```dir bin```
- ```rails server -b x.x.x.x -p x -e development``` or ```rails server -b x.x.x.x -p x -e production```

<h2>2: Manual Way (But Faster)</h2>

TO DO

<h2>3: Docker Deploy</h2>

<h2>Environment Variables</h2>

TO DO 
 
 

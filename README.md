<h1>Read this!</h1>

Please, note that this is an early alpha release and it is not ready for the use in a production environment.

<h1>Useful Links</h1>

- Original article: https://zenodo.org/record/1446468
- Technical documentation: https://zenodo.org/record/1452397

<h1>Description</h1>

RS_Server is the server-side component of Readersourcing 2.0 which has the task to aggregate the ratings given by readers and to use the RSM and TRM models to compute quality scores for readers and publications. An instance of RS_PDF is deployed along one of RS_PDF. Then, there are up to n different browsers of as many users which communicate with the server and every one of them has an instance of RS_Rate, which is the true client. Both RS_PDF and RS_Rate will be described in the following. This setup means that every interaction between readers and server is carried out through clients installed on readers' browsers and these clients have to handle the registration and authentication of readers, the rating action and the download action of edited publications.

<h1>Deploy</h1>

There are three main modalities that can be exploited to deploy a working instance of RS_Server in **development** or **production** mode. The former must be used if there is the need to add custom Readersourcing model or to extend/modify the current implementation of RS_Server. The latter must be used if RS_Server is about to be used as it is. In the following these three modalities are described, along with their requirements. 

<h2>Manual Way</h2>

<h3>Requirements</h3>
....

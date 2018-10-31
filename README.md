<h1>Read this!</h1>

Please, note that this is an early alpha release and it is not ready for the use in a production environment.

<h1>Useful Links</h1>

- Original article: https://zenodo.org/record/1446468
- Technical documentation: https://zenodo.org/record/1452397

<h1>Description</h1>

RS_Server is the server-side component of Readersourcing 2.0 which has the task to aggregate the ratings given by readers and to use the RSM and TRM models to compute quality scores for readers and publications. An instance of RS_PDF is deployed along one of RS_PDF. Then, there are up to n different browsers of as many users which communicate with the server and every one of them has an instance of RS_Rate, which is the true client. Both RS_PDF and RS_Rate will be described in the following. This setup means that every interaction between readers and server is carried out through clients installed on readers' browsers and these clients have to handle the registration and authentication of readers, the rating action and the download action of edited publications.

<h1>Deploy/Usage</h1>

To be done.

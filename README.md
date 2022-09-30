In a nutshell this is what we have setup:

- We setup an AWS linux machine. Here we use the Overpass API docker image by [wiktron](https://github.com/wiktorn/Overpass-API) in two ways:

1. We create a container to keep an up to date version of the Germany OSM. We let the container update itself daily.
2. On a daily basis, after updating the Germany container we do the following:
2.1. Make a query to the Germany container with only the features we need. (i.e. Ways related to roads, relevant nodes and relevant metadata) .
2.2. We start a fresh new Overpass API docker container, using the result on 2.1(reduced set of data) to initialize the dB. We end up with an overpass API server that only contains the data we are interested on.
2.3. We compress the whole dB folder of the new container. And that is the file we publish on S3 for our OpenPilot clients to fetch. (Our filtered German dB is ~800MB compressed)

3. this way when OP starts on our C3s, it checks if there is a new file in S3, if it is , it replaces its whole dB folder with the new one (i.e. clone) and you are ready to make queries to it using the local  osm3s_query script already installed.

In this repo you can find the scripts we are using on our AWS instance:

In addition we automated the instance to start up every day early in the morning and run the update script. Once done, last line in script will shut down the machine so we save costs.

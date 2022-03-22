#!/bin/bash

# This script will take care of fetching and storing an up to date
# copy of a osm db that includes only the minimum set of features 
# used by AS OpenPilot maps implementation.
# With this db, OpenPilot can use a local version of OverpassAPI
# allowing the use of map data in offline mode.

# For this purpose we run two overpass servers as docker containers:
# - The first one (refered as main) is used to keep an up to date 
# version of german maps with all its features.
# - The second one is used to generate an initialized osm db that only
# includes the relevant highway types that openPilot uses. (refered as
# mini db)

# We achieve this by:
# - Starting the main container and giving it time to update its maps.
# - Making a query to the main db container to fetch only the relevant
# features we want in our mini db.
# - Creating a bzip file from the query result and using this file
# to initialize the mini db server.
# - Once initialized we compress the resulting db folder in a .tar.gz
# - Finaly we upload the file to S3 so that comma devices can fetch it.

# --------------------------------------------------------------------

# - Start the full germany overpass container
# It is a pre-requisite that the docker container for the full German
# osm map data has previously be setup and named `overpass_germany`
docker start overpass_germany

# - Give the full germany container time to update
# If run daily, the main container should be able to update the maps 
# changes in a fraction of an hour. We give 1 hour here to have a cushion.
echo "Waiting for overpass germany full container to update"
sleep 1h

# - Define variables.
export USER_DIR=/home/ubuntu
export MAPS_DIR=${USER_DIR}/maps
export DB_TAR_FILE=${MAPS_DIR}/db.tar.gz
export MINI_DB_DIR=/big/docker/overpass_mini_db
export CONTAINER_NAME=overpass_mini_germany
export MINI_DB_OSM_FILE=germany-ways-latest.osm

# - Remove old tar.gz db file if existent
rm $DB_TAR_FILE

# - Remove old mini db osm files if existent
rm ${MAPS_DIR}/${MINI_DB_OSM_FILE}
rm ${MAPS_DIR}/${MINI_DB_OSM_FILE}.bz2

# - Remove old mini db folder if existing
sudo rm -rf $MINI_DB_DIR

# - Remove existing docker container if existing
docker stop ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}

# - Query full german interpreter to get mini germany osm file
wget -O ${MAPS_DIR}/${MINI_DB_OSM_FILE} 'http://localhost:80/api/interpreter?data=[maxsize:2000000000][timeout:3600];way[highway][highway!~"^(footway|path|corridor|bridleway|steps|cycleway|construction|bus_guideway|escape|service|track)$"];(._;>;);out;'

# - Stop the full germany overpass container
docker stop overpass_germany

# - Bzip the osm file
cd $MAPS_DIR
bzip2 $MINI_DB_OSM_FILE

# - Run docker mini container to initialize the mini db
docker run \
  -e OVERPASS_META=yes \
  -e OVERPASS_MODE=init \
  -e OVERPASS_PLANET_URL=file:///maps/${MINI_DB_OSM_FILE}.bz2 \
  -e OVERPASS_RULES_LOAD=10 \
  -e OVERPASS_FLUSH_SIZE=1 \
  -v ~/maps/:/maps \
  -v ${MINI_DB_DIR}/:/db \
  -i \
  --name ${CONTAINER_NAME} wiktorn/overpass-api

# - Compress mini db folder into new tar.gz file
cd $MINI_DB_DIR
tar -czvf $DB_TAR_FILE db

# - Transfer new db Tar file to s3
aws s3 cp ${DB_TAR_FILE} s3://files.as.osm
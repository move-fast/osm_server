#!/bin/bash

# This is script is meant to be run one time only when initializing
# the main container which holds an up to date osm db for the whole 
# of Germany.

# If what you need to do is to start the container once it has been 
# already initialized, run `docker start -ai overpass_germany` instead.

docker run \
  -e OVERPASS_META=yes \
  -e OVERPASS_MODE=init \
  -e OVERPASS_PLANET_URL=file:///maps/germany-latest.osm.bz2 \
  -e OVERPASS_DIFF_URL=http://download.openstreetmap.fr/replication/europe/germany/minute/ \
  -e OVERPASS_RULES_LOAD=10 \
  -v ~/maps/:/maps \
  -v /big/docker/overpass_db/:/db \
  -p 80:80 \
  -i -t \
  --name overpass_germany wiktorn/overpass-api
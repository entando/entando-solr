#!/usr/bin/env bash

ENTANDO_DATA="/var/solr/data/entando"

if [ -d "$ENTANDO_DATA" ]; then
  echo "Entando data already present. Skip"
else
  echo "Need to create entando core"
  sleep 15
  solr create_core -c entando
fi
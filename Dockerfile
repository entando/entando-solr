FROM solr:8.11.4

COPY --chown=solr:0 entando-init.sh /opt/docker-solr/entando-init.sh
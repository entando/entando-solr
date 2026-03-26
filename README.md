# entando-solr

Docker image for Apache Solr used by Entando, based on the official [solr](https://hub.docker.com/_/solr) image.

## What this image adds

An init script (`entando-init.sh`) that creates an `entando` Solr core on first startup (standalone mode).

## Base image

| Component | Version |
|-----------|---------|
| Solr | 8.11.4 |
| JDK | Eclipse Temurin 11.0.27 |
| OS | Ubuntu 20.04 |

## Build

```bash
docker build -t entando/entando-solr:8 .
```

## Run (standalone)

```bash
docker run -d --name solr -p 8983:8983 entando/entando-solr:8
```

The `entando` core can be created via the init script:

```bash
docker exec solr /opt/docker-solr/entando-init.sh
```

## Standalone deployment (Kubernetes / OpenShift)

A single-node Solr deployment with persistent storage. Suitable for development, testing, or small production environments.

A sample manifest is provided in [`samples/entando-solr-standalone.yaml`](samples/entando-solr-standalone.yaml).

### Deploy

```bash
kubectl apply -f samples/entando-solr-standalone.yaml -n YOUR-NAMESPACE
kubectl get pods -l app=solr -w
```

### Create the Entando core

```bash
kubectl port-forward service/solr 8983:8983
```

In another terminal:

```bash
curl "http://localhost:8983/solr/admin/cores?action=CREATE&name=entando&instanceDir=entando&dataDir=data"
```

### Configure the EntandoApp

```bash
kubectl scale deploy/YOUR-APP-NAME-deployment --replicas=0 -n YOUR-NAMESPACE
```

Add the following environment variables to the deployment:

```yaml
spec:
  containers:
    - env:
      - name: SOLR_ACTIVE
        value: "true"
      - name: SOLR_ADDRESS
        value: http://solr:8983/solr
```

Scale back up:

```bash
kubectl scale deploy/YOUR-APP-NAME-deployment --replicas=1 -n YOUR-NAMESPACE
```

## SolrCloud deployment (Kubernetes / OpenShift)

A clustered Solr deployment with Zookeeper, suitable for production environments requiring high availability and replication.

A sample manifest is provided in [`samples/entando-solrCloud.yaml`](samples/entando-solrCloud.yaml).

### Prerequisites

- A working Entando instance
- Helm
- Cluster-level permissions for CRDs

### Install Solr Operator

```bash
helm repo add apache-solr https://solr.apache.org/charts
helm repo update

kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.5.0/all-with-dependencies.yaml
helm install solr-operator apache-solr/solr-operator --version 0.5.0
```

### Deploy SolrCloud

Adjust resource settings (memory, CPU, storage, replicas) in the manifest as needed, then:

```bash
kubectl apply -f samples/entando-solrCloud.yaml -n YOUR-NAMESPACE
kubectl get solrclouds -w
```

### Create collections

Set up port forwarding (leave it running):

```bash
kubectl port-forward service/solr-solrcloud-common 8983:80
```

In another terminal, create the Solr collection. The first collection (primary tenant, or the only one in single-tenant setups) **must** use `entando` as the collection name:

```bash
curl "http://localhost:8983/solr/admin/collections?action=CREATE&name=entando&numShards=1&replicationFactor=3&maxShardsPerNode=2"
```

#### Multitenancy

For multitenant environments, create an additional collection for each secondary tenant using the tenant name as the collection name:

```bash
curl "http://localhost:8983/solr/admin/collections?action=CREATE&name=YOUR-TENANT-NAME&numShards=1&replicationFactor=3&maxShardsPerNode=2"
```

| Placeholder | Description |
|-------------|-------------|
| `YOUR-TENANT-NAME` | The identifying name of the tenant. In most cases, it will also be used to determine the base URL of the tenant (e.g., `yoursite` results in `yoursite.your-domain.com`). |

The number of shards and shards per node should be adjusted for very large quantities of content (50k+). In such cases, adjustments to replicas and other resources may also be needed.

### Configure the EntandoApp

```bash
kubectl scale deploy/YOUR-APP-NAME-deployment --replicas=0 -n YOUR-NAMESPACE
```

Add the following environment variables to the deployment:

```yaml
spec:
  containers:
    - env:
      - name: SOLR_ACTIVE
        value: "true"
      - name: SOLR_ADDRESS
        value: http://solr-solrcloud-common/solr
```

Scale back up:

```bash
kubectl scale deploy/YOUR-APP-NAME-deployment --replicas=1 -n YOUR-NAMESPACE
```

### Generate the Solr schema

The schema is generated automatically for the primary (`entando`) collection. For secondary tenant collections, trigger it manually: go to **App Builder > Content > Solr Configuration** and click **Refresh** next to each content type.

Then reindex: **App Builder > Content > Settings > Reload the indexes**.

## Why not the previous image?

The previous `entando/entando-solr:8` was based on `solr:8.10.1` with OpenJDK 11.0.13, which lacks
**cgroup v2** support (added in JDK 11.0.16). On modern Linux kernels and OpenShift clusters using
cgroup v2, the JVM fails to detect container CPU and memory limits, leading to resource over-allocation.

Rebasing on `solr:8.11.4` (JDK 11.0.27) fixes this and also includes security patches
(including the Log4Shell fix shipped in Solr 8.11.1).

## License

This project is licensed under the Apache License 2.0 — see the [LICENSE](LICENSE) file for details.

Apache Solr is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
Eclipse Temurin is licensed under the [GPL v2 with Classpath Exception](https://openjdk.org/legal/gplv2+ce.html).
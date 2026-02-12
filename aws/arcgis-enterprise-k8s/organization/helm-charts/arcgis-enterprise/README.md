To use ArcGIS Enterprise on Kubernetes Helm charts not available on My Esri:

1. Copy the Helm charts to `<Helm charts version>` subdirectory of this directory.
2. Update `arcgis.repository.metadata.helm_charts_version` property in `manifests/arcgis-enterprise-k8s-files-<ArcGIS version>.json` file to the `Helm charts version`.
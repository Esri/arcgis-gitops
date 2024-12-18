FROM ghcr.io/esri/arcgis-python-api-notebook:2.4.0

ADD ./ /usr/local/enterprise-admin-cli/
ADD --chmod=755 bin/ /usr/local/enterprise-admin-cli/bin/

ENV PATH="${PATH}:/usr/local/enterprise-admin-cli/bin"

FROM ghcr.io/esri/arcgis-python-api-notebook:2.4.0

ARG cli_home="/usr/local/enterprise-admin-cli"

ADD ./ ${cli_home}/
ADD --chmod=755 bin/ ${cli_home}/

RUN conda install conda-build
RUN conda develop -n arcgis ${cli_home}

ENV PATH="${PATH}:${cli_home}/bin"

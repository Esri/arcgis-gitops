FROM ghcr.io/esri/arcgis-python-api-notebook:2.4.0

ARG cli_home="/usr/local/enterprise-admin-cli"

ENV PATH="${PATH}:${cli_home}/bin"

ADD --chown=${NB_USER}:root ./ ${cli_home}/
RUN chmod -R 755 ${cli_home}/bin/

# Add CLI home to "arcgis" conda environment.
RUN conda install conda-build
RUN conda develop -n arcgis ${cli_home}

FROM ghcr.io/esri/arcgis-python-api-notebook:latest

ADD tools/ /cli/tools/
ADD samples/ /cli/samples/

WORKDIR /cli/tools

CMD ["python", "publish_csv.py"]

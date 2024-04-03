# Enterprise Admin CLI

Enterprise Admin CLI is a command line interface for ArcGIS Enterprise configuration management.

The CLI uses [ArcGIS API for Python](https://developers.arcgis.com/python/) as well as standalone Python modules to call ArcGIS Enterprise web services.

## publish_csv

Tests ArcGIS Enterprise portal by publishing a feature service from CSV file.

Usage:

```shell
python -m publish_csv -a <value> -u <value> -p <value>
```

Options:

```text
-a (string) Portal for ArcGIS URL
-u (string) Portal for ArcGIS user name
-p (string) Portal for ArcGIS user password
```

# Repository Index JSON File Format

The index JSON files used by s3_copy_files python script define source and destination locations of files copied to the private repository S3 bucket.

Example:

```json
{
  "arcgis": {
    "repository": {
      "local_archives": "/opt/software/archives",
      "server": {
        "url": "https://downloads.arcgis.com",
        "token_service_url": "https://www.arcgis.com/sharing/rest/generateToken",
        "s3bucket": "mybucket",
        "region": "us-east-1"
      },
      "files": {
        "ArcGIS_Server_Linux_111_185292.tar.gz": {
          "subfolder": "software/arcgis/11.1",
          "sha256": "B76093569A5DE14D7AB4C86459CEF4D84083335B247EE4B0FB0C4E22FE429B37"
        },
        "ArcGIS-111-S-MSCDF-Patch-linux.tar": {
          "url": "https://gisupdates.esri.com/QFE/S-111-P-940/ArcGIS-111-S-MSCDF-Patch-linux.tar",
          "subfolder": "QFE/S-111-P-940",
          "sha256": "AAA395BCCF6E0700FD78C05CABD2E3C8D9BB7040A200DC97DC47C25A48626985"
        }
      }
    }
  },
  "run_list": [
    "recipe[arcgis-repository::s3files2]"
  ]
}
```

The source files location can be:

* My Esri repository
* Local file system
* Public URLs

The destination for s3_copy_files is an S3 bucket specified by `arcgis.repository.server.s3bucket` and `arcgis.repository.server.region` attributes:

* `arcgis.repository.server.bucket` - S3 bucket name
* `arcgis.repository.server.region` - S3 bucket region

My Esri repository and ArcGIS Online token service URLs are specified by `arcgis.repository.server.url` and `arcgis.repository.server.token_service_url` attributes:

* `arcgis.repository.server.url` - My Esri repository URL (default value is `https://downloads.arcgis.com`)
* `arcgis.repository.server.token_service_url` - ArcGIS Online token service URL (default value is `https://www.arcgis.com/sharing/rest/generateToken`)

`arcgis.repository.files.<filename>` attribute specifies the file name.

If `arcgis.repository.files.<filename>.url` attribute is specified, the file source is a public URL. The file is copied form that URL to the destination S3 bucket in the subfolder (S3 key prefix) specified by `arcgis.repository.files.<filename>.subfolder` attribute.

If `arcgis.repository.files.<filename>.path` attribute is specified, the file source is local file system. The file is copied form that path to the destination S3 bucket in the subfolder (S3 key prefix) specified by `arcgis.repository.files.<filename>.subfolder` attribute.

If neither `arcgis.repository.files.<filename>.url` nor `arcgis.repository.files.<filename>.path` attribute is specified, the file source is My Esri repository. The file is copied form the repository folder specified by by `arcgis.repository.files.<filename>.subfolder` attribute to the destination S3 bucket in the subfolder (S3 key prefix) also specified by `arcgis.repository.files.<filename>.subfolder` attribute.

`arcgis.repository.files.<filename>.sha256` attribute specifies SHA-256 hash of the file content used for checking integrity of the copied files and to prevent unnecessary overwrites of files already present in the destination S3 bucket.  

> Note that the index JSON files are also used by arcgis-repository::s3files2 recipe of Chef Cookbooks for ArcGIS to download files from the private S3 repository to local folder specified by `arcgis.repository.local_archives` attribute.

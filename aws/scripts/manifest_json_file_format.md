# Manifest JSON File Format

The manifest JSON files used by s3_copy_files python script define source and destination locations of files copied to the private repository S3 bucket.

Example:

```json
{
  "arcgis": {
    "repository": {
      "local_archives": "/opt/software/archives",
      "local_patches": "/opt/software/archives/patches",
      "server": {
        "url": "https://downloads.arcgis.com",
        "token_service_url": "https://www.arcgis.com/sharing/rest/generateToken",
        "s3bucket": "${s3bucket}",
        "region": "${region}"
      },
      "patch_notification": {
        "products": [
          "Portal for ArcGIS",
          "ArcGIS Server",
          "ArcGIS Data Store",
          "ArcGIS Web Adaptor (Java)"
        ],
        "versions": [
          "11.4"
        ],
        "patches": [
          "ArcGIS-114-*-linux.tar"
        ],
        "subfolder": "software/arcgis/11.4/patches"        
      },
      "metadata": {
        "java_tarball": "jdk-11.0.21.tar.gz",
        "java_version": "11.0.21+9",
        "tomcat_tarball": "apache-tomcat-9.0.83.tar.gz",
        "tomcat_version": "9.0.83"
      },
      "files": {
        "ArcGIS_Server_Linux_114_192977.tar.gz": {
          "subfolder": "software/arcgis/11.4",
          "sha256": "1B766ECDF0B16635F195EBD25151C4E2E7755197C743AE8D25790A07CB4E9B61"
        },
        "Portal_for_ArcGIS_Linux_114_192978.tar.gz": {
          "subfolder": "software/arcgis/11.4",
          "sha256": "57B06474E1EE66047468307EF08E5C4F9FB2C5560282515DC4633D9B388EC0B5"
        },
        "Portal_for_ArcGIS_Web_Styles_Linux_114_192979.tar.gz": {
          "subfolder": "software/arcgis/11.4",
          "sha256": "06902133A7036D816350ABFD4B18A0E20D6D71B90F700CDE8D8DE81A628CAE2D" 
        },
        "ArcGIS_DataStore_Linux_114_192981.tar.gz": {
          "subfolder": "software/arcgis/11.4",
          "sha256": "8207EA907EFD2E2ADDDBF95AB05A1740A7FC5EE2E521C9E3DB473A4286426C16"
        },
        "ArcGIS_Web_Adaptor_Java_Linux_114_192983.tar.gz": {
          "subfolder": "software/arcgis/11.4",
          "sha256": "D01B9EBFF0FEA724266128F57369D0CAF9F4EC99C21DFA386634BAACAFBCBE55"
        },
        "apache-tomcat-9.0.83.tar.gz": {
          "url": "https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.83/bin/apache-tomcat-9.0.83.tar.gz",
          "subfolder": "thirdparty",
          "sha256": "76092DAE89DC1F3AE6DD11404D64852761A401F18CD373C93B5FF7EF2CE4F90A"
        },
        "jdk-11.0.21.tar.gz": {
          "url": "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.21%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.21_9.tar.gz",
          "subfolder": "thirdparty",
          "sha256": "60EA98DAA09834FDD3162CA91DDC8D92A155AB3121204F6F643176EE0C2D0D5E"
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
* ArcGIS patch repository
* Local file system
* Public URLs

The destination for s3_copy_files is an S3 bucket specified by `arcgis.repository.server.s3bucket` and `arcgis.repository.server.region` attributes:

* `arcgis.repository.server.bucket` - S3 bucket name
* `arcgis.repository.server.region` - S3 bucket region

My Esri repository and ArcGIS Online token service URLs are specified by `arcgis.repository.server.url` and `arcgis.repository.server.token_service_url` attributes:

* `arcgis.repository.server.url` - My Esri repository URL (default value is `https://downloads.arcgis.com`)
* `arcgis.repository.server.token_service_url` - ArcGIS Online token service URL (default value is `https://www.arcgis.com/sharing/rest/generateToken`)

## Metadata

`arcgis.repository.metadata` attribute specifies the metadata of the repository files such as versions and version-specific properties.

## Individual Files

`arcgis.repository.files.<filename>` attribute specifies the file name.

If `arcgis.repository.files.<filename>.url` attribute is specified, the file source is a public URL. The file is copied form that URL to the destination S3 bucket in the subfolder (S3 key prefix) specified by `arcgis.repository.files.<filename>.subfolder` attribute.

If `arcgis.repository.files.<filename>.path` attribute is specified, the file source is local file system. The file is copied form that path to the destination S3 bucket in the subfolder (S3 key prefix) specified by `arcgis.repository.files.<filename>.subfolder` attribute.

If neither `arcgis.repository.files.<filename>.url` nor `arcgis.repository.files.<filename>.path` attribute is specified, the file source is My Esri repository. The file is copied form the repository folder specified by by `arcgis.repository.files.<filename>.subfolder` attribute to the destination S3 bucket in the subfolder (S3 key prefix) also specified by `arcgis.repository.files.<filename>.subfolder` attribute.

`arcgis.repository.files.<filename>.sha256` attribute specifies SHA-256 hash of the file content used for checking integrity of the copied files and to prevent unnecessary overwrites of files already present in the destination S3 bucket.  

## ArcGIS Patches

`arcgis.repository.patch_notification` attribute specifies the ArcGIS patch notification URL and the list of products, versions, and patches to be copied to the destination S3 bucket.

`arcgis.repository.patch_notification.url` attribute specifies the ArcGIS patch notification metadata URL. By default, the URL is `https://downloads.esri.com/patch_notification/patches.json`.

`arcgis.repository.patch_notification.products` attribute specifies the list of products for which patches are to be copied to the destination S3 bucket.

`arcgis.repository.patch_notification.versions` attribute specifies the list of product versions for which patches are to be copied to the destination S3 bucket.

`arcgis.repository.patch_notification.patches` attribute specifies the list of patch file names/patterns to be copied to the destination S3 bucket. The file patterns may include '*' and '?' wildcards.

`arcgis.repository.patch_notification.subfolder` attribute specifies the subfolder (S3 key prefix) in the destination S3 bucket where the patches are to be copied.

## Chef Run List

> Note that the manifest JSON files are also used by arcgis-repository::s3files2 recipe of Chef Cookbooks for ArcGIS to download files and patches from the private S3 repository to local folder specified by `arcgis.repository.local_archives` and `arcgis.repository.local_patches` attributes respectively.

# Pepper

Preps images for use on the internet by tagging the image, removing exif data and creating thumbnails. Information is then appended to a JSON file.

## Usage

Configured by environment variables:

* ``PEPPER_DIR``: Directory to store output images and state.
* ``PUSH_TO_EXIT``: Ask to exit program.

```bash
  export PEPPER_DIR=/tmp/pepper
  ./pepper img1.jpg img2.jpg
```

## Image Support

* jpeg

## Linux Desktop Support

1. Copy ``pepper-example.desktop`` to a new file.
1. Update the ``Exec`` section:
    * ``PEPPER_DIR`` points to the desired directory
    * ``pepper.sh`` includes the path to the script if not in ``$PATH``
1. Update the ``Icon`` section to the path of the icon file.
1. Register the desktop file.

## Required Packages

* ArchLinux: ``pacman -S exiv2 netpbm libjpeg-turbo jq``
* Debian/Ubuntu: ``apt-get install exiv2 netpbm libjpeg-progs jq``

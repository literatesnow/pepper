#!/bin/bash

# Creates images and thumbnails from input files.
# Appends image information to JSON file.
#
# Configured by environment variables:
#   PEPPER_DIR   - Directory to store output and state
#   THUMB_WIDTH  - Thumbnail width
#   THUMB_HEIGHT - Thumbnail height
#   QUALITY      - JPEG image quality

INDEX_FILE=$PEPPER_DIR/pepper.json
TAGS_FILE=$PEPPER_DIR/tags.txt

IMAGE_DIR=$PEPPER_DIR/images
THUMB_DIR=$PEPPER_DIR/thumbs

TAGS=

init() {
  local ARG_COUNT=$1
  local PROG=

  if [ "$ARG_COUNT" == "0" ]; then
    echo "Nothing to do"
    return 1
  fi

  if [ -z "$PEPPER_DIR" ]; then
    echo "Env PEPPER_DIR not set"
    return 1
  fi

  [ -z "$THUMB_WIDTH"  ] && THUMB_WIDTH=200
  [ -z "$THUMB_HEIGHT" ] && THUMB_HEIGHT=200
  [ -z "$QUALITY"      ] && QUALITY=90
  [ -z "$EDITOR"       ] && EDITOR=vim

  for PROG in djpeg cjpeg pamscale pamcut exiv2 jq; do
    if ! which "$PROG" > /dev/null 2>&1; then
      echo "Program $PROG is required"
      return 1
    fi
  done

  [ ! -d "$IMAGE_DIR" ] && mkdir "$IMAGE_DIR"
  [ ! -d "$THUMB_DIR" ] && mkdir "$THUMB_DIR"

  return 0
}

ask_tags() {
  if [ ! -e "$TAGS_FILE" ]; then
    cat <<< "#
# Enter a list of image tags here.
# They should be separated by a new line.
#" > "$TAGS_FILE"
  fi

  "$EDITOR" "$TAGS_FILE" || return 1

  if egrep '^!' "$TAGS_FILE" > /dev/null; then
    echo "Aborting (found a tag starting with !)"
    return 1
  fi

  if [ -e "$TAGS_FILE" ]; then
    TAGS=$(egrep -v '^#' "$TAGS_FILE")
  fi
}

process_image() {
  local FILE_PATH=$1
  local FILE_NAME=$2
  local IMAGE_PATH=$3
  local THUMB_PATH=$4

  write_thumb "$FILE_PATH" "$THUMB_PATH" || return 1
  write_image "$FILE_PATH" "$IMAGE_PATH" || return 1
  update_index "$FILE_PATH" "$FILE_NAME" || return 1
}

write_thumb() {
  local FILE_PATH=$1
  local THUMB_PATH=$2

  echo "[$FILE_NAME] Thumbnail: $THUMB_PATH (${THUMB_WIDTH}x${THUMB_HEIGHT})"

  djpeg "$FILE_PATH" | \
    pamscale -xyfill "$THUMB_WIDTH" "$THUMB_WIDTH" | \
    pamcut -width "$THUMB_WIDTH" -height "$THUMB_HEIGHT" | \
    cjpeg -optimize -progressive -quality "$QUALITY" > "$THUMB_PATH"
}

write_image() {
  local FILE_PATH=$1
  local IMAGE_PATH=$2

  echo "[$FILE_NAME] Image: $IMAGE_PATH"

  djpeg "$FILE_PATH" | \
    cjpeg -optimize -progressive -quality "$QUALITY" > "$IMAGE_PATH"
}


update_index() {
  local FILE_PATH=$1
  local FILE_NAME=$2

  local IMAGE_DATE=$(exiv2 -K 'Exif.Image.DateTime' -Pv "$FILE_PATH" 2>/dev/null)
  #exiv2 DateTime format is YYYY:mm:dd HH:MM:SS
  IMAGE_DATE=${IMAGE_DATE/:/-}
  IMAGE_DATE=${IMAGE_DATE/:/-}

  if [ "$IMAGE_DATE" == '0000-00-00 00:00:00' ]; then
    echo "Invalid date: $IMAGE_DATE"
    return 1
  fi

  local JSON="{
    \"fileName\":  $(echo "$FILE_NAME"         | jq -R .),
    \"imageDate\": $(echo "$IMAGE_DATE"        | jq -R .),
    \"addedDate\": $(date '+%Y-%m-%d %H:%M:%S' | jq -R .),
    \"tags\":      $(echo "$TAGS" | jq -Rs 'split("\n") | [ .[] | select(length > 0) ]')
  }"

  [ ! -e "$INDEX_FILE" ] && echo '[]' > "$INDEX_FILE"

  cat "$INDEX_FILE" | \
    jq ". += [$JSON]" > "$INDEX_FILE.new" || return 1
  rm "$INDEX_FILE" > /dev/null 2>&1 || return 1
  mv "$INDEX_FILE.new" "$INDEX_FILE"
}

prep_images() {
  while true; do
    [ -z "$1" ] && break
    local FILE_PATH=$1
    local FILE_NAME=$(basename "$FILE_PATH")
    local THUMB_PATH=$THUMB_DIR/$FILE_NAME
    local IMAGE_PATH=$IMAGE_DIR/$FILE_NAME
    shift

    process_image "$FILE_PATH" "$FILE_NAME" "$IMAGE_PATH" "$THUMB_PATH"
  done
}

fail() {
  end_message
  exit 1
}

end_message() {
  local EMPTY=
  [ -z "$PUSH_TO_EXIT" ] && return 0
  read -p 'Push ENTER to continue' EMPTY
}

init "$#" || fail
ask_tags  || fail
prep_images "$@"
end_message

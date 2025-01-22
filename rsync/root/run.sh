#!/usr/bin/env bashio
# shellcheck shell=bash
set -e

PRIVATE_KEY_FILE=$(bashio::config 'private_key_file')
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
  bashio::log.info 'Generate keypair'

  mkdir -p "$(dirname "$PRIVATE_KEY_FILE")"
  ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_FILE" -N ''

  bashio::log.info "Generated key-pair in $PRIVATE_KEY_FILE"
else
  bashio::log.info "Use private key from $PRIVATE_KEY_FILE"
fi

HOST=$(bashio::config 'remote_host')
USERNAME=$(bashio::config 'username')
FOLDERS=$(bashio::addon.config | jq -r ".folders")

# Create local directories if they don't exist
echo "$FOLDERS" | jq -c '.[]' | while read -r folder; do
  LOCAL_DIR=$(echo "$folder" | jq -r '.local')
  bashio::log.info "Checking local directory: $LOCAL_DIR"
  if [ ! -d "$LOCAL_DIR" ]; then
    bashio::log.info "Creating local directory: $LOCAL_DIR"
    mkdir -p "$LOCAL_DIR"
    # chmod 755 "$LOCAL_DIR"
  fi
done

if bashio::config.has_value 'remote_port'; then
  PORT=$(bashio::config 'remote_port')
  bashio::log.info "Use port $PORT"
else
  PORT=22
fi
folder_count=$(echo "$FOLDERS" | jq -r '. | length')
for (( i=0; i<folder_count; i=i+1 )); do

  local=$(echo "$FOLDERS" | jq -r ".[$i].local")
  remote=$(echo "$FOLDERS" | jq -r ".[$i].remote")
  options=$(echo "$FOLDERS" | jq -r ".[$i].options // \"--archive --recursive --compress --delete --prune-empty-dirs\"")
  direction=$(echo "$FOLDERS" | jq -r ".[$i].direction // \"push\"")
  if [ "$direction" = "pull" ]; then
    # Pull from remote to local.
    bashio::log.info "Sync ${USERNAME}@${HOST}:${remote} -> ${local} with options \"${options}\""
    set -x
    # shellcheck disable=SC2086
    rsync ${options} \
    -e "ssh -p ${PORT} -i ${PRIVATE_KEY_FILE} -oStrictHostKeyChecking=no" \
    "${USERNAME}@${HOST}:${remote}" "${local}"
    set +x
  else
    # Default push from local to remote
    bashio::log.info "Sync ${local} -> ${USERNAME}@${HOST}:${remote} with options \"${options}\""
    set -x
    # shellcheck disable=SC2086
    rsync ${options} \
    -e "ssh -p ${PORT} -i ${PRIVATE_KEY_FILE} -oStrictHostKeyChecking=no" \
    "$local" "${USERNAME}@${HOST}:${remote}"
    set +x
  fi
done

bashio::log.info "Synced all folders"

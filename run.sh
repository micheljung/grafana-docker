#!/bin/bash -e

: "${GF_PATHS_DATA:=/var/lib/grafana}"
: "${GF_PATHS_LOGS:=/var/log/grafana}"
: "${GF_PATHS_PLUGINS:=/var/lib/grafana/plugins}"
: "${GRAFANA_USER:=grafana}"
: "${GRAFANA_GROUP:=grafana}"

chown -R ${GRAFANA_USER}:${GRAFANA_GROUP} "$GF_PATHS_DATA" "$GF_PATHS_LOGS"
chown -R ${GRAFANA_USER}:${GRAFANA_GROUP} /etc/grafana

if [ ! -z ${GF_AWS_PROFILES+x} ]; then
    mkdir -p ~${GRAFANA_USER}/.aws/
    touch ~${GRAFANA_USER}/.aws/credentials

    for profile in ${GF_AWS_PROFILES}; do
        access_key_varname="GF_AWS_${profile}_ACCESS_KEY_ID"
        secret_key_varname="GF_AWS_${profile}_SECRET_ACCESS_KEY"
        region_varname="GF_AWS_${profile}_REGION"

        if [ ! -z "${!access_key_varname}" -a ! -z "${!secret_key_varname}" ]; then
            echo "[${profile}]" >> ~${GRAFANA_USER}/.aws/credentials
            echo "aws_access_key_id = ${!access_key_varname}" >> ~${GRAFANA_USER}/.aws/credentials
            echo "aws_secret_access_key = ${!secret_key_varname}" >> ~${GRAFANA_USER}/.aws/credentials
            if [ ! -z "${!region_varname}" ]; then
                echo "region = ${!region_varname}" >> ~${GRAFANA_USER}/.aws/credentials
            fi
        fi
    done

    chown ${GRAFANA_USER}:${GRAFANA_GROUP} -R ~${GRAFANA_USER}/.aws
    chmod 600 ~${GRAFANA_USER}/.aws/credentials
fi

if [ ! -z "${GF_INSTALL_PLUGINS}" ]; then
  OLDIFS=$IFS
  IFS=','
  for plugin in ${GF_INSTALL_PLUGINS}; do
    IFS=$OLDIFS
    grafana-cli  --pluginsDir "${GF_PATHS_PLUGINS}" plugins install ${plugin}
  done
fi

exec gosu ${GRAFANA_USER} /usr/sbin/grafana-server      \
  --homepath=/usr/share/grafana                 \
  --config=/etc/grafana/grafana.ini             \
  cfg:default.log.mode="console"                \
  cfg:default.paths.data="$GF_PATHS_DATA"       \
  cfg:default.paths.logs="$GF_PATHS_LOGS"       \
  cfg:default.paths.plugins="$GF_PATHS_PLUGINS" \
  "$@"

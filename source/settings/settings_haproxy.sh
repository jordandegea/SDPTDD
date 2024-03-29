#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

ZEPPELIN_SERVER_DECLS=""
FLINK_JOBMANAGER_DECLS=""
SERVER_ID=1
while getopts ":vfs:" opt; do
  case "$opt" in
    s)
      ZEPPELIN_SERVER_DECLS=$(printf "%s\n    server zeppelin%d %s:8080 check" "$ZEPPELIN_SERVER_DECLS" "$SERVER_ID" "$OPTARG")
      FLINK_JOBMANAGER_DECLS=$(printf "%s\n    server flink%d %s:8081 check" "$FLINK_JOBMANAGER_DECLS" "$SERVER_ID" "$OPTARG")
      SERVER_ID=$((SERVER_ID+1))
      ;;
  esac
done

# Create the configuration file for HAProxy
echo "global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # Default ciphers to use on SSL-enabled listening sockets.
    # For more information, see ciphers(1SSL). This list is from:
    #  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
    # An alternative list with additional directives can be obtained from
    #  https://mozilla.github.io/server-side-tls/ssl-config-generator/?server=haproxy
    ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
    ssl-default-bind-options no-sslv3

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    timeout tunnel  3600s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

listen zeppelin
    bind *:80
    mode http
    stats enable
    stats uri /haproxy?stats
    balance roundrobin
    option httpclose
    option forwardfor
    option http-server-close
    option forceclose
    stick-table type ip size 1m expire 1h
    stick on src
$ZEPPELIN_SERVER_DECLS

listen flink
    bind *:81
    mode http
    stats enable
    stats uri /haproxy?stats
    balance roundrobin
    option httpclose
    option forwardfor
    option http-server-close
    option forceclose
    stick-table type ip size 1m expire 1h
    stick on src
$FLINK_JOBMANAGER_DECLS
" > /etc/haproxy/haproxy.cfg
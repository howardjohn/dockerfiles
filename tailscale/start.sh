#!/bin/sh

/app/tailscaled --tun=userspace-networking --socks5-server=0.0.0.0:1055 &
until /app/tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=docker-proxy
do
    sleep 0.1
done
echo Tailscale started

trap 'trap - TERM; kill -s TERM -- -$$' TERM

tail -f /dev/null & wait

exit 0

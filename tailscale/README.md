# Setup

```
docker run --rm --name tailscale -e TAILSCALE_AUTHKEY="$(cat ~/.secrets/tailscale)" -p 127.0.0.1:1055:1055 -d howardjohn/tailscale
```

## Usage

To connect over the proxy, set `all_proxy=socks5://127.0.0.1:1055`.

In browser, proxy.pac can be used.

For ssh, add `-o 'ProxyCommand /usr/bin/nc -x 127.0.0.1:1055 %h %p'`
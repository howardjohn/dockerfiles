# Setup

```
docker run --rm --name tailscale -e TAILSCALE_AUTHKEY="$(cat ~/.secrets/tailscale)" -p 127.0.0.1:1055:1055 -d howardjohn/tailscale
```

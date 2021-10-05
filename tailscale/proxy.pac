function FindProxyForURL(url, host) {
    if (shExpMatch(url, "*.howardjohn.info/*")) {
        return "SOCKS5 127.0.0.1:1055";
    } else {
        return "DIRECT";
    }
}
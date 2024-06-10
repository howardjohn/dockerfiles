variable "hubs" {
  default = ["localhost:5000"]
}

variable "platforms" {
  default = ["linux/amd64", "linux/arm64"]
}

images = [
  {
    name         = "benchtool"
    version      = "v0.0.12"
    dependencies = ["wrk2", "nettools"]
  },
  {
    name    = "go-ci"
    version = "v0.0.5"
  },
  {
    name    = "hyper-server"
    version = "v0.0.15"
    dependencies = ["rust-amd64-amd64", "rust-amd64-arm64"]
  },
  {
    name         = "kubectl"
    version      = "v1.28.0"
    dependencies = ["shell"]
  },
  {
    name    = "netperf"
    version = "v0.0.3"
    dependencies = ["shell", "rust-amd64-amd64", "rust-amd64-arm64"]
  },
  {
    name    = "hp-netperf"
    version = "v0.0.1"
    dependencies = ["shell"]
  },
  {
    name         = "nettools"
    version      = "v0.0.7"
    dependencies = ["shell"]
  },
  {
    name         = "scuttle-shell"
    version      = "v0.0.8"
    dependencies = ["shell"]
  },
  {
    name    = "shell"
    version = "v0.0.9"
  },
  {
    name    = "subliminal"
    version = "v0.0.2"
  },
  {
    name    = "tailscale"
    version = "v1.46.1"
  },
  {
    name    = "wrk2"
    version = "v0.0.2"
    platforms = ["linux/amd64"]
  },
  // Rust AMD64 -> AMD64
  {
    name    = "rust-amd64-amd64"
    version = "v1.77.0"
    platforms = ["linux/amd64"]
  },
  // Rust AMD64 -> ARM64
  {
    name    = "rust-amd64-arm64"
    version = "v1.77.0"
    platforms = ["linux/amd64"]
  },
]

target "all" {
  matrix = {
    item = images
  }
  name    = item.name
  context = item.name
  args    = {
    VERSION    = item.version
    VERSIONNUM = trimprefix(item.version, "v")
  }
  tags = [
    for x in setproduct(hubs, ["latest", item.version]) : join("/${item.name}:", x)
  ]
  contexts  = {for x in lookup(item, "dependencies", []) : "howardjohn/${x}" => "target:${x}"}
  platforms = lookup(item, "platforms", platforms)
  output    = ["type=registry"]
}

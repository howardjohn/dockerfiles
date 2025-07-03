variable "hubs" {
  default = ["localhost:5000"]
}

variable "platforms" {
  default = ["linux/amd64", "linux/arm64"]
}

images = [
  {
    name         = "benchtool"
    version      = "v0.0.16"
    dependencies = ["wrk2", "nettools"]
  },
  {
    name    = "go-ci"
    version = "v0.0.5"
  },
  {
    name    = "cmcp"
    version = "v0.0.2"
  },
  {
    name    = "hyper-server"
    version = "v0.0.24"
    dependencies = ["rust-amd64-amd64", "rust-amd64-arm64"]
  },
  {
    name         = "kubectl"
    version      = "v1.32.2"
    dependencies = ["shell"]
  },
  {
    name    = "netperf"
    version = "v0.0.4"
    dependencies = ["shell", "rust-amd64-amd64", "rust-amd64-arm64"]
  },
  {
    name    = "hp-netperf"
    version = "v0.0.1"
    dependencies = ["shell"]
  },
  {
    name         = "nettools"
    version      = "v0.0.10"
    dependencies = ["shell"]
  },
  {
    name         = "scuttle-shell"
    version      = "v0.0.8"
    dependencies = ["shell"]
  },
  {
    name    = "shell"
    version = "v0.0.11"
  },
  {
    name    = "subliminal"
    version = "v0.0.2"
  },
  {
    name    = "tailscale"
    version = "v1.80.3"
  },
  {
    name    = "wrk2"
    version = "v0.0.4"
    platforms = ["linux/amd64"]
  },
  // Rust AMD64 -> AMD64
  {
    name    = "rust-amd64-amd64"
    version = "v1.88.0"
    platforms = ["linux/amd64"]
  },
  // Rust AMD64 -> ARM64
  {
    name    = "rust-amd64-arm64"
    version = "v1.88.0"
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

variable "hubs" {
  default = ["localhost:5000"]
}

variable "platforms" {
  default = ["linux/amd64", "linux/arm64"]
}

images = [
  {
    name    = "benchtool"
    version = "v0.0.6"
    dependencies = ["wrk2", "nettools"]
  },
  {
    name    = "filebot"
    version = "v0.0.2"
  },
  {
    name    = "go-ci"
    version = "v0.0.5"
  },
  {
    name    = "hyper-server"
    version = "v0.0.13"
  },
  {
    name         = "kubectl"
    version      = "v1.27.0"
    dependencies = ["shell"]
  },
  {
    name    = "netperf"
    version = "v0.0.1"
  },
  {
    name         = "nettools"
    version      = "v0.0.6"
    dependencies = ["shell"]
  },
  {
    name    = "protodep"
    version = "v0.1.8"
  },
  {
    name         = "scuttle-shell"
    version      = "v0.0.7"
    dependencies = ["shell"]
  },
  {
    name    = "shell"
    version = "v0.0.7"
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
  platforms = platforms
  output    = ["type=registry"]
}

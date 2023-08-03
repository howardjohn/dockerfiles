target "_defaults" {

}

variable "hubs" {
  default = ["localhost:5000"]
}

variable "platforms" {
  default = ["linux/amd64", "linux/arm64"]
}

function "tags" {
  params = [name, version]
  result = [
    for x in setproduct(["local", "gcr"], ["latest", version]) : join("/${name}:", x)
  ]
}
function "obj" {
  params = [name, version]
  result = {
    tags = [
      for x in setproduct(["local", "gcr"], ["latest", version]) : join("/${name}:", x)
    ]
  }
}

images = [
  {
    name    = "nettools"
    version = "v0.6.0"
    dependencies = ["shell"]
  },
  {
    name    = "shell"
    version = "v0.6.0"
  }
]

target "all" {
  matrix = {
    item = images
  }
  name    = item.name
  context = item.name
  tags    = [
    for x in setproduct(hubs, ["latest", item.version]) : join("/${item.name}:", x)
  ]
  contexts  = {for x in lookup(item, "dependencies", []) : "howardjohnlocal/${x}" => "target:${x}"}
  platforms = platforms
  output    = ["type=registry"]
}

#target "nettools" {
#    tags = tags("nettools","v0.6.0")
#    args = {
#      VERSION = "v"
#    }
#    context = "nettools"
#    platforms = [
#        "linux/amd64",
#        "linux/arm64",
#    ]
#    output = ["type=registry"]
#}
#  group "all" {
#    targets = ["nettools",]
#  }

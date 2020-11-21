target "identity" {
    tags = ["gcr.io/howardjohn-istio/identity:latest",]
    args = {}
    platforms = [
        "linux/amd64",
    ]
    output = ["type=registry"]
}
target "shell" {
    tags = ["gcr.io/howardjohn-istio/shell:latest","gcr.io/howardjohn-istio/shell:v0.0.1",]
    args = {}
    context = "shell"
    platforms = [
        "linux/amd64",
    ]
    output = ["type=registry"]
}
  group "all" {
    targets = ["identity","shell",]
  }

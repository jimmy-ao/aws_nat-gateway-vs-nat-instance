# locals.tf

locals {
  # First letter only: "lab" -> "l". Careful, "prod" and "preprod" would both give "p".
  env = substr(var.environment, 0, 1)
  reg = join("", [element((split("-", var.region)), 0), substr(element((split("-", var.region)), 1), 0, 1), element((split("-", var.region)), 2)])

  az = data.aws_availability_zones.available.names[0]
}
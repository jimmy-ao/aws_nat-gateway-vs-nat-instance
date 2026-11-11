# locals.tf

locals {
  env = substr(var.environment, 0, 1)
  reg = join("", [element((split("-", var.region)), 0), substr(element((split("-", var.region)), 1), 0, 1), element((split("-", var.region)), 2)])

  az        = data.aws_availability_zones.available.names[0]
  az_naming = join("", [element((split("-", local.az)), 0), substr(element((split("-", local.az)), 1), 0, 1), element((split("-", local.az)), 2)])
}
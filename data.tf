# data.tf

data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:The lab uses whichever AZ comes first, on purpose
  state = "available"
}
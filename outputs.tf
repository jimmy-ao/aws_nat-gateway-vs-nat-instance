# outputs.tf

output "nat_gateway_id" {
  description = "ID of the zonal NAT Gateway"
  value       = aws_nat_gateway.zonal.id
}

output "nat_gateway_public_ip" {
  description = "Public IP private subnet A egresses from (zonal NAT Gateway)"
  value       = aws_eip.zonal_nat_gateway.public_ip
}

output "nat_instance_id" {
  description = "Instance ID of the NAT instance"
  value       = aws_instance.nat_instance.id
}

output "nat_instance_public_ip" {
  description = "Public IP private subnet B egresses from (NAT instance)"
  value       = aws_eip.nat_instance.public_ip
}

output "regional_nat_gateway_id" {
  description = "ID of the Regional NAT Gateway"
  value       = aws_nat_gateway.regional.id
}

output "regional_nat_gateway_public_ips" {
  description = "Public IPs private subnet C egresses from: one entry per AZ the Regional NAT Gateway has expanded into"
  value       = { for a in aws_nat_gateway.regional.regional_nat_gateway_address : a.availability_zone => a.public_ip }
}

output "test_instance_ids" {
  description = "Test instance IDs, keyed by the door their subnet uses"
  value       = { for k, i in aws_instance.test : k => i.id }
}

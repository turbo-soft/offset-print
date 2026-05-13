# Replicate the customer's existing zone here BEFORE switching nameservers.
# Run the audit commands in infra/README.md, then fill in MX / SPF / DKIM /
# DMARC and any subdomain records below. Apply, verify, THEN flip NS at the
# registrar.
#
# Example MX block — adjust priorities and hosts to whatever the audit shows.
#
# resource "aws_route53_record" "mx" {
#   zone_id = aws_route53_zone.site.zone_id
#   name    = var.domain
#   type    = "MX"
#   ttl     = 3600
#   records = [
#     "10 mx1.example-mail-host.com",
#     "20 mx2.example-mail-host.com",
#   ]
# }
#
# resource "aws_route53_record" "spf" {
#   zone_id = aws_route53_zone.site.zone_id
#   name    = var.domain
#   type    = "TXT"
#   ttl     = 3600
#   records = ["v=spf1 include:example-mail-host.com -all"]
# }
#
# resource "aws_route53_record" "dmarc" {
#   zone_id = aws_route53_zone.site.zone_id
#   name    = "_dmarc.${var.domain}"
#   type    = "TXT"
#   ttl     = 3600
#   records = ["v=DMARC1; p=quarantine; rua=mailto:office@offsetprint.eu"]
# }

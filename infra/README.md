# Infrastructure

Terraform for the customer's AWS account: S3 + CloudFront + ACM + IAM (OIDC) + Route 53.

## One-time prerequisites

1. AWS CLI configured against the customer's account with admin (just for `terraform apply`).
2. `terraform` ≥ 1.7.
3. The GitHub repository exists at `<owner>/offset-print-site`.
4. A registered domain (`offsetprint.eu`). The migration of nameservers to Route 53 is the **last** step — see DNS Cutover below.

## Files

- `main.tf` — providers, S3, CloudFront, OAC, CF Function, IAM OIDC role, ACM cert, Route 53 zone.
- `variables.tf` — domain, repo, bucket name, etc.
- `outputs.tf` — values to plug into GitHub Actions vars and Sveltia config.

## Apply

```sh
cd infra
terraform init
terraform apply -var="github_repo=<owner>/offset-print-site"
```

After apply:
- Set GitHub repository **variables**:
  - `AWS_DEPLOY_ROLE_ARN` ← `terraform output -raw deploy_role_arn`
  - `CLOUDFRONT_DISTRIBUTION_ID` ← `terraform output -raw cloudfront_distribution_id`
- Set GitHub repository **secret**:
  - `PUBLIC_WEB3FORMS_KEY` ← Web3Forms access key from web3forms.com

## DNS cutover (do this LAST)

Before changing nameservers at the registrar:

1. **Audit the current zone** — get the existing MX, TXT/SPF, DKIM, DMARC, and any subdomain records. They live wherever the customer registered the domain (likely Wix or the registrar's panel).
   ```sh
   dig offsetprint.eu MX  +short
   dig offsetprint.eu TXT +short
   dig _dmarc.offsetprint.eu TXT +short
   dig default._domainkey.offsetprint.eu TXT +short
   ```
2. **Add every existing record to `route53_extra_records.tf`** (or directly via the AWS console). MX records are the most important — getting this wrong kills the customer's email.
3. **Lower TTLs at the current DNS provider** to 300s, at least 24 h before cutover.
4. Validate the ACM certificate (Terraform handles the validation records via Route 53 once the zone is authoritative).
5. **Switch nameservers** at the registrar to the four Route 53 NS records (`terraform output -json route53_name_servers`).
6. Wait for propagation (~30 min). Test:
   - `dig offsetprint.eu @8.8.8.8` shows the CloudFront ALIAS.
   - `dig offsetprint.eu MX @8.8.8.8` still shows the customer's mail provider.
   - Send a test email to `office@offsetprint.eu` from an outside address; confirm delivery.

## Cost

- S3: pennies (a few MB stored).
- CloudFront: free tier covers 1 TB/month and 10M requests for the first 12 months; after that, ~\$0.085/GB egress to Europe. This site will not move 1 TB.
- ACM: free.
- Route 53: \$0.50/month per hosted zone + \$0.40 per million queries.
- Total: well under \$5/month, hence the budget alert in `main.tf`.

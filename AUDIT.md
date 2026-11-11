# AUDIT.md

A Well-Architected and security-by-design review of this lab, conducted with love, static analysis and a healthy amount of sarcasm.

## v2 (2026-11-11): the fixes

Same day, second pass. The author removed the dead `az_map`, and the fix list from v1 was applied. Re-run of the same tools: `terraform validate` passes, `terraform fmt` is clean, checkov reports **59 passed, 0 failed, 7 skipped**, each skip carrying its excuse in a comment next to the resource.

| Pillar | v1 | v2 | What changed |
| --- | --- | --- | --- |
| Operational excellence | D | B+ | It validates. A CI robot now says "no" on your behalf. |
| Security | B- | A- | Disks encrypted, default SG locked, egress narrowed, hop limit set. |
| Reliability | C, on purpose | C, on purpose | Still one AZ and one pet. Still the point. |
| Performance efficiency | B | B | The scanner stopped sulking about `ebs_optimized`. |
| Cost optimization | B- | B | Documented, not automated. A budget alert remains your job. |
| Sustainability | A- | A- | The polar bears have no further comments. |

| ID | Status | What was done |
| --- | --- | --- |
| OPS-1, OPS-2 | Fixed | `az_map` removed from `locals.tf`. The repo validates. |
| OPS-3 | Fixed | `.github/workflows/terraform.yml`: fmt, validate, checkov and shellcheck on every push and pull request. |
| OPS-4 | Fixed | `.terraform.lock.hcl` is in the repo (AWS provider 6.72.0). |
| OPS-5 | Fixed | README file table rewritten for the current file names; `zone-nat-gateway.tf` now knows its own name; every file has its header. |
| OPS-6 | Documented | A comment in `locals.tf` warns that `prod` and `preprod` would both become `p`. |
| OPS-7 | Accepted | GovCloud region names still produce odd short codes. |
| OPS-8 | Fixed | Every output has a description; `.DS_Store` is gitignored. |
| OPS-9 | Accepted | No alarms in a lab. |
| SEC-1 | Fixed | `root_block_device { encrypted = true }` on all four instances. |
| SEC-2 | Fixed | `aws_default_security_group.main` adopts the default SG with no rules. Plan goes from 27 to 28 resources. |
| SEC-3, SEC-7 | Fixed | Test instances: egress tcp/443 only, every rule has a description. |
| SEC-4 | Fixed, the cheap way | Role and profile renamed `...-ssm-lab-instances`, since the NAT instance uses them too. One shared role with one managed policy; split it if the lab grows. |
| SEC-5 | Fixed | The masquerade rule only covers private subnet B. |
| SEC-6 | Fixed | `http_put_response_hop_limit = 1` on all instances. |
| SEC-8 | Accepted | No VPC Flow Logs; skip documented on the VPC. |
| SEC-9 | Accepted | NAT instance egress stays wide open; skip documented on its SG. |
| SEC-10, SEC-11, SEC-12 | Accepted | Unpinned AMI, no egress inspection, local state. See v1. |
| REL-1, REL-2, REL-3, REL-5 | Accepted | By design. See v1. |
| REL-4 | Fixed, with a correction | v1 claimed the check script could wait forever. It could not: the SSM waiter gives up after about 100 seconds. The real problem was an ugly crash when an instance is not registered with SSM; the script now prints `UNREACHABLE` and exits non-zero. |
| PERF-2 | Fixed | `ebs_optimized = true` set explicitly. |
| PERF-1, PERF-3 | Accepted | Burstable is fine; detailed monitoring skip documented. |
| COST-1 | Documented | README now states the $90 a month idle cost and suggests a budget alert. No budget resource was added: it would need an e-mail address or a topic, which is your call. |
| COST-2 | Documented | README explains activating `Purpose` as a cost allocation tag. |
| COST-3, COST-4 | Accepted | See v1. |

**New in v2, not in v1:** `scripts/check-egress.sh` used an associative array, a bash 4 feature. macOS still ships bash 3.2, where the script would have died on its first line of logic. Rewritten with a `case` statement. An audit that misses "does not run on the author's laptop" has no business grading others on operational excellence; noted with humility.

**Still open:** nothing blocking. The lab has not been applied by this audit: `validate` and static analysis are a paper exam, and the first `terraform apply` is the practical.

---

## v1 (2026-11-11)

**Scope:** every `.tf` file in the repo root, plus `scripts/` and the README.
**Method:** `terraform fmt` and `terraform validate` (Terraform 1.17.1, AWS provider 6.x), checkov 3.4.3, then a human-style read through the six pillars. Nothing was deployed: this is a paper audit, the cheapest kind.

**Reminder of the rules of the game:** this is a lab meant to live for a few hours. A finding marked *Accept* is not a compliment, it is a shrug with a justification.

### Scorecard

| Pillar | Grade | One-line verdict |
| --- | --- | --- |
| Operational excellence | D | It does not `validate`. Everything else is a detail. |
| Security | B- | Good instincts (no SSH, IMDSv2, SSM only), four unencrypted disks and an open default SG. |
| Reliability | C, on purpose | One AZ, one pet. The lab exists to demonstrate this, so we will not pretend to be shocked. |
| Performance efficiency | B | A `t4g.nano` routing three `curl` calls. It will cope. |
| Cost optimization | B- | Beautiful tags, zero guardrails. About $90 a month if you forget it exists. |
| Sustainability | A- | Graviton, tiny, short-lived. The polar bears send their regards. |

**Static analysis:** 47 checks passed, 19 failed, across 8 distinct rules. Of those 8: three are real and cheap to fix, three are acceptable for a lab, one is a false positive and one is simply the definition of a NAT.

---

### 1. Operational excellence

| ID | Severity | Finding | Verdict |
| --- | --- | --- | --- |
| OPS-1 | **Blocker** | `locals.tf` line 10 reads `data.aws_availability_zones.current`, but `data.tf` only declares `available`. `terraform validate` fails, so the lab that compares three ways out of a VPC currently has zero ways into one. | **Fix** |
| OPS-2 | Medium | `local.az_map` is computed and used by nobody. Dead code in a repo this small is a bold lifestyle choice. It is also the code that breaks OPS-1, which is poetic. | **Fix** (delete it, OPS-1 disappears with it) |
| OPS-3 | Medium | No CI. OPS-1 would have been caught by a four-line GitHub Actions job running `fmt -check` and `validate`. A robot that says "no" is the cheapest colleague you will ever hire. | **Fix** |
| OPS-4 | Medium | No `.terraform.lock.hcl` committed, and the provider floats on `~> 6.0`. Today's lab and next month's lab are two different labs that happen to share a README. | **Fix** (commit the lock file) |
| OPS-5 | Low | The README file table describes a repo that no longer exists: `nat_gateway.tf` is now `zone-nat-gateway.tf`, the others moved to hyphens, default tags moved from `versions.tf` to `providers.tf`, and `data.tf` and `locals.tf` are not mentioned. `zone-nat-gateway.tf` also introduces itself as `# nat-gateway.tf` in its own header. Identity crisis. | **Fix** |
| OPS-6 | Low | `local.env` keeps only the first letter of the environment. `lab` becomes `l`, fine. But `prod` and `preprod` both become `p`, which is the kind of ambiguity that ends in a post-mortem. | **Fix or document** |
| OPS-7 | Low | `local.reg` assumes three-part region names. `eu-north-1` gives `eun1`, lovely. `us-gov-west-1` gives `usgwest`. GovCloud users are used to suffering, but still. | **Accept** |
| OPS-8 | Low | Six of seven outputs have no `description`. `.DS_Store` is sitting untracked next to the code, one `git add -A` away from immortality. | **Fix** |
| OPS-9 | Info | No alarms, no dashboards. For a lab that lives three hours, your eyes are the monitoring stack. | **Accept** |

### 2. Security (and security by design)

**What the lab gets right, and it deserves saying:**

- No SSH keys, no bastion, no inbound rule anywhere. Access is SSM Session Manager only, so there is nothing to brute-force and nothing to rotate.
- IMDSv2 is required on every instance.
- Private subnets never get public IPs; only the NAT instance and the zonal gateway hold an Elastic IP.
- The NAT instance security group only accepts traffic from the one subnet routed through it.
- The instance role carries a single AWS managed policy, `AmazonSSMManagedInstanceCore`, and nothing else.
- State and `.tfvars` are gitignored.

**What it gets less right:**

| ID | Severity | Finding | Verdict |
| --- | --- | --- | --- |
| SEC-1 | Medium | Four EC2 root volumes with no `encrypted = true` (CKV_AWS_8). Unless the account enforces EBS encryption by default, those disks are in plain text. It costs nothing and takes one block; "it is only a lab" is how every unencrypted disk in production started its career. | **Fix** |
| SEC-2 | Medium | The VPC's default security group is left as AWS ships it: allow everything from itself, allow everything out (CKV2_AWS_12). Nobody uses it, which is exactly why somebody eventually will. | **Fix** (adopt it with `aws_default_security_group` and no rules) |
| SEC-3 | Medium | The test instances' security group allows all protocols to `0.0.0.0/0` (CKV_AWS_382). They need exactly one thing: HTTPS, for SSM, `dnf` and `curl checkip`. Least privilege is not a production-only hobby. | **Fix** (egress tcp/443 only) |
| SEC-4 | Low | The NAT instance shares its IAM role with the test instances, and the role is named `...-ssm-test-instances`. The one box with a public IP is borrowing someone else's badge. Blast radius is small (SSM core only), but separate roles make the story honest. | **Fix or accept** |
| SEC-5 | Low | The masquerade rule covers the whole VPC CIDR and the `FORWARD` chain accepts anything. The security group saves the day by limiting sources to subnet B, so this is defence in depth, not a hole. Scope `-s` to the subnet you actually serve. | **Fix** |
| SEC-6 | Low | `http_tokens = "required"` is set, the hop limit is left to the AMI's default. Set `http_put_response_hop_limit = 1` explicitly; trusting defaults is how defaults become incidents. | **Fix** |
| SEC-7 | Low | Egress rules have no `description` (CKV_AWS_23). Future you, reading the console at 3 a.m., would like a word. | **Fix** |
| SEC-8 | Info | No VPC Flow Logs (CKV2_AWS_11). In production this is non-negotiable. In a three-hour lab, it is a CloudWatch bill for logs nobody will read. | **Accept**, or add behind a variable |
| SEC-9 | Info | The NAT instance SG allows all egress (CKV_AWS_382 again). Yes. It is a NAT. Sending things everywhere is the job description. | **Accept** (suppress with a comment) |
| SEC-10 | Info | AMI resolved from the `latest` SSM parameter, packages installed from the internet at boot. Always patched on first boot, never reproducible. For a disposable lab that is the right trade; for anything longer, bake an AMI. | **Accept** |
| SEC-11 | Info | None of the three doors inspects or filters anything. A NAT Gateway shrinks the attack surface; it does not read your packets. Egress control is a different product (Network Firewall, DNS Firewall) and out of scope here. | **Document** |
| SEC-12 | Info | Local state, no remote backend. Nothing secret lives in it and it is gitignored. | **Accept** |

### 3. Reliability

| ID | Severity | Finding | Verdict |
| --- | --- | --- | --- |
| REL-1 | By design | Everything lives in one AZ. If it has a bad day, so do you. The single AZ is what keeps cross-AZ charges out of the comparison. | **Accept** |
| REL-2 | By design | The NAT instance is a single instance with no Auto Scaling group, no failover and no health check. It is the pet the article warns you about, displayed in its natural habitat. | **Accept** (already flagged in the README) |
| REL-3 | Low | `names[0]` of an unfiltered AZ list picks "whichever comes first" (CKV_AWS_394). Deterministic enough for a lab; pin it or filter it if you ever care which AZ. | **Accept** |
| REL-4 | Low | If the NAT instance's user data fails, the only symptom is a test instance that never appears in SSM. `check-egress.sh` will then wait politely for a command that cannot be delivered. A timeout on the waiter would be kind. | **Fix or accept** |
| REL-5 | Info | The Regional NAT Gateway can take a while to expand; the outputs can be empty right after `apply`. Documented in the README. | **Accept** |

### 4. Performance efficiency

| ID | Severity | Finding | Verdict |
| --- | --- | --- | --- |
| PERF-1 | Info | `t4g.nano` as a router: burstable CPU, burstable network. For three `curl` calls it is a Ferrari. For a real workload it is a scooter towing a caravan. | **Accept** |
| PERF-2 | False positive | CKV_AWS_135 wants `ebs_optimized = true`. T4g instances are EBS-optimized by default. Set the attribute if you want the scanner to stop sulking. | **Suppress** |
| PERF-3 | Info | CKV_AWS_126 wants detailed monitoring on four nano instances. Paying for one-minute metrics on a lab you watch with `curl` is performance art, not performance efficiency. | **Accept** |

### 5. Cost optimization

| ID | Severity | Finding | Verdict |
| --- | --- | --- | --- |
| COST-1 | Medium | No guardrail against the classic: "I'll destroy it after lunch." Left running, the lab costs about $90 a month (two NAT Gateways, three public IPv4 addresses, four nano instances, four small volumes, us-east-1 list prices). A budget alert costs nothing; forgetting costs a nice dinner. | **Fix** |
| COST-2 | Low | The `Project`, `Environment`, `Service` and `Purpose` tags are genuinely good. They are also invisible in Cost Explorer until someone activates them as cost allocation tags in the Billing console. Tagging without activating is a diary nobody reads. | **Document** |
| COST-3 | Info | No S3 gateway endpoint, in a lab whose article preaches VPC endpoints. Defensible: Amazon Linux repositories live in S3, so an endpoint would let `dnf` skip the NAT and hide the very thing being tested. Irony noted, design accepted. | **Accept** |
| COST-4 | Info | Two NAT Gateways are the entire point and also 70% of the bill. Working as intended, which is the saddest sentence in FinOps. | **Accept** |

### 6. Sustainability

| ID | Severity | Finding | Verdict |
| --- | --- | --- | --- |
| SUS-1 | Good | Graviton everywhere, the smallest instance type available, and a lifetime measured in hours. | Nothing to do |
| SUS-2 | Info | The only real waste is leaving it on. See COST-1: the planet and your wallet agree for once. | Covered by COST-1 |

---

### Fix list, cheapest first

1. **OPS-1 / OPS-2:** delete `az_map` from `locals.tf` (or point it at `data.aws_availability_zones.available`). The repo validates again.
2. **SEC-1 / SEC-6:** add to every `aws_instance`:
   ```hcl
   root_block_device {
     encrypted = true
   }

   metadata_options {
     http_tokens                 = "required"
     http_put_response_hop_limit = 1
   }
   ```
3. **SEC-2:** lock the default security group:
   ```hcl
   resource "aws_default_security_group" "main" {
     vpc_id = aws_vpc.main.id
     # no ingress, no egress: nothing in, nothing out
   }
   ```
4. **SEC-3 / SEC-7:** narrow the test instances' egress:
   ```hcl
   egress {
     description = "HTTPS only: SSM, dnf and the egress check"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ```
5. **SEC-5:** in the user data, replace `-s ${var.vpc_cidr}` with the CIDR of private subnet B.
6. **OPS-4:** run `terraform init` and commit `.terraform.lock.hcl`.
7. **OPS-3:** add a workflow running `terraform fmt -check`, `terraform validate` and checkov on every push.
8. **OPS-5 / OPS-8:** refresh the README file table, add output descriptions, add `.DS_Store` to `.gitignore`.
9. **COST-1:** add a small AWS Budgets alert, or at least a calendar reminder with a threatening title.

### Bottom line

Security by design is mostly there: no keys, no inbound, no long-lived secrets, tokens required. The gaps are the unglamorous defaults (disk encryption, default security group, wide-open egress on boxes that only speak HTTPS), each fixable in a handful of lines.

Reliability is poor by construction, and that is the lesson of the lab, not a defect of it: this is what a NAT instance looks like when nobody builds the machinery around it, and why production gets a NAT Gateway.

The one finding that truly matters today is the least sophisticated: the code does not validate. Fix that first. Architecture reviews are more convincing when the architecture can be applied.

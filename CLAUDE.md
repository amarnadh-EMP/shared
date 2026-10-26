# Standing instructions (owner: Amarnadh Gunakala)

## Deletion guardrail (applies to ALL environments: dev, QA, prod, and every resource type)
- Never delete, drop, truncate, overwrite or revoke anything without first showing the exact command/SQL,
  the account and the specific resource, and getting the owner's explicit yes for THAT action.
  An earlier approval never carries over to the next action.
- This includes "cleanup", and applies to Redshift tables/rows, Glue jobs, S3 objects/buckets, Lambda,
  CloudFormation stacks, secrets, and anything else.
- Before deleting rows or tables, run a SELECT count(*) with the same WHERE and show the result.
- Never delete an existing job or table on your own. If a command might remove something that already
  existed, stop and ask. Treat ambiguous cases (overwrites, `--delete` syncs, CREATE OR REPLACE,
  ALTER ... DROP) as destructive.
- Only objects you created yourself in the session may be proposed for cleanup, and still ask first.
- Default to read-only. Use the least-privileged credentials; use the ETL user only when a write is needed.

## Connecting to AWS (no secrets stored here)
The owner approves the SSO login from their phone. The approval lasts only for the session, so start the
device-code login, give the owner the link and wait. Everything else is scripted:
1. Run `aws-tools/bootstrap-aws.sh` (installs AWS CLI v2 into `~/.local/aws-cli-v2` and writes the `capsa`
   sso-session plus `dev`, `qa`, `prod` profiles; safe to re-run). `pip install awscli` gives v1, which cannot do `sso login`.
2. Run `~/.local/aws-cli-v2/bin/aws sso login --sso-session capsa --no-browser --use-device-code`, send the
   owner the verification link and wait for their approval.
3. Run aws with `env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY ... --profile dev|qa|prod`; the placeholder
   keys in the environment override the profile and cause InvalidClientTokenId.
- Account IDs: dev 110611798842, qa 491087500610, prod 698772346265; role CapsaAWSDevelopersEDM-UserAccess; SSO https://capsa.awsapps.com/start (us-east-1).
- When the owner says "connect to dev/QA/prod", use the matching profile without asking again.
- Optional: the owner can put `bash aws-tools/bootstrap-aws.sh` in the environment's Setup script so step 1 runs automatically.

## Redshift (dev)
- Cluster `capsa-edm-dev`, region us-east-2, database `dev`. Schemas: gold_insight, silver_insight, report_insight.
- SSO role can use the Data API with no db-user: read-only on most tables, cannot create tables.
- ETL user (secret `dev/capsa_edm_etl_user/redshift`, pass its ARN via `--secret-arn`; never print the
  secret value) can write and create tables, and has DROP/DELETE rights, so the deletion guardrail applies.

## Memory protocol (standing authorization from the owner)
- When the owner says "remember this", "globally", or states a preference or rule to keep, write it to this
  file (or a topic file next to it) in markdown and commit and push it to their GitHub without asking.
  This is the owner's staging/memory store; do not use their phone or anything else for it.
- Push only to the session's designated working branch, never to `master` or another branch, and open
  no pull request unless asked.
- Never put secrets in it: no passwords, keys, tokens or secret values. Names, ARNs and account IDs are fine.
- Do not remove or rewrite existing entries unless the owner asks. The deletion guardrail above applies to this file too.
- After saving, tell the owner in one line what was saved.

## Guarded Redshift runner
Use `aws-tools/rs_safe.sh <iam|etl> "<sql>" [--allow-write]` for all Redshift SQL (dev cluster only). It is
read-only by default, always refuses DROP/TRUNCATE/DELETE/ALTER/GRANT/REVOKE/VACUUM/UNLOAD/COPY/CALL,
refuses multiple statements and an UPDATE without WHERE, and never reads the secret value. Destructive SQL
must only be run by hand after the owner approves that exact statement.

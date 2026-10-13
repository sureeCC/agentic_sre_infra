locals {
  branch_name = lower(get_env("BRANCH_NAME", get_env("GITHUB_REF_NAME", "")))
  env_aliases = { dev = "dev", qa = "qa", prod = "prod" }
  environment = local.env_aliases[local.branch_name]
  repo_name   = basename(get_env("GITHUB_REPOSITORY", "agentic-sre-infra"))
}

variable "application" {
  default     = "celery-stalk"
  description = "Identifying prefix for this application."
}

variable "codebuild_github_source" {
  default     = "https://github.com/chainstay/celery_stalk.git"
  description = "Repo that will be pulled for Codebuild, must contain a buildspec.yml"
}

variable "github_oauth_token" {
  description = "Github Personal access token with access to read from repos and write to commit status."
}

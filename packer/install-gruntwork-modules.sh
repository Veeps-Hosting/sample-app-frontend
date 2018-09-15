#!/bin/bash
# Install the Gruntwork modules used by this app.

set -e

readonly GRUNTWORK_INSTALL_VERSION="v0.0.21"
readonly GRUNTKMS_VERSION="v0.0.6"
readonly MODULE_SECURITY_VERSION="v0.15.1"
readonly MODULE_AWS_MONITORING_VERSION="v0.9.1"

function print_usage {
  echo
  echo "Usage: install-gruntwork-modules.sh"
  echo
  echo "Install the Gruntwork modules used by this app."
  echo
  echo "This script is configured via environment variables so it's easy to use with Packer:"
  echo
  echo -e "  AWS_REGION\t\t\t\tThe AWS region this server will be deployed to. Required."
  echo -e "  SSH_GRUNT_GROUP\t\t\t\tThe name of the IAM group that should get SSH access. Required."
  echo -e "  SSH_GRUNT_SUDO_GROUP\t\t\tThe name of the IAM group that should get SSH access with sudo privileges. Required."
  echo -e "  EXTERNAL_ACCOUNT_SSH_GRUNT_ROLE_ARN\tThe name of the IAM role to assume to talk to IAM in another account. Optional."
  echo -e "  GITHUB_OAUTH_TOKEN\t\tA GitHub personal access token. Must be from a user who has access to the Gruntwork repositories. Required."
  echo
  echo "Example:"
  echo
  echo "  AWS_REGION=eu-west-1 GITHUB_OAUTH_TOKEN=1234567890abcdefghij SSH_GRUNT_GROUP=ssh-grunt-users SSH_GRUNT_SUDO_GROUP=ssh-grunt-sudo-users install-gruntwork-modules.sh"
}

function install_security_packages {
  local readonly grunt_kms_version="$1"
  local readonly module_security_version="$2"
  local readonly ssh_grunt_group="$3"
  local readonly ssh_grunt_sudo_group="$4"
  local readonly external_account_ssh_grunt_role_arn="$5"

  echo "Installing Gruntwork Security Modules"

  gruntwork-install --binary-name 'gruntkms' --repo https://github.com/gruntwork-io/gruntkms --tag "$grunt_kms_version"
  gruntwork-install --module-name 'auto-update' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --module-name 'fail2ban' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --module-name 'ntp' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --module-name 'ip-lockdown' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --binary-name 'ssh-grunt' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  sudo /usr/local/bin/ssh-grunt iam install --iam-group "$ssh_grunt_group" --iam-group-sudo "$ssh_grunt_sudo_group" --role-arn "$external_account_ssh_grunt_role_arn"
}

function install_monitoring_packages {
  local readonly module_aws_monitoring_version="$1"
  local readonly aws_region="$2"

  echo "Installing Gruntwork Monitoring Modules"

  gruntwork-install --module-name 'logs/cloudwatch-log-aggregation-scripts' --repo https://github.com/gruntwork-io/module-aws-monitoring --tag "$module_aws_monitoring_version" --module-param aws-region="$aws_region"
  gruntwork-install --module-name 'metrics/cloudwatch-memory-disk-metrics-scripts' --repo https://github.com/gruntwork-io/module-aws-monitoring --tag "$module_aws_monitoring_version"
  gruntwork-install --module-name 'logs/syslog' --repo https://github.com/gruntwork-io/module-aws-monitoring --tag "$module_aws_monitoring_version"
}

function assert_env_var_not_empty {
  local readonly var_name="$1"
  local readonly var_value="${!var_name}"

  if [[ -z "$var_value" ]]; then
    echo "ERROR: Required environment variable $var_name not set."
    print_usage
    exit 1
  fi
}

function install_bash_commons {
  local -r bash_commons_version="$1"

  echo "Installing bash-commons version $bash_commons_version"
  gruntwork-install --module-name 'bash-commons' --repo https://github.com/gruntwork-io/bash-commons --tag "$bash_commons_version"
}

function install_gruntwork_modules {
  assert_env_var_not_empty "GITHUB_OAUTH_TOKEN"
  assert_env_var_not_empty "AWS_REGION"
  assert_env_var_not_empty "SSH_GRUNT_GROUP"
  assert_env_var_not_empty "SSH_GRUNT_SUDO_GROUP"

  local aws_region="$AWS_REGION"
  local ssh_grunt_group="$SSH_GRUNT_GROUP"
  local ssh_grunt_sudo_group="$SSH_GRUNT_SUDO_GROUP"
  local external_account_ssh_grunt_role_arn="$EXTERNAL_ACCOUNT_SSH_GRUNT_ROLE_ARN"

  curl -Ls https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh | bash /dev/stdin --version "$GRUNTWORK_INSTALL_VERSION"

  install_bash_commons "v0.0.4"
  install_security_packages "$GRUNTKMS_VERSION" "$MODULE_SECURITY_VERSION" "$ssh_grunt_group" "$ssh_grunt_sudo_group" "$external_account_ssh_grunt_role_arn"
  install_monitoring_packages "$MODULE_AWS_MONITORING_VERSION" "$aws_region"
}

install_gruntwork_modules
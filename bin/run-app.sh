#!/bin/bash
# This script is meant to be called from the User Data of a booting EC2 Instance to boot up sample-app-frontend.
# Note that this script assumes its running the an AMI built from the Packer template at packer/build.json.

set -e

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function print_usage {
  echo
  echo "Usage: run-app.sh [OPTIONS]"
  echo
  echo "This script is meant to be called from the User Data of a booting EC2 Instance to boot up sample-app-frontend."
  echo
  echo "Options:"
  echo
  echo -e "  --aws-region\t\tThe name of the AWS region this app is running in."
  echo -e "  --vpc-name\t\tThe name of the VPC this app is running in."
  echo -e "  --asg-name\t\tThe name of the Auto Scaling Group this app is running in."
  echo -e "  --port\t\tThe port the app should listen on."
  echo -e "  --db-url\t\tThe URL of the database."
  echo -e "  --internal-alb-url\tThe URL of a load balancer that can be used to make calls to other services."
  echo -e "  --internal-alb-port\tThe port to use for the load balancer that can be used to make calls to other services."
  echo -e "  --help\t\tShow this help text and exit."
  echo
  echo "Example:"
  echo
  echo "  run-app.sh --aws-region us-east-1 --vpc-name stage --asg-name sample-app-stage --port 8080 --db-url abc.def.us-east-1.rds.amazonaws.com --internal-alb-url abc.us-east1.alb.amazonaws.com"
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function decrypt_config {
  local readonly vpc_name="$1"
  local readonly aws_region="$2"
  local readonly config_file="$SCRIPT_DIR/../config/example-config-$vpc_name.json"

  log_info "Loading configuration from $config_file"
  local encrypted_config_contents
  encrypted_config_contents=$(cat "$config_file")

  if [[ "$vpc_name" == "development" ]]; then
    log_info "VPC name is set to development, so no need to decrypt secrets."
    echo -n "$encrypted_config_contents"
  else
    log_info "Decrypting secrets in $config_file using gruntkms in region $aws_region for VPC $vpc_name"
    gruntkms decrypt --aws-region "$aws_region" --ciphertext "$encrypted_config_contents"
  fi
}

function decrypt_tls_cert_private_key {
  local readonly cert_private_key_encrypted_path="$1"
  local readonly vpc_name="$2"
  local readonly aws_region="$3"

  log_info "Loading TLS cert private key from $cert_private_key_encrypted_path"
  local private_key_encrypted
  private_key_encrypted=$(cat "$cert_private_key_encrypted_path")

  if [[ "$vpc_name" == "development" ]]; then
    log_info "VPC name is set to development, so no need to decrypt the TLS cert private key"
    echo -n "$private_key_encrypted"
  else
    log_info "Decrypting TLS cert private key in $cert_private_key_encrypted_path using gruntkms in region $aws_region for VPC $vpc_name"
    gruntkms decrypt --aws-region "$aws_region" --ciphertext "$private_key_encrypted"
  fi
}

function start_cloudwatch_logs_agent {
  local readonly vpc_name="$1"
  local readonly log_group_name="$2"

  log_info "Starting CloudWatch Logs Agent in VPC $vpc_name"
  /etc/user-data/cloudwatch-log-aggregation/run-cloudwatch-logs-agent.sh --vpc-name "$vpc_name" --log-group-name "$log_group_name"
}

function start_fail2ban {
  log_info "Starting fail2ban"
  /etc/user-data/configure-fail2ban-cloudwatch/configure-fail2ban-cloudwatch.sh --cloudwatch-namespace Fail2Ban
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function assert_is_installed {
  local readonly name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function run_app {
  local aws_region
  local vpc_name
  local asg_name
  local port
  local db_url
  local internal_alb_url
  local internal_alb_port

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --aws-region)
        aws_region="$2"
        shift
        ;;
      --vpc-name)
        vpc_name="$2"
        shift
        ;;
      --asg-name)
        asg_name="$2"
        shift
        ;;
      --port)
        port="$2"
        shift
        ;;
      --db-url)
        db_url="$2"
        shift
        ;;
      --internal-alb-url)
        internal_alb_url="$2"
        shift
        ;;
      --internal-alb-port)
        internal_alb_port="$2"
        shift
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--aws-region" "$aws_region"
  assert_not_empty "--vpc-name" "$vpc_name"
  assert_not_empty "--asg-name" "$asg_name"
  assert_not_empty "--port" "$port"
  assert_not_empty "--db-url" "$db_url"
  assert_not_empty "--internal-alb-url" "$internal_alb_url"

  assert_is_installed "jq"
  assert_is_installed "gruntkms"
  assert_is_installed "nodejs"
  local readonly tls_cert_private_key_path="$SCRIPT_DIR/../tls/cert-$vpc_name.key.pem.kms.encrypted"
  start_cloudwatch_logs_agent "${vpc_name}" "${asg_name}"
  start_fail2ban

  local decrypted_config
  decrypted_config=$(decrypt_config "$vpc_name" "$aws_region")

  local decrypted_tls_cert_private_key
  decrypted_tls_cert_private_key=$(decrypt_tls_cert_private_key "$tls_cert_private_key_path" "$vpc_name" "$aws_region")

  # Set env vars for the Node app to read
  export PORT="$port"
  export VPC_NAME="$vpc_name"
  export DB_URL="$db_url"
  export INTERNAL_ALB_URL="$internal_alb_url"
  export BACKEND_PORT="$internal_alb_port"

  log_info "Starting app on port $port"

  # Below, we (1) create a named pipe, (2) spawn a background process that will write the config to that pipe as
  # soon as someone tries to read from the pipe, and (3) delete the pipe once it has been read. Our app can then read
  # from this pipe just as if it was a file—in fact, an empty file node is written to disk—but all the data will be
  # kept entirely in memory, and readable only once, keeping our secrets secure.
  #  We also use the same process to keep the TLS cert private key secure.
  # For more info, see: https://unix.stackexchange.com/a/63933/215969

  local readonly config_pipe_path="$SCRIPT_DIR/../config/example-config-$vpc_name-named-pipe.json"
  mkfifo "$config_pipe_path"
  (echo -e "$decrypted_config" > "$config_pipe_path" && rm -f "$config_pipe_path") &

  local readonly tls_cert_pipe_path="$SCRIPT_DIR/../tls/cert-$vpc_name-named-pipe.key.pem"
  mkfifo "$tls_cert_pipe_path"
  (echo -e "$decrypted_tls_cert_private_key" > "$tls_cert_pipe_path" && rm -f "$tls_cert_pipe_path") &

  # TODO: You should run real-world applications using a process supervisor such as systemd to ensure that if your app
  # crashes or the server reboots, your app will restart automatically! Also, in the particular case of Node, you'll
  # probably want to run one Node process per CPU core, perhaps by using Node cluster.
  nohup nodejs "$SCRIPT_DIR/../app/server.js" "$config_pipe_path" "$tls_cert_pipe_path" &

  # Lock down the EC2 metadata endpoint so only the root user can access it
  /usr/local/bin/ip-lockdown 169.254.169.254 root
}

run_app "$@"


#!/bin/bash
set -euo pipefail

# CircleCI investigation toolbox.
# Calls CircleCI API v2 / v1.1 with the Circle-Token header read from $CIRCLECI_TOKEN.

CIRCLECI_API_BASE="https://circleci.com"

# ---------------------------------------------------------------
# helpers
# ---------------------------------------------------------------

die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: circleci.sh <subcommand> <input>

Subcommands:
  status    <input>                Show job metadata (status, started_at, ...)
  jobs      <input>                List jobs in the workflow(s)
  artifacts <input>                List artifacts produced by the job
  usage     <input>                Show resource_class / parallelism / step durations
  steplog   <input> [--output-dir DIR]
                                   Save raw stdout/stderr of every step into a single file
                                   (filename: circleci-steplog-...) and print the absolute path
  tests     <input> [--output-dir DIR]
                                   Save the full paginated test result list into a JSON file
                                   (filename: circleci-tests-...) and print the absolute path

Input formats (interchangeable across all subcommands):
  job_url:      https://app.circleci.com/pipelines/<vcs>/<org>/<project>/<pipeline_num>/workflows/<workflow_id>/jobs/<build_num>
  pipeline_url: https://app.circleci.com/pipelines/<vcs>/<org>/<project>/<pipeline_num>
  branch+job:   --branch <name> --project <vcs_short>/<org>/<project> --job <job_name>
                  -> resolves to the latest pipeline of <name>, then the first workflow
                     containing a job whose name == <job_name>

Environment:
  CIRCLECI_TOKEN  CircleCI Personal API Token (required)
EOF
  exit 1
}

_get_token() {
  if [[ -z "${CIRCLECI_TOKEN:-}" ]]; then
    die "CIRCLECI_TOKEN is not set. Issue a token at https://circleci.com/settings/user/tokens and 'export CIRCLECI_TOKEN=...'"
  fi
  printf '%s' "$CIRCLECI_TOKEN"
}

# Call CircleCI API and emit response body to stdout.
# On HTTP >= 400 it dies with a message containing the response body
# (with the token redacted) - the token itself is only passed via the
# Circle-Token header.
# Usage: _api <api_version> <path>   where api_version = "v2" | "v1.1"
_api() {
  local version="$1"
  local path="$2"
  local token
  token="$(_get_token)"
  local url="${CIRCLECI_API_BASE}/api/${version}${path}"
  # Append "\n<http_code>" after the response body so we can split them
  # without touching the filesystem. This avoids depending on $TMPDIR
  # being writable, which is not guaranteed under sandboxed runners.
  # `--` separates options from the URL so a future code path that produces
  # a URL starting with '-' cannot inject curl flags.
  local response http_code body
  if ! response=$(curl -sS -w $'\n%{http_code}' \
                       -H "Circle-Token: $token" \
                       -- "$url"); then
    die "CircleCI API ${version} request failed (network/TLS error) for ${path}"
  fi
  http_code="${response##*$'\n'}"
  body="${response%$'\n'*}"
  if [[ ! "$http_code" =~ ^[0-9]+$ ]]; then
    die "CircleCI API ${version} returned no HTTP status (got '${http_code}') for ${path}"
  fi
  if [[ "$http_code" -ge 400 ]]; then
    # Defensive token redaction in case CircleCI ever echoes the request
    # token in an error body (current behavior does not, but cheap to guard).
    local masked="${body//$token/***REDACTED***}"
    die "CircleCI API ${version} returned HTTP ${http_code} for ${path}: ${masked}"
  fi
  printf '%s' "$body"
}

_api_v2() { _api "v2" "$@"; }
_api_v1() { _api "v1.1" "$@"; }

# Walk CircleCI API v2 next_page_token cursors and emit a single merged
# `{"items":[...], "next_page_token":null}` JSON. Use this for endpoints
# whose first page may not contain all results (tests, artifacts, etc.).
#
# Items are accumulated as one compact JSON line per item, then folded into
# an array by `jq -s`. We deliberately avoid passing the growing merged JSON
# via `jq --argjson` because it would hit ARG_MAX once items reach ~MB scale
# (e.g. jobs with thousands of test results).
_api_v2_paginated() {
  local path="$1"
  local sep="?"
  [[ "$path" == *"?"* ]] && sep="&"
  local page next_token="" items_chunk accumulated=""
  while :; do
    local fetch_path="$path"
    [[ -n "$next_token" ]] && fetch_path="${path}${sep}page-token=${next_token}"
    page=$(_api_v2 "$fetch_path")
    items_chunk=$(printf '%s' "$page" | jq -c '.items[]?')
    [[ -n "$items_chunk" ]] && accumulated+="${items_chunk}"$'\n'
    next_token=$(printf '%s' "$page" | jq -r '.next_page_token // empty')
    [[ -z "$next_token" ]] && break
  done
  printf '%s' "$accumulated" | jq -s '{items: ., next_page_token: null}'
}

# ---------------------------------------------------------------
# context
# ---------------------------------------------------------------

CTX_VCS_TYPE=""
CTX_VCS_SHORT=""
CTX_ORG=""
CTX_PROJECT=""
CTX_PROJECT_SLUG=""
CTX_PIPELINE_NUM=""
CTX_PIPELINE_ID=""
CTX_WORKFLOW_ID=""
CTX_BUILD_NUM=""
CTX_BRANCH=""
CTX_JOB_NAME=""
CTX_SELECTED_REASON=""

# Normalize CTX_VCS_TYPE / CTX_VCS_SHORT and build CTX_PROJECT_SLUG.
# Accepts either the long form ("github"/"bitbucket") or the short form ("gh"/"bb").
# CTX_ORG and CTX_PROJECT must already be set by the caller. Returns 1 if the input
# is not a recognized VCS, so callers can decide whether to die or fall through.
_finalize_vcs_ctx() {
  local input="$1"
  case "$input" in
    gh|github)    CTX_VCS_TYPE="github";    CTX_VCS_SHORT="gh" ;;
    bb|bitbucket) CTX_VCS_TYPE="bitbucket"; CTX_VCS_SHORT="bb" ;;
    *) return 1 ;;
  esac
  CTX_PROJECT_SLUG="${CTX_VCS_SHORT}/${CTX_ORG}/${CTX_PROJECT}"
  return 0
}

# Parse a job URL and fill CTX_* variables. Returns 0 on success, 1 if the URL doesn't match.
_parse_job_url() {
  local url="$1"
  local re='^https://app\.circleci\.com/pipelines/([^/]+)/([^/]+)/([^/]+)/([0-9]+)/workflows/([0-9a-f-]+)/jobs/([0-9]+)/?$'
  if [[ ! "$url" =~ $re ]]; then
    return 1
  fi
  CTX_ORG="${BASH_REMATCH[2]}"
  CTX_PROJECT="${BASH_REMATCH[3]}"
  CTX_PIPELINE_NUM="${BASH_REMATCH[4]}"
  CTX_WORKFLOW_ID="${BASH_REMATCH[5]}"
  CTX_BUILD_NUM="${BASH_REMATCH[6]}"
  _finalize_vcs_ctx "${BASH_REMATCH[1]}" || die "Unsupported VCS in URL: ${BASH_REMATCH[1]}"
  return 0
}

# Parse a pipeline URL and fill CTX_* (pipeline-scope fields only).
# https://app.circleci.com/pipelines/<vcs>/<org>/<project>/<pipeline_num>
_parse_pipeline_url() {
  local url="$1"
  local re='^https://app\.circleci\.com/pipelines/([^/]+)/([^/]+)/([^/]+)/([0-9]+)/?$'
  if [[ ! "$url" =~ $re ]]; then
    return 1
  fi
  CTX_ORG="${BASH_REMATCH[2]}"
  CTX_PROJECT="${BASH_REMATCH[3]}"
  CTX_PIPELINE_NUM="${BASH_REMATCH[4]}"
  _finalize_vcs_ctx "${BASH_REMATCH[1]}" || die "Unsupported VCS in URL: ${BASH_REMATCH[1]}"
  return 0
}

# Parse a project slug like "gh/ClusterVR/cluster" or "github/ClusterVR/cluster"
# and fill CTX_VCS_TYPE / CTX_VCS_SHORT / CTX_ORG / CTX_PROJECT / CTX_PROJECT_SLUG.
_parse_project_slug() {
  local slug="$1"
  local re='^([^/]+)/([^/]+)/([^/]+)/?$'
  if [[ ! "$slug" =~ $re ]]; then
    return 1
  fi
  CTX_ORG="${BASH_REMATCH[2]}"
  CTX_PROJECT="${BASH_REMATCH[3]}"
  _finalize_vcs_ctx "${BASH_REMATCH[1]}"
}

# Resolve the latest run of <job_name> on <branch> in <project_slug>.
# Strategy: pick the latest pipeline on <branch>, walk its workflows newest-first,
# and find the first workflow that contains a job whose .name == <job_name>.
# Fills CTX_PIPELINE_NUM/_ID, CTX_WORKFLOW_ID, CTX_BUILD_NUM, CTX_BRANCH,
# CTX_JOB_NAME, and CTX_SELECTED_REASON.
_resolve_latest_run() {
  local branch="$1" project_slug="$2" job_name="$3"
  if ! _parse_project_slug "$project_slug"; then
    die "Invalid --project slug: '$project_slug' (expected <vcs>/<org>/<project> e.g. gh/ClusterVR/cluster)"
  fi
  CTX_BRANCH="$branch"
  CTX_JOB_NAME="$job_name"

  local branch_encoded pipelines
  branch_encoded=$(printf '%s' "$branch" | jq -sRr @uri)
  pipelines=$(_api_v2 "/project/${CTX_PROJECT_SLUG}/pipeline?branch=${branch_encoded}")

  local pipeline_id pipeline_num
  pipeline_id=$(printf '%s' "$pipelines" | jq -r '.items[0].id // empty')
  pipeline_num=$(printf '%s' "$pipelines" | jq -r '.items[0].number // empty')
  if [[ -z "$pipeline_id" ]]; then
    die "No pipeline found for branch '$branch' in ${CTX_PROJECT_SLUG}"
  fi
  CTX_PIPELINE_ID="$pipeline_id"
  CTX_PIPELINE_NUM="$pipeline_num"

  local workflows
  workflows=$(_api_v2 "/pipeline/${pipeline_id}/workflow")

  # Walk workflows newest-first so the user gets the most recent matching run
  # even if the API's default ordering changes in the future.
  local wf_id wf_name jobs match approval_seen=""
  while IFS=$'\t' read -r wf_id wf_name; do
    [[ -z "$wf_id" ]] && continue
    jobs=$(_api_v2 "/workflow/${wf_id}/job")
    # Single jq pass per workflow: classify the first matching job as
    # "none" (no name match), "pending" (matched but not yet started, e.g.
    # approval/queued -> job_number is null), or the job_number string.
    match=$(printf '%s' "$jobs" \
      | jq -r --arg n "$job_name" '
          [.items[] | select(.name == $n)]
          | if length == 0 then "none"
            elif (.[0].job_number == null) then "pending"
            else (.[0].job_number | tostring)
            end
        ')
    case "$match" in
      none)    : ;;
      pending) approval_seen="${wf_name} (${wf_id})" ;;
      *)
        CTX_WORKFLOW_ID="$wf_id"
        CTX_BUILD_NUM="$match"
        CTX_SELECTED_REASON="branch=${branch}, pipeline #${pipeline_num} (${pipeline_id}), workflow ${wf_name} (${wf_id}), job_number=${match}"
        return 0
        ;;
    esac
  done < <(printf '%s' "$workflows" | jq -r '
    .items
    | sort_by(.created_at)
    | reverse
    | .[]
    | [.id, .name]
    | @tsv
  ')

  if [[ -n "$approval_seen" ]]; then
    die "Job '$job_name' is on the latest pipeline (#${pipeline_num}) workflow ${approval_seen} but has no job_number yet (approval pending or not yet started)"
  fi
  die "Job '$job_name' not found in any workflow of the latest pipeline (#${pipeline_num}) on branch '$branch'"
}

# If branch+job resolution was used, log how it was resolved so the user can
# audit the auto-selected run. Stays out of stdout so JSON pipes still work.
_emit_resolved_if_any() {
  if [[ -n "$CTX_SELECTED_REASON" ]]; then
    echo "Resolved: $CTX_SELECTED_REASON" >&2
  fi
}

# Subcommands that operate on a specific job die early when the input only
# resolves to a pipeline (no build_num).
_require_job_context() {
  local subcmd="$1"
  if [[ -z "$CTX_BUILD_NUM" ]]; then
    die "${subcmd} requires a job-level input (job URL, or --branch/--project/--job)"
  fi
}

# Build the absolute path to write a per-job artifact (steplog/tests/...).
# Includes the subcommand name as a prefix so the filename communicates what
# kind of payload it holds (`circleci-steplog-...`, `circleci-tests-...`).
# - subcmd: "steplog", "tests", ... (filename prefix)
# - ext:    "log", "json", ...
# - out_dir: --output-dir value (empty = use $PWD)
# - job_name: human-readable job name, sanitized into the filename
# Creates the empty file inside a subshell with `umask 077` so secrets that
# may end up in the payload (env-derived values in CI logs, etc.) aren't
# world-readable. Pre-condition: CTX_ORG / CTX_PROJECT / CTX_BUILD_NUM set.
_make_output_file() {
  local subcmd="$1" ext="$2" out_dir="$3" job_name="$4"
  if [[ -n "$out_dir" ]]; then
    mkdir -p "$out_dir" || die "Cannot create --output-dir: $out_dir"
  else
    out_dir="$PWD"
  fi
  local safe_org safe_project safe_job
  safe_org="${CTX_ORG//[^a-zA-Z0-9._-]/-}"
  safe_project="${CTX_PROJECT//[^a-zA-Z0-9._-]/-}"
  safe_job="${job_name//[^a-zA-Z0-9._-]/-}"
  local file_name="circleci-${subcmd}-${safe_org}-${safe_project}-${safe_job}-${CTX_BUILD_NUM}.${ext}"
  local abs_dir
  abs_dir="$(cd "$out_dir" && pwd)"
  local out_file="${abs_dir}/${file_name}"
  ( umask 077 && : > "$out_file" )
  printf '%s' "$out_file"
}

# Accepts either:
#   - one positional URL (job URL or pipeline URL), or
#   - --branch <name> --project <slug> --job <name>
_resolve_context() {
  local url="" branch="" project="" job_name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch)
        [[ -z "${2:-}" ]] && die "--branch requires a value"
        branch="$2"; shift 2 ;;
      --project)
        [[ -z "${2:-}" ]] && die "--project requires a value"
        project="$2"; shift 2 ;;
      --job)
        [[ -z "${2:-}" ]] && die "--job requires a value"
        job_name="$2"; shift 2 ;;
      --)
        shift; break ;;
      -*)
        die "Unknown flag for context: $1" ;;
      *)
        if [[ -n "$url" ]]; then
          die "Multiple positional inputs provided: '$url' and '$1'"
        fi
        url="$1"; shift ;;
    esac
  done

  if [[ -n "$url" ]]; then
    if [[ -n "$branch" || -n "$project" || -n "$job_name" ]]; then
      die "URL input and --branch/--project/--job are mutually exclusive"
    fi
    if _parse_job_url "$url"; then
      return 0
    fi
    if _parse_pipeline_url "$url"; then
      return 0
    fi
    die "Unsupported input format: $url (expected job URL or pipeline URL)"
  fi

  if [[ -n "$branch" || -n "$project" || -n "$job_name" ]]; then
    if [[ -z "$branch" || -z "$project" || -z "$job_name" ]]; then
      die "Branch input requires all of --branch, --project, --job"
    fi
    _resolve_latest_run "$branch" "$project" "$job_name"
    return 0
  fi

  die "Input is required: provide a job/pipeline URL, or --branch <name> --project <slug> --job <name>"
}

# ---------------------------------------------------------------
# subcommands
# ---------------------------------------------------------------

cmd_status() {
  _resolve_context "$@"
  _require_job_context status
  _emit_resolved_if_any
  _api_v2 "/project/${CTX_PROJECT_SLUG}/job/${CTX_BUILD_NUM}"
}

# List jobs in workflows.
# - Job URL or --branch/--project/--job : returns the resolved workflow's job list
# - Pipeline URL : resolves pipeline_num -> pipeline_id, then returns one entry
#                  per workflow with its job list
cmd_jobs() {
  _resolve_context "$@"
  _emit_resolved_if_any
  if [[ -n "$CTX_WORKFLOW_ID" ]]; then
    _api_v2 "/workflow/${CTX_WORKFLOW_ID}/job"
    return
  fi
  if [[ -z "$CTX_PIPELINE_NUM" ]]; then
    die "Could not resolve pipeline or workflow from input"
  fi
  # Reuse pipeline_id if branch+job resolution already fetched it; otherwise
  # convert the pipeline_num from a URL into a pipeline_id with one extra call.
  if [[ -z "$CTX_PIPELINE_ID" ]]; then
    local pipeline_meta
    pipeline_meta=$(_api_v2 "/project/${CTX_PROJECT_SLUG}/pipeline/${CTX_PIPELINE_NUM}")
    CTX_PIPELINE_ID=$(printf '%s' "$pipeline_meta" | jq -r '.id // empty')
    [[ -z "$CTX_PIPELINE_ID" ]] && die "Pipeline #${CTX_PIPELINE_NUM} returned no id (unexpected response shape)"
  fi
  local workflows
  workflows=$(_api_v2 "/pipeline/${CTX_PIPELINE_ID}/workflow")
  local result
  result=$(jq -n \
    --arg pn "$CTX_PIPELINE_NUM" \
    --arg pid "$CTX_PIPELINE_ID" \
    '{pipeline_number: ($pn|tonumber), pipeline_id: $pid, workflows: []}')
  local workflow_id workflow_name jobs
  while IFS=$'\t' read -r workflow_id workflow_name; do
    [[ -z "$workflow_id" ]] && continue
    jobs=$(_api_v2 "/workflow/${workflow_id}/job")
    result=$(printf '%s' "$result" | jq \
      --arg id "$workflow_id" \
      --arg name "$workflow_name" \
      --argjson jobs "$jobs" \
      '.workflows += [{id: $id, name: $name, jobs: ($jobs.items // [])}]')
  done < <(printf '%s' "$workflows" | jq -r '.items[] | [.id, .name] | @tsv')
  printf '%s' "$result"
}

# List artifacts produced by a job.
cmd_artifacts() {
  _resolve_context "$@"
  _require_job_context artifacts
  _emit_resolved_if_any
  _api_v2_paginated "/project/${CTX_PROJECT_SLUG}/${CTX_BUILD_NUM}/artifacts"
}

# Show resource usage (resource_class, parallelism, build/step durations).
cmd_usage() {
  _resolve_context "$@"
  _require_job_context usage
  _emit_resolved_if_any
  local response
  response=$(_api_v1 "/project/${CTX_VCS_TYPE}/${CTX_ORG}/${CTX_PROJECT}/${CTX_BUILD_NUM}")
  printf '%s' "$response" | jq '{
    build_num,
    job_name: (.workflows.job_name // .job_name),
    status,
    parallelism: .parallel,
    executor: .picard.executor,
    resource_class: .picard.resource_class,
    queued_at: .usage_queued_at,
    started_at: .start_time,
    stopped_at: .stop_time,
    build_time_millis,
    steps: [
      .steps[] | {
        name,
        actions: [.actions[] | {index, status, exit_code, run_time_millis}]
      }
    ]
  }'
}

# Save all step logs of a job into a single file and print its absolute path.
# Implementation note: CircleCI API v2 has no endpoint that returns per-step
# stdout/stderr. We have to use the legacy v1.1 endpoint to get presigned S3
# `output_url` for each action, then download them sequentially.
cmd_steplog() {
  local output_dir=""
  local ctx_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output-dir)
        [[ -z "${2:-}" ]] && die "--output-dir requires a value"
        output_dir="$2"
        shift 2
        ;;
      *)
        ctx_args+=("$1")
        shift
        ;;
    esac
  done
  # bash 3.2 + `set -u` errors on "${arr[@]}" when the array is empty.
  # ${name+...} expands only if `name` is set, sidestepping that bug.
  _resolve_context ${ctx_args[@]+"${ctx_args[@]}"}
  _require_job_context steplog
  _emit_resolved_if_any

  local response job_name
  response=$(_api_v1 "/project/${CTX_VCS_TYPE}/${CTX_ORG}/${CTX_PROJECT}/${CTX_BUILD_NUM}")
  job_name=$(printf '%s' "$response" | jq -r '.workflows.job_name // .job_name // "job"')

  local out_file
  out_file=$(_make_output_file steplog log "$output_dir" "$job_name")

  local step_name action_index status exit_code duration_ms output_url
  while IFS=$'\t' read -r step_name action_index status exit_code duration_ms output_url; do
    {
      printf '========================================\n'
      printf 'Step: %s  (action[%s], status=%s, exit_code=%s, duration_ms=%s)\n' \
        "$step_name" "$action_index" "$status" "$exit_code" "$duration_ms"
      printf '========================================\n'
    } >> "$out_file"
    if [[ -z "$output_url" || "$output_url" == "null" ]]; then
      printf '(no output for this step)\n\n' >> "$out_file"
      continue
    fi
    # output_url is a presigned S3 URL - no auth header needed.
    # `--` ensures even a future URL beginning with '-' is not treated as a flag.
    if ! curl -sSf -- "$output_url" | jq -r '.[]?.message // empty' >> "$out_file"; then
      printf '(failed to fetch step output)\n' >> "$out_file"
    fi
    printf '\n' >> "$out_file"
  done < <(printf '%s' "$response" | jq -r '
    .steps[] as $step |
    $step.actions[] as $action |
    [
      $step.name,
      ($action.index | tostring),
      ($action.status // ""),
      ($action.exit_code | tostring),
      ($action.run_time_millis | tostring),
      ($action.output_url // "")
    ] | @tsv
  ')

  echo "Wrote step log: $out_file" >&2
  printf '%s\n' "$out_file"
}

# Save the full paginated test result list (raw) to a JSON file and print
# the absolute path. The caller is expected to query the file with jq for
# whatever subset they care about (failures, by classname, etc.) - this keeps
# multi-MB responses out of the calling chat context.
cmd_tests() {
  local output_dir=""
  local ctx_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output-dir)
        [[ -z "${2:-}" ]] && die "--output-dir requires a value"
        output_dir="$2"
        shift 2
        ;;
      *)
        ctx_args+=("$1")
        shift
        ;;
    esac
  done
  # bash 3.2 + `set -u` errors on "${arr[@]}" when the array is empty.
  # ${name+...} expands only if `name` is set, sidestepping that bug.
  _resolve_context ${ctx_args[@]+"${ctx_args[@]}"}
  _require_job_context tests
  _emit_resolved_if_any

  # Use the resolved CTX_JOB_NAME when branch+job mode set it; otherwise look
  # it up via the v2 job endpoint so the filename mirrors steplog's shape.
  local job_name="$CTX_JOB_NAME"
  if [[ -z "$job_name" ]]; then
    job_name=$(_api_v2 "/project/${CTX_PROJECT_SLUG}/job/${CTX_BUILD_NUM}" | jq -r '.name // "job"')
  fi

  local out_file
  out_file=$(_make_output_file tests json "$output_dir" "$job_name")
  _api_v2_paginated "/project/${CTX_PROJECT_SLUG}/${CTX_BUILD_NUM}/tests" > "$out_file"

  echo "Wrote tests: $out_file" >&2
  printf '%s\n' "$out_file"
}

# ---------------------------------------------------------------
# main
# ---------------------------------------------------------------

main() {
  if [[ $# -lt 1 ]]; then
    usage
  fi
  local subcmd="$1"
  shift
  case "$subcmd" in
    status)    cmd_status "$@" ;;
    jobs)      cmd_jobs "$@" ;;
    artifacts) cmd_artifacts "$@" ;;
    tests)     cmd_tests "$@" ;;
    usage)     cmd_usage "$@" ;;
    steplog)   cmd_steplog "$@" ;;
    -h|--help) usage ;;
    *)         die "Unknown subcommand: $subcmd" ;;
  esac
}

main "$@"

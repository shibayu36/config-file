#!/usr/bin/env python3
"""CircleCI investigation toolbox.

Calls CircleCI API v2 / v1.1 with the Circle-Token header read from
$CIRCLECI_TOKEN. Uses only the Python standard library.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, NoReturn

CIRCLECI_API_BASE = "https://circleci.com"
HTTP_TIMEOUT_SEC = 30


# ---------------------------------------------------------------
# helpers
# ---------------------------------------------------------------


def die(msg: str) -> NoReturn:
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def get_token() -> str:
    token = os.environ.get("CIRCLECI_TOKEN")
    if not token:
        die(
            "CIRCLECI_TOKEN is not set. Issue a token at "
            "https://circleci.com/settings/user/tokens "
            "and 'export CIRCLECI_TOKEN=...'"
        )
    return token


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Disable HTTP redirects on authenticated CircleCI API calls.

    urllib's default redirect handler forwards custom request headers
    (including Circle-Token) to the redirect target. CircleCI API does
    not redirect under normal use; treating any 30x as an error avoids
    accidentally leaking the token to a different host.
    """

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_API_OPENER = urllib.request.build_opener(_NoRedirect())


def api_request(
    version: str, path: str, params: dict[str, str] | None = None
) -> Any:
    """Call CircleCI API and return parsed JSON.

    Dies on HTTP >= 400 or network error. The token is sent only via the
    Circle-Token header; on error, redact the token from the response
    body before printing it.
    """
    token = get_token()
    url = f"{CIRCLECI_API_BASE}/api/{version}{path}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"Circle-Token": token})
    try:
        with _API_OPENER.open(req, timeout=HTTP_TIMEOUT_SEC) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        masked = err_body.replace(token, "***REDACTED***")
        die(f"CircleCI API {version} returned HTTP {e.code} for {path}: {masked}")
    except urllib.error.URLError as e:
        die(
            f"CircleCI API {version} request failed (network/TLS error) "
            f"for {path}: {e.reason}"
        )
    try:
        return json.loads(body)
    except json.JSONDecodeError as e:
        die(f"CircleCI API {version} returned non-JSON response for {path}: {e}")


def api_v2(path: str, params: dict[str, str] | None = None) -> Any:
    return api_request("v2", path, params)


def api_v1(path: str) -> Any:
    return api_request("v1.1", path)


def api_v2_paginated(
    path: str, params: dict[str, str] | None = None
) -> dict:
    """Walk CircleCI API v2 next_page_token cursors and return a single
    merged `{"items": [...], "next_page_token": null}` dict.

    Use this for endpoints whose first page may not contain all results
    (tests, artifacts, etc.). All items are accumulated in memory; this
    is fine for the multi-MB responses we have observed (e.g. ~8k tests).
    """
    items: list = []
    next_token: str | None = None
    while True:
        page_params = dict(params) if params else {}
        if next_token:
            page_params["page-token"] = next_token
        page = api_v2(path, page_params or None)
        items.extend(page.get("items", []))
        next_token = page.get("next_page_token")
        if not next_token:
            break
    return {"items": items, "next_page_token": None}


def fetch_public(url: str) -> bytes:
    """Fetch a public URL (e.g. presigned S3) without auth."""
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_SEC) as resp:
        return resp.read()


def print_json(obj: Any) -> None:
    print(json.dumps(obj, indent=2, ensure_ascii=False))


# ---------------------------------------------------------------
# context
# ---------------------------------------------------------------


@dataclass
class Context:
    vcs_type: str = ""
    vcs_short: str = ""
    org: str = ""
    project: str = ""
    project_slug: str = ""
    pipeline_num: int | None = None
    pipeline_id: str = ""
    workflow_id: str = ""
    build_num: int | None = None
    branch: str = ""
    job_name: str = ""
    selected_reason: str = ""

    def set_vcs(self, vcs_input: str) -> None:
        """Normalize vcs_type / vcs_short and build project_slug.

        Accepts either the long form ("github"/"bitbucket") or the short
        form ("gh"/"bb"). Caller must have already set org and project.
        Dies if the input is not a recognized VCS.
        """
        if vcs_input in ("gh", "github"):
            self.vcs_type = "github"
            self.vcs_short = "gh"
        elif vcs_input in ("bb", "bitbucket"):
            self.vcs_type = "bitbucket"
            self.vcs_short = "bb"
        else:
            die(f"Unsupported VCS: {vcs_input}")
        self.project_slug = f"{self.vcs_short}/{self.org}/{self.project}"


JOB_URL_RE = re.compile(
    r"^https://app\.circleci\.com/pipelines/([^/]+)/([^/]+)/([^/]+)/(\d+)"
    r"/workflows/([0-9a-f-]+)/jobs/(\d+)/?$"
)
PIPELINE_URL_RE = re.compile(
    r"^https://app\.circleci\.com/pipelines/([^/]+)/([^/]+)/([^/]+)/(\d+)/?$"
)
PROJECT_SLUG_RE = re.compile(r"^([^/]+)/([^/]+)/([^/]+)/?$")
SAFE_NAME_RE = re.compile(r"[^a-zA-Z0-9._-]")


def _sanitize_name(name: str) -> str:
    return SAFE_NAME_RE.sub("-", name)


def parse_job_url(ctx: Context, url: str) -> bool:
    m = JOB_URL_RE.match(url)
    if not m:
        return False
    ctx.org = m.group(2)
    ctx.project = m.group(3)
    ctx.pipeline_num = int(m.group(4))
    ctx.workflow_id = m.group(5)
    ctx.build_num = int(m.group(6))
    ctx.set_vcs(m.group(1))
    return True


def parse_pipeline_url(ctx: Context, url: str) -> bool:
    m = PIPELINE_URL_RE.match(url)
    if not m:
        return False
    ctx.org = m.group(2)
    ctx.project = m.group(3)
    ctx.pipeline_num = int(m.group(4))
    ctx.set_vcs(m.group(1))
    return True


def parse_project_slug(ctx: Context, slug: str) -> bool:
    """Parse a project slug like "gh/<org>/<project>" into Context."""
    m = PROJECT_SLUG_RE.match(slug)
    if not m:
        return False
    ctx.org = m.group(2)
    ctx.project = m.group(3)
    ctx.set_vcs(m.group(1))
    return True


def resolve_latest_run(
    ctx: Context, branch: str, project_slug: str, job_name: str
) -> None:
    """Resolve the latest run of <job_name> on <branch> in <project_slug>.

    Picks the latest pipeline on <branch>, walks its workflows in API
    default order, and selects the first workflow that contains a job
    whose name == <job_name>.
    """
    if not parse_project_slug(ctx, project_slug):
        die(
            f"Invalid --project slug: '{project_slug}' "
            "(expected <vcs>/<org>/<project> e.g. gh/ClusterVR/cluster)"
        )
    ctx.branch = branch
    ctx.job_name = job_name

    pipelines = api_v2(
        f"/project/{ctx.project_slug}/pipeline", {"branch": branch}
    )
    items = pipelines.get("items", [])
    if not items:
        die(f"No pipeline found for branch '{branch}' in {ctx.project_slug}")
    first = items[0]
    pipeline_id = first.get("id")
    pipeline_num = first.get("number")
    if not pipeline_id or not pipeline_num:
        die(f"No pipeline found for branch '{branch}' in {ctx.project_slug}")
    ctx.pipeline_id = pipeline_id
    ctx.pipeline_num = pipeline_num

    workflows = api_v2(f"/pipeline/{pipeline_id}/workflow")

    approval_seen = ""
    for wf in workflows.get("items", []):
        wf_id = wf.get("id")
        wf_name = wf.get("name", "")
        if not wf_id:
            continue
        jobs = api_v2(f"/workflow/{wf_id}/job")
        matches = [
            j for j in jobs.get("items", []) if j.get("name") == job_name
        ]
        if not matches:
            continue
        first_match = matches[0]
        if first_match.get("job_number") is None:
            approval_seen = f"{wf_name} ({wf_id})"
            continue
        ctx.workflow_id = wf_id
        ctx.build_num = first_match["job_number"]
        ctx.selected_reason = (
            f"branch={branch}, pipeline #{pipeline_num} ({pipeline_id}), "
            f"workflow {wf_name} ({wf_id}), "
            f"job_number={first_match['job_number']}"
        )
        return

    if approval_seen:
        die(
            f"Job '{job_name}' is on the latest pipeline (#{pipeline_num}) "
            f"workflow {approval_seen} but has no job_number yet "
            "(approval pending or not yet started)"
        )
    die(
        f"Job '{job_name}' not found in any workflow of the latest pipeline "
        f"(#{pipeline_num}) on branch '{branch}'"
    )


def emit_resolved_if_any(ctx: Context) -> None:
    if ctx.selected_reason:
        print(f"Resolved: {ctx.selected_reason}", file=sys.stderr)


def require_job_context(ctx: Context, subcmd: str) -> None:
    if ctx.build_num is None:
        die(
            f"{subcmd} requires a job-level input "
            "(job URL, or --branch/--project/--job)"
        )


def make_output_path(
    ctx: Context, subcmd: str, ext: str, out_dir: str, job_name: str
) -> str:
    """Build the absolute output path for a per-job artifact.

    Caller is expected to open the path with `open_secure` so the file
    lands as 0o600 (CI logs may contain env-derived secrets).
    """
    if out_dir:
        try:
            os.makedirs(out_dir, exist_ok=True)
        except OSError as e:
            die(f"Cannot create --output-dir: {out_dir}: {e}")
    else:
        out_dir = os.getcwd()
    file_name = (
        f"circleci-{subcmd}-{_sanitize_name(ctx.org)}-"
        f"{_sanitize_name(ctx.project)}-{_sanitize_name(job_name)}-"
        f"{ctx.build_num}.{ext}"
    )
    return os.path.join(os.path.abspath(out_dir), file_name)


def open_secure(path: str):
    """Open `path` for writing with mode 0o600.

    O_NOFOLLOW prevents following an attacker-placed symlink at the final
    path component. umask is temporarily zeroed so the mode lands as 0o600
    even if the calling process has a more permissive umask.
    """
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW
    old_umask = os.umask(0)
    try:
        fd = os.open(path, flags, 0o600)
    finally:
        os.umask(old_umask)
    return os.fdopen(fd, "w", encoding="utf-8")


def resolve_context(ctx: Context, args: argparse.Namespace) -> None:
    """Accepts either:
    - one positional URL (job URL or pipeline URL), or
    - --branch <name> --project <slug> --job <name>

    Empty strings on any of these are treated as "not provided".
    """
    url = args.url or None
    branch = args.branch or None
    project = args.project or None
    job_name = args.job or None

    if url:
        if branch or project or job_name:
            die("URL input and --branch/--project/--job are mutually exclusive")
        if parse_job_url(ctx, url):
            return
        if parse_pipeline_url(ctx, url):
            return
        die(f"Unsupported input format: {url} (expected job URL or pipeline URL)")

    if branch or project or job_name:
        if not (branch and project and job_name):
            die("Branch input requires all of --branch, --project, --job")
        resolve_latest_run(ctx, branch, project, job_name)
        return

    die(
        "Input is required: provide a job/pipeline URL, "
        "or --branch <name> --project <slug> --job <name>"
    )


# ---------------------------------------------------------------
# subcommands
# ---------------------------------------------------------------


def cmd_status(ctx: Context, args: argparse.Namespace) -> None:
    resolve_context(ctx, args)
    require_job_context(ctx, "status")
    emit_resolved_if_any(ctx)
    result = api_v2(f"/project/{ctx.project_slug}/job/{ctx.build_num}")
    print_json(result)


def cmd_jobs(ctx: Context, args: argparse.Namespace) -> None:
    """List jobs in workflows.

    - Job URL or --branch/--project/--job: returns the resolved workflow's
      job list.
    - Pipeline URL: resolves pipeline_num -> pipeline_id, then returns one
      entry per workflow with its job list.
    """
    resolve_context(ctx, args)
    emit_resolved_if_any(ctx)
    if ctx.workflow_id:
        result = api_v2(f"/workflow/{ctx.workflow_id}/job")
        print_json(result)
        return
    if ctx.pipeline_num is None:
        die("Could not resolve pipeline or workflow from input")
    if not ctx.pipeline_id:
        meta = api_v2(f"/project/{ctx.project_slug}/pipeline/{ctx.pipeline_num}")
        pipeline_id = meta.get("id")
        if not pipeline_id:
            die(
                f"Pipeline #{ctx.pipeline_num} returned no id "
                "(unexpected response shape)"
            )
        ctx.pipeline_id = pipeline_id
    workflows = api_v2(f"/pipeline/{ctx.pipeline_id}/workflow")
    payload: dict[str, Any] = {
        "pipeline_number": int(ctx.pipeline_num),
        "pipeline_id": ctx.pipeline_id,
        "workflows": [],
    }
    for wf in workflows.get("items", []):
        wf_id = wf.get("id")
        wf_name = wf.get("name", "")
        if not wf_id:
            continue
        jobs = api_v2(f"/workflow/{wf_id}/job")
        payload["workflows"].append({
            "id": wf_id,
            "name": wf_name,
            "jobs": jobs.get("items", []),
        })
    print_json(payload)


def cmd_artifacts(ctx: Context, args: argparse.Namespace) -> None:
    resolve_context(ctx, args)
    require_job_context(ctx, "artifacts")
    emit_resolved_if_any(ctx)
    result = api_v2_paginated(
        f"/project/{ctx.project_slug}/{ctx.build_num}/artifacts"
    )
    print_json(result)


def _format_action(a: dict) -> dict:
    return {
        "index": a.get("index"),
        "status": a.get("status"),
        "exit_code": a.get("exit_code"),
        "run_time_millis": a.get("run_time_millis"),
    }


def _format_step(s: dict) -> dict:
    return {
        "name": s.get("name"),
        "actions": [_format_action(a) for a in s.get("actions", [])],
    }


def cmd_usage(ctx: Context, args: argparse.Namespace) -> None:
    """Show resource usage (resource_class, parallelism, build/step durations)."""
    resolve_context(ctx, args)
    require_job_context(ctx, "usage")
    emit_resolved_if_any(ctx)
    response = api_v1(
        f"/project/{ctx.vcs_type}/{ctx.org}/{ctx.project}/{ctx.build_num}"
    )
    picard = response.get("picard", {})
    workflows = response.get("workflows", {})
    result = {
        "build_num": response.get("build_num"),
        "job_name": workflows.get("job_name") or response.get("job_name"),
        "status": response.get("status"),
        "parallelism": response.get("parallel"),
        "executor": picard.get("executor"),
        "resource_class": picard.get("resource_class"),
        "queued_at": response.get("usage_queued_at"),
        "started_at": response.get("start_time"),
        "stopped_at": response.get("stop_time"),
        "build_time_millis": response.get("build_time_millis"),
        "steps": [_format_step(s) for s in response.get("steps", [])],
    }
    print_json(result)


def cmd_steplog(ctx: Context, args: argparse.Namespace) -> None:
    """Save all step logs of a job into a single file and print its path.

    CircleCI API v2 has no endpoint for per-step stdout/stderr, so we use
    the legacy v1.1 endpoint to get presigned S3 output_url for each
    action, then download them sequentially.
    """
    resolve_context(ctx, args)
    require_job_context(ctx, "steplog")
    emit_resolved_if_any(ctx)

    response = api_v1(
        f"/project/{ctx.vcs_type}/{ctx.org}/{ctx.project}/{ctx.build_num}"
    )
    workflows = response.get("workflows", {})
    job_name = workflows.get("job_name") or response.get("job_name") or "job"

    out_path = make_output_path(ctx, "steplog", "log", args.output_dir, job_name)

    with open_secure(out_path) as f:
        for step in response.get("steps", []):
            step_name = step.get("name", "")
            for action in step.get("actions", []):
                f.write("========================================\n")
                f.write(
                    f"Step: {step_name}  (action[{action.get('index')}], "
                    f"status={action.get('status', '')}, "
                    f"exit_code={action.get('exit_code')}, "
                    f"duration_ms={action.get('run_time_millis')})\n"
                )
                f.write("========================================\n")
                output_url = action.get("output_url")
                if not output_url:
                    f.write("(no output for this step)\n\n")
                    continue
                try:
                    raw = fetch_public(output_url)
                    parts = json.loads(raw)
                except (urllib.error.URLError, json.JSONDecodeError) as e:
                    f.write(
                        f"(failed to fetch step output: "
                        f"{type(e).__name__}: {e})\n\n"
                    )
                    continue
                for part in parts:
                    msg = part.get("message", "")
                    if msg:
                        f.write(msg)
                f.write("\n")

    print(f"Wrote step log: {out_path}", file=sys.stderr)
    print(out_path)


def cmd_tests(ctx: Context, args: argparse.Namespace) -> None:
    """Save the full paginated test result list (raw) to a JSON file.

    The caller is expected to query the file with jq for whatever subset
    they care about (failures, by classname, etc.) — this keeps multi-MB
    responses out of the calling chat context.
    """
    resolve_context(ctx, args)
    require_job_context(ctx, "tests")
    emit_resolved_if_any(ctx)

    job_name = ctx.job_name
    if not job_name:
        meta = api_v2(f"/project/{ctx.project_slug}/job/{ctx.build_num}")
        job_name = meta.get("name") or "job"

    out_path = make_output_path(ctx, "tests", "json", args.output_dir, job_name)
    result = api_v2_paginated(
        f"/project/{ctx.project_slug}/{ctx.build_num}/tests"
    )

    with open_secure(out_path) as f:
        json.dump(result, f, ensure_ascii=False)

    print(f"Wrote tests: {out_path}", file=sys.stderr)
    print(out_path)


# ---------------------------------------------------------------
# main
# ---------------------------------------------------------------


def add_context_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("url", nargs="?", help="job URL or pipeline URL")
    p.add_argument("--branch", help="branch name (with --project / --job)")
    p.add_argument(
        "--project",
        help="project slug, e.g. gh/<org>/<project> (with --branch / --job)",
    )
    p.add_argument(
        "--job", help="job name to resolve (with --branch / --project)"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="circleci.py",
        description=(
            "CircleCI investigation toolbox. Calls CircleCI API v2 / v1.1 "
            "with the Circle-Token header read from $CIRCLECI_TOKEN."
        ),
    )
    sub = parser.add_subparsers(dest="subcommand", required=True)

    p_status = sub.add_parser("status", help="Show job metadata")
    add_context_args(p_status)
    p_status.set_defaults(func=cmd_status)

    p_jobs = sub.add_parser("jobs", help="List jobs in workflow(s)")
    add_context_args(p_jobs)
    p_jobs.set_defaults(func=cmd_jobs)

    p_artifacts = sub.add_parser(
        "artifacts", help="List artifacts produced by the job"
    )
    add_context_args(p_artifacts)
    p_artifacts.set_defaults(func=cmd_artifacts)

    p_usage = sub.add_parser(
        "usage",
        help="Show resource_class / parallelism / step durations",
    )
    add_context_args(p_usage)
    p_usage.set_defaults(func=cmd_usage)

    p_steplog = sub.add_parser(
        "steplog", help="Save raw step logs to a single file"
    )
    add_context_args(p_steplog)
    p_steplog.add_argument(
        "--output-dir", default="", help="output directory (default: $PWD)"
    )
    p_steplog.set_defaults(func=cmd_steplog)

    p_tests = sub.add_parser(
        "tests", help="Save the full test result list to a JSON file"
    )
    add_context_args(p_tests)
    p_tests.add_argument(
        "--output-dir", default="", help="output directory (default: $PWD)"
    )
    p_tests.set_defaults(func=cmd_tests)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    ctx = Context()
    args.func(ctx, args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)

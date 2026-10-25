"""Bounded source observations. No tokens, network calls, or CI admission policy."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


class IdentityError(Exception):
    """No raw input or Git diagnostics belong in an identity error."""


def require(condition):
    if not condition:
        raise IdentityError("inconsistent or malformed source identity")


def sha(value):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None)
    return value


def positive_id(value):
    require(type(value) in (str, int))
    text = str(value)
    require(re.fullmatch(r"[1-9][0-9]{0,19}", text) is not None)
    return text


def repository(value):
    require(isinstance(value, dict))
    name = value.get("full_name")
    require(isinstance(name, str)
            and re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", name) is not None
            and len(name) <= 201)
    return {"name": name, "id": positive_id(value.get("id"))}


def git(workspace, *arguments):
    # Read-only Git operations, no shell. Ref arguments start with literal refs/.
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith("GIT_")}
    environment["GIT_CONFIG_NOSYSTEM"] = "1"
    environment["GIT_CONFIG_GLOBAL"] = os.devnull
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    with tempfile.TemporaryFile() as output:
        result = subprocess.run(["git", "--no-optional-locks", "-c",
                                 "safe.directory=" + str(workspace.resolve()),
                                 "-C", str(workspace), *arguments],
                                env=environment, stdin=subprocess.DEVNULL, stdout=output,
                                stderr=subprocess.DEVNULL, timeout=15, check=False)
        output.seek(0)
        content = output.read(2 * 1024 * 1024 + 1)
    require(result.returncode == 0 and len(content) <= 2 * 1024 * 1024)
    return content


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result)
        result[key] = value
    return result


def read_event(path):
    with open(path, "rb") as stream:
        content = stream.read(2 * 1024 * 1024 + 1)
    require(len(content) <= 2 * 1024 * 1024)
    event = json.loads(content, object_pairs_hook=unique_object)
    require(isinstance(event, dict))
    return event


def observe(environment, provenance):
    def context(name):
        value = environment.get("SOURCE_RECEIPT_" + name)
        require(isinstance(value, str) and 0 < len(value) <= 4096)
        return value

    target = repository({"full_name": context("REPOSITORY"),
                         "id": context("REPOSITORY_ID")})
    workflow_ref = context("WORKFLOW_REF")
    workflow_path, separator, workflow_revision = workflow_ref.rpartition("@")
    workflow_prefix = target["name"] + "/.github/workflows/"
    require(separator == "@" and workflow_path.startswith(workflow_prefix))
    workflow_filename = workflow_path[len(workflow_prefix):]
    require(workflow_filename not in ("", ".", "..") and "/" not in workflow_filename)
    require(workflow_revision.startswith("refs/"))
    workflow_sha = sha(context("WORKFLOW_SHA"))
    run = {"id": positive_id(context("RUN_ID")),
           "attempt": positive_id(context("RUN_ATTEMPT"))}
    event_name = context("EVENT_NAME")
    require(event_name in ("pull_request", "push", "workflow_dispatch"))
    event = read_event(context("EVENT_PATH"))
    require(repository(event.get("repository")) == target)
    checked_out = sha(context("SHA"))
    workspace = Path(context("WORKSPACE"))
    require(workspace.is_dir())
    observed_root = Path(os.fsdecode(git(workspace, "rev-parse", "--show-toplevel")).rstrip("\n"))
    require(observed_root.resolve() == workspace.resolve())
    git(workspace, "check-ref-format", workflow_revision)
    observed_head = git(workspace, "rev-parse", "--verify", "HEAD").decode("ascii").strip()
    require(sha(observed_head) == checked_out)
    ref = context("REF")
    source = {"event": event_name, "ref": ref, "checkedOutCommit": checked_out,
              "pullRequest": None, "base": None, "head": None,
              "testedMergeCommit": None}
    if event_name == "pull_request":
        pull = event.get("pull_request")
        require(isinstance(pull, dict))
        number = positive_id(event.get("number"))
        require(positive_id(pull.get("number")) == number)
        require(ref == "refs/pull/" + number + "/merge")
        event_merge = pull.get("merge_commit_sha")
        if event_merge is not None:
            require(sha(event_merge) == checked_out)
        base, head = pull.get("base"), pull.get("head")
        require(isinstance(base, dict) and isinstance(head, dict))
        base_identity = {"repository": repository(base.get("repo")),
                         "commit": sha(base.get("sha"))}
        head_identity = {"repository": repository(head.get("repo")),
                         "commit": sha(head.get("sha"))}
        require(base_identity["repository"] == target)
        # cat-file reads the commit's real parents, including in a shallow checkout.
        commit = git(workspace, "cat-file", "-p", "HEAD").decode("utf-8", errors="replace")
        headers = commit.split("\n\n", 1)[0].splitlines()
        parents = [line[7:] for line in headers if line.startswith("parent ")]
        require(parents == [base_identity["commit"], head_identity["commit"]])
        source.update(pullRequest={"number": number}, base=base_identity,
                      head=head_identity, testedMergeCommit=checked_out)
    else:
        require("pull_request" not in event)
        require(ref.startswith(("refs/heads/", "refs/tags/")))
        git(workspace, "check-ref-format", ref)
        if event_name == "push":
            require(event.get("deleted") is False)
            require(sha(event.get("after")) == checked_out and event.get("ref") == ref)
        source["head"] = {"repository": target, "commit": checked_out}
    return {"schemaVersion": 1, "repository": target,
            "workflow": {"ref": workflow_ref, "commit": workflow_sha},
            "run": run, "source": source, "component": provenance}


def record(environment, provenance):
    receipt = observe(environment, provenance)
    compact = json.dumps(receipt, separators=(",", ":"), ensure_ascii=True)
    with open(environment["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
        stream.write("receipt=" + compact + "\n")
    print(compact)

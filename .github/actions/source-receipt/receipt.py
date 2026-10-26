"""Bounded source observations. No tokens, network calls, or CI admission policy."""

from enum import Enum
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


class ValidationStage(Enum):
    """Closed diagnostic vocabulary; values never contain runner or Git data."""

    CONTEXT = "runner-context"
    WORKFLOW = "workflow-identity"
    RUN = "run-identity"
    EVENT = "event-payload"
    REPOSITORY = "target-repository"
    CHECKOUT_ROOT = "checkout-root"
    CHECKOUT_COMMIT = "checkout-commit"
    PR = "pull-request-identity"
    PR_REF = "pull-request-ref"
    PR_EVENT_MERGE = "event-merge-commit"
    PR_BASE = "pull-request-base"
    PR_HEAD = "pull-request-head"
    PR_PARENTS = "merge-parents"
    PUSH = "push-identity"
    GIT = "git-read"


class IdentityError(Exception):
    """Only a closed validation stage can cross the diagnostic boundary."""

    def __init__(self, stage):
        if not isinstance(stage, ValidationStage):
            raise TypeError("identity error requires a validation stage")
        self.stage = stage
        super().__init__(stage.value)


def require(condition, stage):
    if not condition:
        raise IdentityError(stage)


def sha(value, stage):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None, stage)
    return value


def positive_id(value, stage):
    require(type(value) in (str, int), stage)
    text = str(value)
    require(re.fullmatch(r"[1-9][0-9]{0,19}", text) is not None, stage)
    return text


def repository(value, stage):
    require(isinstance(value, dict), stage)
    name = value.get("full_name")
    require(isinstance(name, str)
            and re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", name) is not None
            and len(name) <= 201, stage)
    return {"name": name, "id": positive_id(value.get("id"), stage)}


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
    require(result.returncode == 0 and len(content) <= 2 * 1024 * 1024, ValidationStage.GIT)
    return content


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, ValidationStage.EVENT)
        result[key] = value
    return result


def read_event(path):
    with open(path, "rb") as stream:
        content = stream.read(2 * 1024 * 1024 + 1)
    require(len(content) <= 2 * 1024 * 1024, ValidationStage.EVENT)
    event = json.loads(content, object_pairs_hook=unique_object)
    require(isinstance(event, dict), ValidationStage.EVENT)
    return event


def observe(environment, provenance):
    def context(name, stage=ValidationStage.CONTEXT):
        value = environment.get("SOURCE_RECEIPT_" + name)
        require(isinstance(value, str) and 0 < len(value) <= 4096, stage)
        return value

    target = repository({"full_name": context("REPOSITORY", ValidationStage.REPOSITORY),
                         "id": context("REPOSITORY_ID", ValidationStage.REPOSITORY)},
                        ValidationStage.REPOSITORY)
    workflow_ref = context("WORKFLOW_REF", ValidationStage.WORKFLOW)
    workflow_path, separator, workflow_revision = workflow_ref.rpartition("@")
    workflow_prefix = target["name"] + "/.github/workflows/"
    require(separator == "@" and workflow_path.startswith(workflow_prefix), ValidationStage.WORKFLOW)
    workflow_filename = workflow_path[len(workflow_prefix):]
    require(workflow_filename not in ("", ".", "..") and "/" not in workflow_filename,
            ValidationStage.WORKFLOW)
    require(workflow_revision.startswith("refs/"), ValidationStage.WORKFLOW)
    workflow_sha = sha(context("WORKFLOW_SHA", ValidationStage.WORKFLOW), ValidationStage.WORKFLOW)
    run = {"id": positive_id(context("RUN_ID", ValidationStage.RUN), ValidationStage.RUN),
           "attempt": positive_id(context("RUN_ATTEMPT", ValidationStage.RUN), ValidationStage.RUN)}
    event_name = context("EVENT_NAME")
    require(event_name in ("pull_request", "push", "workflow_dispatch"), ValidationStage.EVENT)
    event = read_event(context("EVENT_PATH"))
    require(repository(event.get("repository"), ValidationStage.REPOSITORY) == target,
            ValidationStage.REPOSITORY)
    checked_out = sha(context("SHA", ValidationStage.CHECKOUT_COMMIT), ValidationStage.CHECKOUT_COMMIT)
    workspace = Path(context("WORKSPACE"))
    require(workspace.is_dir(), ValidationStage.CHECKOUT_ROOT)
    observed_root = Path(os.fsdecode(git(workspace, "rev-parse", "--show-toplevel")).rstrip("\n"))
    require(observed_root.resolve() == workspace.resolve(), ValidationStage.CHECKOUT_ROOT)
    git(workspace, "check-ref-format", workflow_revision)
    observed_head = git(workspace, "rev-parse", "--verify", "HEAD").decode("ascii").strip()
    require(sha(observed_head, ValidationStage.CHECKOUT_COMMIT) == checked_out,
            ValidationStage.CHECKOUT_COMMIT)
    ref = context("REF")
    source = {"event": event_name, "ref": ref, "checkedOutCommit": checked_out,
              "pullRequest": None, "base": None, "head": None,
              "testedMergeCommit": None}
    if event_name == "pull_request":
        pull = event.get("pull_request")
        require(isinstance(pull, dict), ValidationStage.PR)
        number = positive_id(event.get("number"), ValidationStage.PR)
        require(positive_id(pull.get("number"), ValidationStage.PR) == number, ValidationStage.PR)
        require(ref == "refs/pull/" + number + "/merge", ValidationStage.PR_REF)
        event_merge = pull.get("merge_commit_sha")
        if event_merge is not None:
            # PR merge metadata and the Actions-selected commit are separate observations.
            sha(event_merge, ValidationStage.PR_EVENT_MERGE)
        base, head = pull.get("base"), pull.get("head")
        require(isinstance(base, dict) and isinstance(head, dict), ValidationStage.PR)
        base_identity = {"repository": repository(base.get("repo"), ValidationStage.PR_BASE),
                         "commit": sha(base.get("sha"), ValidationStage.PR_BASE)}
        head_identity = {"repository": repository(head.get("repo"), ValidationStage.PR_HEAD),
                         "commit": sha(head.get("sha"), ValidationStage.PR_HEAD)}
        require(base_identity["repository"] == target, ValidationStage.PR_BASE)
        # cat-file reads the commit's real parents, including in a shallow checkout.
        commit = git(workspace, "cat-file", "-p", "HEAD").decode("utf-8", errors="replace")
        headers = commit.split("\n\n", 1)[0].splitlines()
        parents = [line[7:] for line in headers if line.startswith("parent ")]
        require(parents == [base_identity["commit"], head_identity["commit"]], ValidationStage.PR_PARENTS)
        source.update(pullRequest={"number": number}, base=base_identity,
                      head=head_identity, testedMergeCommit=checked_out)
    else:
        require("pull_request" not in event, ValidationStage.EVENT)
        require(ref.startswith(("refs/heads/", "refs/tags/")), ValidationStage.EVENT)
        git(workspace, "check-ref-format", ref)
        if event_name == "push":
            require(event.get("deleted") is False, ValidationStage.PUSH)
            require(sha(event.get("after"), ValidationStage.PUSH) == checked_out
                    and event.get("ref") == ref, ValidationStage.PUSH)
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

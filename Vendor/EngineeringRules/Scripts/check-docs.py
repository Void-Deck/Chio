#!/usr/bin/env python3
"""Read-only module/deliverable documentation and Markdown destination checks."""

import argparse
import importlib.metadata
import json
from pathlib import Path, PurePosixPath
import sys
import unicodedata
from urllib.parse import unquote, urlsplit


class CheckFailure(Exception):
    pass


def object_with_unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise CheckFailure("Duplicate JSON key: " + key)
        result[key] = value
    return result


def require_fields(value, fields, label):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise CheckFailure(label + " must contain exactly: " + ", ".join(fields))


def relative_path(value, label):
    if (not isinstance(value, str) or not value or "\\" in value
            or any(ord(character) < 32 for character in value)):
        raise CheckFailure(label + " must be a normalized repository-relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or value != path.as_posix() or any(part in (".", "..") for part in value.split("/")):
        raise CheckFailure(label + " must be a normalized repository-relative path: " + value)
    return value


def checked_path(root, relative, exact_case=False):
    path = root
    for part in PurePosixPath(relative).parts:
        if exact_case and part not in {child.name for child in path.iterdir()}:
            raise CheckFailure("Missing or case-mismatched deliverable root: " + relative)
        path = path / part
        if path.is_symlink():
            raise CheckFailure("Symlink is not supported: " + str(path.relative_to(root)))
    return path


def string_paths(value, label):
    if not isinstance(value, list):
        raise CheckFailure(label + " must be an array")
    paths = [relative_path(item, label) for item in value]
    if len(paths) != len(set(paths)):
        raise CheckFailure("Duplicate entry in " + label)
    return paths


def deliverable_roots(root, entries):
    if not isinstance(entries, list) or not entries:
        raise CheckFailure("deliverables must be a nonempty array")
    inventory = {}
    roots = set()
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) not in ({"id", "root"}, {"id", "root", "parent"}):
            raise CheckFailure("deliverables entry must contain exactly id, root, and optional parent")
        identifier = entry["id"]
        if (not isinstance(identifier, str) or not identifier.strip() or identifier != identifier.strip()
                or any(unicodedata.category(character) == "Cc" for character in identifier)):
            raise CheckFailure("Deliverable id must be a nonblank normalized string without controls")
        if identifier in inventory:
            raise CheckFailure("Duplicate deliverable id: " + identifier)
        name = entry["root"]
        if name != ".":
            relative_path(name, "Deliverable root")
        if name in roots:
            raise CheckFailure("Duplicate deliverable root: " + name)
        directory = checked_path(root, name, exact_case=True)
        if not directory.is_dir():
            raise CheckFailure("Deliverable root must be an existing directory: " + name)
        inventory[identifier] = entry
        roots.add(name)
    for identifier, entry in inventory.items():
        if "parent" not in entry:
            continue
        parent = entry["parent"]
        if not isinstance(parent, str) or parent not in inventory or parent == identifier:
            raise CheckFailure("Deliverable parent must name an existing distinct id: " + identifier)
    for identifier in inventory:
        ancestors = set()
        current = identifier
        while current is not None:
            if current in ancestors:
                raise CheckFailure("Cycle in deliverable parents: " + identifier)
            ancestors.add(current)
            current = inventory[current].get("parent")
    for identifier, entry in inventory.items():
        if "parent" in entry:
            parent_root = PurePosixPath(inventory[entry["parent"]]["root"])
            if parent_root not in PurePosixPath(entry["root"]).parents:
                raise CheckFailure("Deliverable parent root must be an ancestor of child root: " + identifier)
    return roots


def read_configuration(root, configuration_path):
    relative_path(configuration_path, "Configuration path")
    configuration_file = checked_path(root, configuration_path)
    if not configuration_file.is_file():
        raise CheckFailure("Configuration must be a regular file: " + configuration_path)
    with configuration_file.open(encoding="utf-8") as stream:
        configuration = json.load(stream, object_pairs_hook=object_with_unique_keys)
    fields = ("schemaVersion", "moduleRoots", "modules", "excludedModules", "documents")
    if not isinstance(configuration, dict):
        require_fields(configuration, fields, "Configuration")
    schema = configuration.get("schemaVersion")
    if type(schema) is not int or schema not in (1, 2):
        raise CheckFailure("Unsupported documentation configuration schema; expected 1 or 2")
    if schema == 1:
        require_fields(configuration, fields, "Configuration")
        source_roots = set()
    elif schema == 2:
        require_fields(configuration, fields + ("deliverables",), "Configuration")
        source_roots = deliverable_roots(root, configuration["deliverables"])
    roots = string_paths(configuration["moduleRoots"], "moduleRoots")
    documents = string_paths(configuration["documents"], "documents")
    for first in roots:
        for second in roots:
            if first != second and second.startswith(first + "/"):
                raise CheckFailure("Overlapping module roots: " + first + " and " + second)
    inventory = set()
    for name in roots:
        directory = checked_path(root, name)
        if not directory.is_dir():
            raise CheckFailure("Missing module root: " + name)
        for child in directory.iterdir():
            relative = child.relative_to(root).as_posix()
            if child.is_symlink():
                raise CheckFailure("Symlink in module root: " + relative)
            if child.is_dir():
                inventory.add(relative)
    mappings = {}
    excluded = set()
    for field, fields in (("modules", ("path", "document")), ("excludedModules", ("path", "reason"))):
        entries = configuration[field]
        if not isinstance(entries, list):
            raise CheckFailure(field + " must be an array")
        for entry in entries:
            require_fields(entry, fields, field + " entry")
            path = relative_path(entry["path"], field + " path")
            if path in mappings or path in excluded:
                raise CheckFailure("Duplicate or overlapping module entry: " + path)
            if path not in inventory:
                raise CheckFailure("Missing or stale module entry: " + path)
            if field == "modules":
                mappings[path] = relative_path(entry["document"], "Module document")
            else:
                reason = entry["reason"]
                if not isinstance(reason, str) or not reason.strip():
                    raise CheckFailure("Excluded module requires a reason: " + path)
                excluded.add(path)
    document_set = set(documents) | set(mappings.values())
    deliverable_documents = set()
    findings = []
    for name in sorted(source_roots):
        document = (PurePosixPath(name) / "README.md").as_posix()
        directory = root / name
        if "README.md" not in {child.name for child in directory.iterdir()}:
            findings.append({"path": document, "destination": None, "message": "Deliverable needs README.md at its source root"})
            document_set.discard(document)
            continue
        path = checked_path(root, document)
        if not path.is_file():
            raise CheckFailure("Deliverable README must be a regular file: " + document)
        if not path.read_text(encoding="utf-8").strip():
            findings.append({"path": document, "destination": None, "message": "Deliverable README.md must not be blank"})
        deliverable_documents.add(document)
    document_set |= deliverable_documents
    for document in sorted(document_set):
        if not checked_path(root, document).is_file():
            raise CheckFailure("Missing document file: " + document)
    undocumented = sorted(inventory - set(mappings) - excluded)
    findings.extend({"path": path, "destination": None, "message": "Module needs an owning document or reviewed exclusion"} for path in undocumented)
    return sorted(document_set), len(inventory), len(source_roots) if schema == 2 else None, findings


def markdown_parser():
    for distribution, expected in (("markdown-it-py", "3.0.0"), ("mdurl", "0.1.2")):
        try:
            actual = importlib.metadata.version(distribution)
        except importlib.metadata.PackageNotFoundError:
            raise CheckFailure("Missing parser dependency: " + distribution + "==" + expected)
        if actual != expected:
            raise CheckFailure("Unsupported parser dependency: " + distribution + " " + actual + "; expected " + expected)
    from markdown_it import MarkdownIt
    return MarkdownIt("commonmark").enable("table")


def destinations(tokens):
    for token in tokens:
        if token.type == "link_open":
            yield token.attrGet("href")
        elif token.type == "image":
            yield token.attrGet("src")
            # CommonMark renders image children as plain alternative text,
            # not nested navigable links or additional image resources.
            continue
        if token.children:
            yield from destinations(token.children)


def local_destination_problem(root, document, destination):
    if destination.startswith("//"):
        return None
    try:
        parsed = urlsplit(destination)
        if parsed.scheme or not parsed.path:
            return None
        path = unquote(parsed.path, encoding="utf-8", errors="strict")
    except (ValueError, UnicodeError) as error:
        return "Invalid local destination: " + str(error)
    if path.startswith("/"):
        return "Absolute/root-relative local destinations are unsupported"
    if "\\" in path or any(ord(character) < 32 for character in path):
        return "Unsupported character in local destination"
    parts = list(PurePosixPath(document).parent.parts)
    for part in path.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            if not parts:
                return "Local destination escapes the repository"
            parts.pop()
        else:
            parts.append(part)
        candidate = root.joinpath(*parts)
        if candidate.is_symlink():
            return "Symlink in local destination"
    target = root.joinpath(*parts)
    if not target.exists():
        return "Local destination does not exist"
    if not (target.is_file() or target.is_dir()):
        return "Local destination must be a file or directory"
    return None


def check(root, configuration_path):
    documents, module_count, deliverable_count, findings = read_configuration(root, configuration_path)
    parser = markdown_parser()
    for document in documents:
        text = checked_path(root, document).read_text(encoding="utf-8")
        for destination in destinations(parser.parse(text)):
            problem = local_destination_problem(root, document, destination)
            if problem:
                findings.append({"path": document, "destination": destination, "message": problem})
    return documents, module_count, deliverable_count, findings


def main():
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("--root", default=".")
    arguments.add_argument("--config", default=".documentation-rules.json", help="Repository-relative configuration path")
    arguments.add_argument("--format", choices=("text", "json"), default="text")
    options = arguments.parse_args()
    try:
        if sys.version_info < (3, 9):
            raise CheckFailure("Python 3.9 or newer is required")
        root = Path(options.root).resolve(strict=True)
        if not root.is_dir():
            raise CheckFailure("Repository root must be a directory")
        documents, modules, deliverables, findings = check(root, options.config)
    except (CheckFailure, OSError, ValueError, ImportError) as error:
        if options.format == "json":
            print(json.dumps({"findings": [], "error": str(error)}, ensure_ascii=False))
        else:
            print("documentation-rules: " + str(error), file=sys.stderr)
        return 2
    if options.format == "json":
        print(json.dumps({"findings": findings, "error": None}, ensure_ascii=False))
    else:
        for finding in findings:
            destination = " -> " + finding["destination"] if finding["destination"] is not None else ""
            print(finding["path"] + destination + ": " + finding["message"])
        summary = "Documentation rules: checked " + str(len(documents)) + " documents and " + str(modules) + " modules"
        if deliverables is not None:
            summary += " and " + str(deliverables) + " deliverables"
        print(summary + "; " + str(len(findings)) + " findings.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())

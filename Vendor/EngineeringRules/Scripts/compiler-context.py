#!/usr/bin/env python3
"""Export explicit SwiftRules compiler settings from a completed native SwiftPM build.

This does not run a build, download dependencies, or replay shell commands.
Rebuild first. Xcode projects can supply the documented context JSON directly.
"""
import argparse
import json
from pathlib import Path
import sys


def validate_scheduling_count(option, value):
    # Swift's thread count is unsigned. Reject malformed operands before
    # omitting them so a following semantic flag can never become a count.
    if not isinstance(value, str) or not value.isascii() or not value.isdecimal():
        raise ValueError(f'Invalid build scheduling count for {option}: {value!r}')
    digits = value.lstrip('0') or '0'
    if len(digits) > 10:
        raise ValueError(f'Invalid build scheduling count for {option}: {value!r}')
    count = int(digits)
    minimum = 0 if option == '-num-threads' else 1
    if not minimum <= count <= 4294967295:
        raise ValueError(f'Invalid build scheduling count for {option}: {value!r}')


def frontend_arguments(command):
    arguments = command['otherArguments']
    result = ['-I', command['importPath']]
    # These affect scheduling, diagnostics, linking, or generated outputs only.
    # Retain every other argument; the checker's allowlist rejects unsupported
    # semantic settings instead of silently dropping them.
    omitted_switches = {'-incremental', '-enable-batch-mode', '-serialize-diagnostics',
                        '-parseable-output', '-emit-objc-header', '-g', '-gline-tables-only'}
    omitted_pairs = {'-index-store-path', '-module-cache-path', '-emit-objc-header-path', '-L'}
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if argument in {'-j', '-num-threads'}:
            if index + 1 >= len(arguments):
                raise ValueError(f'Missing build argument value for {argument}')
            validate_scheduling_count(argument, arguments[index + 1])
            index += 2
        elif argument.startswith('-j'):
            validate_scheduling_count('-j', argument[2:])
            index += 1
        elif argument in omitted_switches:
            index += 1
        elif argument in omitted_pairs:
            if index + 1 >= len(arguments):
                raise ValueError(f'Missing build argument value for {argument}')
            index += 2
        elif argument == '-Xfrontend':
            if index + 1 >= len(arguments):
                raise ValueError('Missing -Xfrontend argument')
            result.append(arguments[index + 1])
            index += 2
        elif argument == '-Xcc':
            if index + 1 >= len(arguments):
                raise ValueError('Missing -Xcc argument')
            result.extend(arguments[index:index + 2])
            index += 2
        else:
            result.append(argument)
            index += 1
    return result


def export(root, description, selected):
    commands = description['swiftCommands'].values()
    modules = []
    compilers = set()
    for command in commands:
        if selected and command['moduleName'] not in selected:
            continue
        try:
            sources = [str(Path(path).resolve().relative_to(root)) for path in command['sources']]
        except ValueError:
            if selected:
                raise ValueError(f"Module {command['moduleName']} contains sources outside this repository")
            continue
        if not selected and not any(path.startswith('Sources/') for path in sources):
            continue
        for path in sources:
            if not (root / path).is_file():
                raise ValueError(f'Missing build input {path}; refresh the build description')
        compilers.add(command['executable'])
        modules.append({'name': command['moduleName'], 'configuration': command['moduleName'] + '-swiftpm',
                        'sources': sources, 'arguments': frontend_arguments(command)})
    if not modules or len(compilers) != 1:
        raise ValueError('Expected local modules using one compiler; rebuild or select explicit --module names')
    missing = set(selected) - {module['name'] for module in modules}
    if missing:
        raise ValueError('Modules absent from build description: ' + ', '.join(sorted(missing)))
    return {'schemaVersion': 1, 'compiler': compilers.pop(), 'modules': sorted(modules, key=lambda module: module['name'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--build-description', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--module', action='append', default=[])
    arguments = parser.parse_args()
    try:
        context = export(arguments.root.resolve(), json.loads(arguments.build_description.read_text()), arguments.module)
        arguments.output.write_text(json.dumps(context, indent=2) + '\n')
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'compiler-context: {error}', file=sys.stderr)
        return 2
    print(f'Wrote {len(context["modules"])} compiler configurations to {arguments.output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Read Wrangler D1 migration locations without printing configuration values."""
import json
import pathlib
import sys


def jsonc(text):
    # Strip comments and trailing commas only outside JSON strings.
    out, i, string, escape = [], 0, False, False
    while i < len(text):
        c = text[i]
        if string:
            out.append(c)
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                string = False
            i += 1
        elif c == '"':
            string = True
            out.append(c)
            i += 1
        elif text[i:i+2] == '//':
            i += 2
            while i < len(text) and text[i] not in '\r\n':
                i += 1
        elif text[i:i+2] == '/*':
            end = text.find('*/', i + 2)
            if end < 0:
                raise ValueError('unterminated comment')
            i = end + 2
        elif c == ',':
            j = i + 1
            while j < len(text):
                if text[j].isspace():
                    j += 1
                elif text[j:j+2] == '//':
                    j += 2
                    while j < len(text) and text[j] not in '\r\n':
                        j += 1
                elif text[j:j+2] == '/*':
                    end = text.find('*/', j + 2)
                    if end < 0:
                        raise ValueError('unterminated comment')
                    j = end + 2
                else:
                    break
            if j >= len(text) or text[j] not in '}]':
                out.append(c)
            i += 1
        else:
            out.append(c)
            i += 1
    return json.loads(''.join(out))


def main(root):
    root = pathlib.Path(root)
    configs = [p for p in (root/'wrangler.jsonc', root/'wrangler.json', root/'wrangler.toml') if p.is_file()]
    if len(configs) != 1:
        return 'unknown'
    p = configs[0]
    try:
        if p.suffix == '.toml':
            try:
                import tomllib
            except ImportError:
                return 'unknown'
            config = tomllib.loads(p.read_text())
        else:
            config = jsonc(p.read_text())
        if not isinstance(config, dict):
            return 'unknown'
        envs = config.get('env', {})
        if not isinstance(envs, dict) or any(not isinstance(x, dict) for x in envs.values()):
            return 'unknown'
        bindings = []
        for scope in [config, *envs.values()]:
            group = scope.get('d1_databases', [])
            if not isinstance(group, list) or any(not isinstance(db, dict) for db in group):
                return 'unknown'
            bindings.extend(group)
        if not bindings:
            return 'no-d1'
        for db in bindings:
            directory = db.get('migrations_dir', 'migrations')
            if not isinstance(directory, str):
                return 'unknown'
            path = (p.parent / directory).resolve()
            try:
                path.relative_to(root.resolve())
            except ValueError:
                return 'unknown'
            if not path.is_dir() or not any(f.is_file() for f in path.glob('*.sql')):
                return 'd1-no-migrations'
        return 'd1-migrations-found'
    except (OSError, ValueError, TypeError):
        return 'unknown'


if __name__ == '__main__':
    print(main(sys.argv[1]))

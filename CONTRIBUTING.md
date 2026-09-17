# Contributing

The first milestone is a tested, modular Classic-style interface for the actual
Forever client. The current development addon targets Classic Era 1.15.9 for
asset inspection; it does not yet replace native frames.

## Development

Use Python 3.11 or newer:

```sh
python3 -m venv tools/python-env
tools/python-env/bin/python -m pip install -r tools/requirements.txt
tools/python-env/bin/python tests/run.py
python3 tools/package_addon.py
```

Keep user-facing strings, code comments and documentation in English. Add each
feature as a module and state which client/build was tested. Preserve native
gameplay and secure interactions; do not claim combat safety from mock tests
alone. For an in-game report, include the client build, reproduction steps and
Lua error, without account or character information.

## Artwork and dependencies

Original code is MIT licensed. Blizzard artwork has separate attribution in
`NOTICE.md`. Preserve source FileDataIDs and hashes when updating the selected
art pack. Do not copy Classic Frames source or introduce third-party code
without compatible licensing and attribution.

Full local exports, installation reports, downloaded tools, caches and generated
packages belong in ignored directories. Never commit game account settings,
SavedVariables from personal play sessions or credentials.

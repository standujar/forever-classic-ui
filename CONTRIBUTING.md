# Contributing

The goal is a tested, modular Classic-style in-game interface for the actual
Forever client, with native Forever nameplates retained. Inspect that client's
build, frame hierarchies and available APIs before final adaptation. The current
development addon provides diagnostics for Classic Era 1.15.9 and a separate
Forever beta 1.60.1.69893 package; it does not yet replace native frames. Beta
source inspection is recorded in [the validation log](docs/validation-forever.md),
but in-game beta behavior remains unvalidated.

Unit frames, windows, world and flight maps, action bars, minimap and the remaining
HUD are in scope. Nameplates are the only excluded in-game UI family. Follow the
[restoration checklist](docs/ui-coverage.md); a resource's presence in the reference
pack or diagnostic report does not establish restoration progress.

## Development

Use Python 3.11 or newer:

```sh
python3 -m venv tools/python-env
tools/python-env/bin/python -m pip install -r tools/requirements.txt
tools/python-env/bin/python tests/run.py
python3 tools/package_addon.py
```

The default package target is `era`. Use
`python3 tools/package_addon.py --target forever-beta` for the beta archive.
Its candidate Interface `16001` is inferred from the client version and must be
confirmed in game. Follow the [beta installation and test steps](README.md#forever-beta)
and preserve historical Era test results as evidence for their original version.

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

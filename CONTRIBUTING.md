# Contributing

Pull requests run automated checks and produce test archives. To publish an
update after merging into `main`, follow the [release guide](docs/releasing.md):
bump both version declarations and add matching English release notes.

The goal is a tested, modular Classic-style in-game interface for the actual
Forever client, with native Forever nameplates retained. Inspect that client's
build, frame hierarchies and available APIs before final adaptation. The current
development addon provides diagnostics for Classic Era 1.15.9 and a separate
Forever beta 1.60.1.69893 package. Version `0.2.3-dev` attaches Classic UI options
directly to native Edit Mode and retains three optional window-border modules;
no complete Classic window, unit frame or HUD replacement is implemented.
Beta source inspection and pending
runtime checks are recorded in [the validation log](docs/validation-forever.md).

The options section belongs to the native Edit Mode manager and follows its
visibility and movement. Do not introduce a separate Settings category for these
controls. Addon choices persist immediately and are shared across layouts; native
Edit Mode Save/Revert does not undo them. Keep that distinction visible beside
the controls and cover it when validating the integration.

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
tools/python-env/bin/python -m unittest discover -s tests -p 'test_*.py'
python3 tools/package_addon.py
```

The default package target is `era`. Use
`python3 tools/package_addon.py --target forever-beta` for the beta archive.
Its candidate Interface `16001` is inferred from the client version and must be
confirmed in game. Follow the [beta installation and test steps](README.md#forever-beta)
and preserve historical Era test results as evidence for their original version.
Packaging includes the required dialog-border texture from `RequiredMedia.txt`;
copying only the Lua source directory is not a complete installation.

Keep user-facing strings, code comments and documentation in English. Add each
feature as a module and state which client/build was tested. Preserve native
gameplay and secure interactions; do not claim combat safety from mock tests
alone. For an in-game report, include the client build, reproduction steps and
Lua error, without account or character information.

Restoration descriptors must provide a support check, apply and revert methods;
see [the addon extension points](addon/ForeverReframed/README.md#extension-points).
Keep new modules disabled by default and preserve the user's native presentation
when they are disabled. The initial border modules require exact version
`1.60.1`, build `69893`, candidate Interface `16001` and the inspected frame
structure. They reject protected or forbidden frames, defer changes in combat
and restore captured border alphas when switched off. Expand support only with
new client evidence and tests; offline tests do not establish in-game safety.

## Artwork and dependencies

Original code is MIT licensed. Blizzard artwork has separate attribution in
`NOTICE.md`. Preserve source FileDataIDs and hashes when updating the selected
art pack. Do not copy Classic Frames source or introduce third-party code
without compatible licensing and attribution.

Full local exports, installation reports, downloaded tools, caches and generated
packages belong in ignored directories. Never commit game account settings,
SavedVariables from personal play sessions or credentials.

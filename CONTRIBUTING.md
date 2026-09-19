# Contributing

The goal is a modular Classic-style in-game interface for Forever, with native
Forever nameplates retained. Keep user-facing text, comments and documentation
in English. Describe implemented behavior separately from the restoration goal.

## Current development target

Version **0.3.0-dev** groups Classic UI choices in native Edit Mode and provides
sixteen partial side-and-bottom window skins. It supports Forever beta **1.60.1**
builds **69893** and **69913**, with Interface **16001** confirmed by the user's
69913 logs. Full Classic windows, unit frames and HUD are still future work.

Consult the [current validation record](docs/validation-forever-69913.md) and
[restoration checklist](docs/ui-coverage.md) before adding a module. Check the
active client manifests, frame hierarchy and runtime behavior; finding a familiar
texture or global does not establish compatibility.

## Development

Python 3.11 or newer:

```sh
python3 -m venv tools/python-env
tools/python-env/bin/python -m pip install -r tools/requirements.txt
tools/python-env/bin/python tests/run.py
tools/python-env/bin/python -m unittest discover -s tests -p 'test_*.py'
python3 tools/package_addon.py --target forever-beta
```

The default package target is `era`; the source TOC remains Interface `11509` for
Era diagnostics and previews. The beta archive uses Interface `16001` and includes
the required dialog-border texture. Install the archive rather than copying only
Lua sources. Follow the [installation steps](README.md#install-the-development-build).

PRs run automated checks and produce test archives. To publish a new version
through `main`, update both version declarations and add matching English release
notes as described in the [release guide](docs/releasing.md). Distribution uses
CurseForge's Release channel even while the implementation is experimental.

## Adding restoration modules

Use a descriptor with a support check and reversible apply/revert methods;
see the [extension points](addon/ForeverReframed/README.md#extension-points).
Choose `unit_frames`, `windows`, `maps` or `hud` as its group. Nameplates have no
restoration group and must retain their native appearance and behavior.

Fresh settings default to off. Existing explicit module choices take precedence
over group defaults. Future modules inherit their group's saved choice; do not
force them off or on during an upgrade. Group selection clears exceptions in
that group; Restore Forever clears all choices. Cover inheritance and migration
when changing the settings model.

The options belong to native Edit Mode and follow its movement and visibility.
Keep groups compact and put individual exceptions behind Customize. Do not
introduce a separate Settings category. Choices apply immediately across layouts;
native Save/Revert must not undo them. Unimplemented groups remain visibly marked
Coming soon with disabled controls.

Preserve native gameplay and secure interactions. The current skins reject
protected or forbidden frames, defer changes in combat and restore captured
border alphas when disabled. Expand client or frame support only with source
evidence and appropriate tests. Passing mock tests does not prove combat safety,
correct rendering or compatibility in game.

For an in-game report, include the client build, addon version, reproduction
steps and Lua error. Keep account and character information out of reports.
Record each tested build and preserve historical results with their original
version and date.

## Documentation and artwork

Project docs are Markdown in `README.md`, `addon/ForeverReframed/README.md` and
`docs/`. Update setup, public extension points and behavior changes as needed;
do not describe pending work as finished or an upload as moderator approval.

Original code is MIT-licensed. Blizzard artwork has separate attribution in
`NOTICE.md`. Preserve FileDataIDs and hashes when updating the selected art
pack. Do not copy Classic Frames code or add third-party source without a
compatible license and attribution.

Full exports, downloaded tools, caches, installation reports and generated
packages belong in ignored directories. Never commit personal SavedVariables,
game account settings or credentials.

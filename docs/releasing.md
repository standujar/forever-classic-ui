# CI and CurseForge releases

Every pull request and push runs the addon tests, release-tool tests, artwork
checks and package builds. Download the ZIP files from the workflow's
`addon-builds-…` artifact to test a proposed change. PR builds never upload to
CurseForge and the checks job does not receive the CurseForge token.

After a PR is merged into `main`, a change to the addon version triggers an
automatic upload **only after all checks pass**. Direct pushes to `main` follow
the same rule. Documentation-only or same-version pushes do not publish.
Uploads always use the **Release** channel, including versions ending in `-dev`.

The `CF_API_TOKEN` repository secret was configured on September 17, 2026.
An end-to-end upload through this workflow has not yet been tested. The initial
`0.2.2-dev` file was submitted manually and remains under review with the project;
it must not be uploaded again to test the automation.

## One-time setup

1. Create a dedicated upload token in the author's
   [CurseForge API token settings](https://www.curseforge.com/account/api-tokens).
2. In this repository's [Actions secrets](https://github.com/standujar/forever-classic-ui/settings/secrets/actions),
   add a repository secret named **`CF_API_TOKEN`** containing that token.

Keep the token in the secret store; do not commit it, paste it in an issue or put
it in a workflow file. A missing token fails the publish job with an explicit
setup message. The workflow itself needs only read access to repository contents.

## Prepare a release PR

1. Choose a new version that has not already been uploaded to CurseForge.
2. Set the same version in `addon/ForeverReframed/ForeverReframed.toc`
   (`## Version`) and `addon/ForeverReframed/Core.lua` (`Addon.version`).
3. Add English release notes at `docs/releases/<version>.md`. Describe the
   implemented changes and remaining runtime limitations accurately.
4. Open the PR, review its checks and downloadable package, then merge to `main`.

The publish job downloads the exact archive produced by the checks job and
verifies its manifest, SHA-256 hash, TOC, version and target before uploading.
It sends the normal `ForeverReframed-<version>-forever-beta.zip`, without the
optional preview artwork, to CurseForge project **1699904** for game **1.60.1**.
The current exact-build restriction is still `1.60.1.69893`; changing supported
clients requires updating and validating the addon and publishing checks together.

The Actions summary and `curseforge-receipt-…` artifact record the returned file
ID. Successful upload means submission to CurseForge; moderation still decides
when the file becomes public. This workflow does not bypass the initial project
review or subsequent file reviews.

## Manual runs and failures

The workflow's **Run workflow** button defaults to checks and builds only.
To submit the current version manually, select branch `main` and enable
**Publish the current main version**. Use this only after checking the
[CurseForge file dashboard](https://authors.curseforge.com/#/projects/1699904/files)
to confirm that the version has not already arrived. This is useful after adding
a missing token or resolving an upload failure. Do not use it for `0.2.2-dev`,
which was already submitted manually.

Uploads are not retried automatically. A connection failure can occur after
CurseForge has accepted a file. The uploader also refuses GitHub's **Re-run jobs**
attempts to avoid accidentally submitting the same file twice. Inspect CurseForge
first; if no file was created, start a fresh manual workflow run. Per-project
concurrency prevents simultaneous upload jobs.

## Local checks

```sh
tools/python-env/bin/python tests/run.py
tools/python-env/bin/python -m unittest discover -s tests -p 'test_*.py'
tools/python-env/bin/python tools/package_addon.py --target forever-beta
tools/python-env/bin/python tools/curseforge_release.py prepare
```

`prepare` writes `dist/curseforge-metadata.json` without network access or a token.
Inspect that file and the matching ZIP before submitting a release.

References: [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321)
and [GitHub Actions events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).

# Scratch-build packages in Koji

This pipeline can scratch-build packages in a side-tag.
Packages that has build-time dependency on some other component can be scratch-rebuilt in a side-tag to make sure that the updated dependency won't make them [FTBFS](https://docs.fedoraproject.org/en-US/fesco/Fails_to_build_from_source_Fails_to_install/) (compilation errors, test errors, ...).

## How to enable this test for your package

Currently the only way how to enable this test for your package is to specify the list of packages that should be rebuilt in your `gating.yaml` file (i.e. to enable gating on this test).

Here's how to do it:

```yaml
rules:
- !PassingTestCaseRule {test_case_name: fedora-ci.koji-build.scratch-build.validation, scenario: dependent-package1}
- !PassingTestCaseRule {test_case_name: fedora-ci.koji-build.scratch-build.validation, scenario: dependent-package2}
```

**NOTE**
If you're already familiar with `gating.yaml` syntax, then the only new thing here might be the 
`scenario: dependent-package1` part. This is how the test determines which package to scratch-rebuild.

## Limitations

There are many:

* resultsdb-listener
  * following changes need to be deployed to production:
    * https://pagure.io/ci-resultsdb-listener/pull-request/22
* Bodhi doesn't understand custom scenarios
  * this includes web UI and CLI (waiving)
* gating-only test
  * there is no package-specific config file for CI
  * the test will be triggered only for packages which decided to gate on it

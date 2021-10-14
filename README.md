# Scratch-rebuild packages in Koji

This pipeline can scratch-rebuild packages in a side-tag.
Packages that has build-time dependency on some other packages can be scratch-rebuilt in a side-tag to make sure that the updated dependency won't make them [FTBFS](https://docs.fedoraproject.org/en-US/fesco/Fails_to_build_from_source_Fails_to_install/) (compilation errors, test errors, ...).

## How to enable this test for your packages

Currently the only way how to enable this test for your package is to specify the list of packages that you want to rebuild in your `gating.yaml` file (i.e. to enable gating on this test).

Here's how to do it:

```yaml
rules:
- !PassingTestCaseRule {test_case_name: fedora-ci.koji-build.scratch-build.validation, scenario: rebuild/dependent-package1}
- !PassingTestCaseRule {test_case_name: fedora-ci.koji-build.scratch-build.validation, scenario: rebuild/dependent-package2}
```

**NOTE**
If you're already familiar with `gating.yaml` syntax, then the only new thing here might be the 
`scenario: rebuild/dependent-package1` part. This is how the test determines which package to scratch-rebuild.

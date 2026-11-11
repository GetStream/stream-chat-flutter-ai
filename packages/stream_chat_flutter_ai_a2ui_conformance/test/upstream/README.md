# A2UI conformance suites (vendored)

Copied unchanged from [a2ui-project/a2ui](https://github.com/a2ui-project/a2ui) at
`b3ac4298344c6131bc8a64157357f7609fd826e7`, under the Apache License 2.0 in [`LICENSE`](LICENSE):

- `conformance/core/*.yaml` — every core suite, including the ones this package doesn't run;
- `conformance/conformance_schema.json` — the schema of the suites;
- `catalogs/basic/v1/catalog.json` and the `conformance/test_data/catalogs/` files the run suites name.

Paths are kept as they are upstream, so the paths the cases name resolve here unchanged. To update, copy the same
files from a newer commit, record its SHA here, and run `flutter test --tags conformance`.

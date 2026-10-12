# Project conventions

## Commits

All commits use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>): <short imperative summary>

<optional body>
```

* Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`, `test`, `style`, `perf`, `build`.
* Scopes match the module layout: `network`, `iam`, `node-group`, `cluster`, `addons`, `examples`.
* Mark breaking changes to module inputs/outputs with `!` (e.g. `feat(iam)!: ...`) and a
  `BREAKING CHANGE:` footer.

## Formatting and tests

* Run `terraform fmt -recursive` before committing.
* `modules/addons` has unit tests with a mocked helm provider:
  `terraform -chdir=modules/addons init && terraform -chdir=modules/addons test`.

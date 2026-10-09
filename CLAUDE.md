# Project conventions

## Commits

All commits use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>): <short imperative summary>

<optional body>
```

* Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`, `test`, `style`, `perf`, `build`.
* Scopes match the module layout: `network`, `iam`, `node-group`, `cluster`, `examples`.
* Mark breaking changes to module inputs/outputs with `!` (e.g. `feat(iam)!: ...`) and a
  `BREAKING CHANGE:` footer.

## Formatting

Run `terraform fmt -recursive` before committing.

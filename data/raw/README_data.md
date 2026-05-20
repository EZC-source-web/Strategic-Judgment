# Raw Data

Place user-supplied raw data files here. Do not commit raw data to git.

Suggested future layout:

```text
data/raw/spf/        Philadelphia Fed SPF density forecast files
data/raw/boe/        Bank of England fan chart inputs
data/raw/norges/     Norges Bank fan chart inputs
```

Pipeline scripts should read from this folder through paths defined in
`config/default_config.m` and write generated artifacts only to `out/`.

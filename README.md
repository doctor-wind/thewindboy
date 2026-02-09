# larkchan.github.io

This repo uses a branch split for Hugo:

- `source` branch: Hugo source files
- `main` branch: published site output

## Local development

1. `hugo server`

## Deploy

Push to `source`. GitHub Actions builds the site and overwrites `main` with the generated `public/` output.

## One-time GitHub settings

1. Set the default branch to `source` in GitHub repo settings.
2. Set GitHub Pages to deploy from the `main` branch root.

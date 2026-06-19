# Develop how-to

## After release:

```bash

git submodule update --remote
git add services/*
git commit -m "update submodules after release"
git push -u github main
```
 Or use 'origin' instead of 'github' in case of ouside development


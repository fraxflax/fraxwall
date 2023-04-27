# Development Branch

Make development in the development branch and create pull requests to merge changes into main.
**Observe**, that this branch should not have any rules, apart from the _rules-examples/_.

```shell
git branch development

git checkout development

# do your stuff and testing

git commit ...

git push --set-upstream origin development

# Create Pull Request:
# https://github.com/fraxflax/fraxwall/compare/main...development?expand=1
```

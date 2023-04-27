# fraxwall

Make development in branches and create pull requests for additions to main.

Name your development-branch: `dev-username-title` <br>
where `username` is your username ( dah ... :-) and <br>
`title` is a title (micro description) of your change.

**Observe**, that you should not add "production rules" to this repository!

```shell
git branch dev-username-title

git checkout dev-username-title

# Now, do your monkey stuff and make sure you test it thoughrouly. If
# you have additions you should do a dry run firstly to check that you
# don't have local stuff that shouldn't be added:
#     git add --dry-run --all
# and if so, add your files manually or clean up before you do:
#     git add --all

git commit [ --dry-run ] --all --message='good description of your changes'

git push --set-upstream origin dev-username-title
```

Create the Pull Request: <br>
https://github.com/fraxflax/fraxwall/compare/main...dev-username-title?expand=1

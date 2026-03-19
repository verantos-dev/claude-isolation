# claude-isolation
Setup process for running claude in an isolated environment

# Build the docker image
If you are using limactl and have set it up with multi arch support you can run
```
docker build -t claude:local --platform linux/amd64 .
```

However, if you don't have that you should be able to run (I haven't personally tested this one)
```
docker build -t claude:local .
```

# Run the container
The default setup will clone a git repository and then checkout the main branch.
You can specify which repo and branch as well as providing credentials by setting
the following environment variables
<ul>
<li> GH_REPO: The git repository to clone. Defaults to github.com/verantos-dev/verantos-evidence-platform.
<li> GH_BRANCH: The branch to checkout. Defaults to main.
<li> GH_PAT: Credentials needed to clone the repository.
</ul>

Then run the container with
```
docker run --rm -it --platform linux/amd64 -e GH_PAT=${GH_PAT} -e GH_BRANCH=${GH_BRANCH} -e GH_REPO=${GH_REPO} claude:local
```
Similarly, the `--platform linux/amd64` flag can be removed if you aren't using the necessary limactl setup.

## Container startup script
When the container starts it runs the commands in the `startup_script.sh` file. You can
customize this file for your needs then rebuild the container.

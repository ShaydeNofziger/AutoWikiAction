# AutoWikiAction

AutoWikiAction provides a GitHub workflow and PowerShell script that automatically
publishes a wiki entry summarizing any pull request once it is merged. The script
retrieves details about the merged PR, generates a short description using the OpenAI API,
and commits a markdown file to your repository's wiki.

The workflow `.github/workflows/update-wiki.yml` demonstrates how to run the script
when a pull request targeting the `main` branch is closed and merged. The generated
markdown file is named `PR-<number>.md` and is pushed directly to the wiki repository.
If the pull request title contains `[skip wiki]` the step is skipped.

## Using in another repository

1. Copy `scripts/update-wiki-from-pr.ps1` into a `scripts/` directory of your repo.
2. Add the workflow file from `.github/workflows/update-wiki.yml` to the same
   location in your repository. Adjust branch filters or job settings as needed.
3. In repository settings, create a secret named `OPENAI_APIKEY` containing your
   OpenAI API key. The built-in `GITHUB_TOKEN` secret is used for wiki pushes.
4. Commit these files to your repository's default branch.
5. On each pull request merge, the workflow will run and create a new wiki page
   summarizing the changes.

This project is intended as a simple starting point. Feel free to modify the script
or workflow to suit your automation needs.

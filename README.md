# stagit

My fork of [stagit](https://codemadness.org/git/stagit/), plus the scripts
that use it to publish <https://git.michaelneuper.com>, a static, read-only
mirror of my public GitHub repos. The upstream README is in `README`.

## Changes from upstream

- Each repo opens on its README (`index.html`), with markdown rendered by
  [md4c](https://github.com/mity/md4c). `README.md` is preferred over
  `README`, which is shown as plain text. Repos without either open on the
  log.
- stagit-index links to each repo's front page instead of its log.
- The menu reads README | Files | Log | Refs.
- Files are browsed by directory: `files.html` lists the top level, each
  directory gets a page at `tree/<path>.html`, and file and directory pages
  start with a linked path.
- cgit-flavoured `style.css`, and my own logo and favicon.
- The Makefile also finds libraries installed by Homebrew.

To see only the code changes: `git diff 1.3 -- '*.c' Makefile`.

## Building the site

Needs libgit2, md4c and the GitHub CLI (`brew install libgit2 md4c gh`).

    ./build.sh
    python3 -m http.server -d public

`build.sh` builds stagit with `make`, lists every public, non-fork,
non-empty repo of the account `gh` is logged in to, fetches it into
`work/repos`, and writes the site to `public`. Repos named in `exclude` are
skipped. Environment variables:

- `GITHUB_USER`: account to mirror instead of the logged-in one.
- `SITE_URL`: public URL with trailing slash, used to make the Atom feed
  links absolute.
- `SERVE_GIT=1`: also publish the bare repos, so that
  `git clone https://git.michaelneuper.com/<repo>.git` works over git's dumb
  HTTP protocol. It's off in the workflow because the website repo's
  packfile is over 100 MB, and Netlify doesn't handle files that large well.

To try a change on a single repo without a full build:

    make
    mkdir -p /tmp/out && cd /tmp/out
    ~/Developer/stagit/stagit ~/Developer/stagit/work/repos/cube.git

## Deploying

`.github/workflows/mirror.yml` builds the site and deploys it to Netlify on
every push to `main`, every 6 hours, and on demand. One-time setup:

1. Create an empty Netlify project and note the project ID it prints:

       npx netlify-cli login
       npx netlify-cli sites:create --name <name> --disable-linking

2. In the Netlify UI, open the project's domain management and add
   `git.michaelneuper.com`. michaelneuper.com is on Netlify DNS, so the
   record and HTTPS certificate are set up automatically.
3. Create a personal access token under User settings → Applications.
4. Push this repo to GitHub and add both as secrets:

       gh secret set NETLIFY_AUTH_TOKEN
       gh secret set NETLIFY_SITE_ID

5. Run the workflow from the Actions tab, or push to `main`.

GitHub disables scheduled workflows in public repos after 60 days without
activity in the repo. That doesn't apply if the repo is private.

## Updating from upstream

Upstream is only reachable over the git protocol:

    git remote add upstream git://git.codemadness.org/stagit
    git fetch upstream --tags
    git merge <new tag>

Merge rather than rebase, so `main` never needs a force push. Conflicts in
`style.css`, `logo.png` and `favicon.png` resolve to ours.

## Notes

- Every run regenerates the site from scratch. stagit never rewrites an
  existing commit page, so incremental output would go stale after a force
  push or a description change. Netlify only uploads files whose contents
  changed, so redeploys stay small.
- Relative image links in READMEs don't work, because stagit only publishes
  HTML views of files, not the files themselves.

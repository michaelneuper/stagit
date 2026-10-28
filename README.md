# stagit

My fork of [stagit](https://codemadness.org/git/stagit/), plus the scripts
that use it to publish <https://git.michaelneuper.com>, a static, read-only
mirror of my public GitHub repos. The upstream README is in `README`.

## Changes from upstream

- Each repo opens on its README (`index.html`). `README.md` is rendered by
  [md4c](https://github.com/mity/md4c) and `README.org` by
  [pandoc](https://pandoc.org); a plain `README`, or a `README.org` when
  pandoc isn't installed, is shown as plain text. They're looked for in that
  order, and repos without one open on the log.
- Relative links and images in a README resolve from the repo root, like on
  GitHub. Links to text files go to their file page and links to directories
  to their listing. Images and other binary files are copied to
  `raw/<path>` and linked there.
- stagit-index links to each repo's front page instead of its log.
- The menu reads README | Files | Log | Refs.
- Files are browsed by directory: `files.html` lists the top level, each
  directory gets a page at `tree/<path>.html`, and file and directory pages
  start with a linked path.
- cgit-flavoured `style.css`, and my own logo and favicon.
- The Makefile also finds libraries installed by Homebrew.

The fork is based on stagit 1.3, and upstream releases are merged in rather
than rebased onto. To see only the code changes:
`git diff 1.3 -- '*.c' Makefile`. Upstream is only reachable over the git
protocol, at `git://git.codemadness.org/stagit`.

## Building the site

Needs libgit2, md4c, pandoc, chroma and the GitHub CLI
(`brew install libgit2 md4c pandoc chroma gh`). Without chroma, file pages
aren't syntax highlighted.

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
  `git clone <SITE_URL><repo>.git` works over git's dumb HTTP protocol, and
  use that as the clone URL on the repo pages. Each repo is first repacked
  into packs of at most 20 MiB, because Cloudflare doesn't serve files over
  25 MiB. A single file over 25 MiB can't be split, so a repo with one
  fails the deploy. The workflow sets it.

stagit writes into the current directory, so to render a single repo
without a full build:

    make
    mkdir -p /tmp/out && cd /tmp/out
    path/to/stagit/stagit path/to/stagit/work/repos/<repo>.git

## Deploying

`.github/workflows/mirror.yml` rebuilds the site on every push to `main`,
every 6 hours, and on demand, then deploys `public` to Cloudflare as a
Worker with static assets, configured in `wrangler.jsonc`. Every run
regenerates the site from scratch: stagit never rewrites an existing commit
page, so incremental output would go stale after a force push or a
description change. wrangler only uploads files whose contents changed, so
redeploys stay small.

The workflow mirrors the repos of whoever owns the GitHub repo it runs in.
To deploy your own copy:

1. Put your hostname in `wrangler.jsonc` and `SITE_URL` in the workflow,
   and list any repos to skip in `exclude`. The domain must be a Cloudflare
   zone without DNS records for that hostname: the deploy creates its own
   record and HTTPS certificate, but fails if another record is in the way.
2. Create a Cloudflare API token from the "Edit Cloudflare Workers"
   template, and add it and your account ID as repository secrets:

       gh secret set CLOUDFLARE_API_TOKEN
       gh secret set CLOUDFLARE_ACCOUNT_ID

3. Push to `main`, or run the workflow from the Actions tab.

GitHub disables scheduled workflows in public repos after 60 days without
activity in the repo.

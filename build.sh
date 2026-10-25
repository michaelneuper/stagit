#!/bin/sh
# Mirror public GitHub repos and render them as static HTML with stagit.
#
# Environment:
#   GITHUB_USER  account to mirror (default: the account gh is logged in as)
#   SITE_URL     public URL of the site, with trailing slash; makes the links
#                in the Atom feeds absolute (optional)
#   SERVE_GIT    set to 1 to also publish the bare repos, so that
#                `git clone ${SITE_URL}<name>.git` works over dumb HTTP
#
# Builds stagit if needed, fetches repos into ./work/repos and writes the
# site to ./public.
set -eu

root=$(cd "$(dirname "$0")" && pwd)
work=$root/work
out=$root/public

user=${GITHUB_USER:-$(gh api user --jq .login)}
site_url=${SITE_URL:-}
serve_git=${SERVE_GIT:-0}

copyassets() {
	cp "$root/style.css" "$root/logo.png" "$root/favicon.png" "$1"
}

(cd "$root" && make >/dev/null)

mkdir -p "$work/repos"
rm -rf "$out"
mkdir -p "$out"
copyassets "$out"
# Served by Netlify for any missing page, so its links are absolute.
cp "$root/404.html" "$out/"

# One line per non-empty, public, non-fork repo: name, default branch,
# primary language and description, separated by the ASCII unit separator
# (read would merge the empty fields between two tabs).
gh repo list "$user" --visibility public --source --limit 1000 \
	--json name,defaultBranchRef,primaryLanguage,description,isEmpty \
	--jq '.[] | select(.isEmpty | not)
		| [.name, .defaultBranchRef.name, (.primaryLanguage.name // ""),
		   (.description // "" | gsub("\\s+"; " "))]
		| join("\u001f")' > "$work/repos.lst"

us=$(printf '\037')
: > "$work/index.lst"
while IFS=$us read -r name branch lang desc <&3; do
	if grep -qxF "$name" "$root/exclude" 2>/dev/null; then
		continue
	fi
	echo "$name"
	repo=$work/repos/$name.git

	# Track only branches and tags; a --mirror clone would also pull in
	# GitHub's refs/pull/*.
	if [ ! -d "$repo" ]; then
		git init -q --bare "$repo"
		git -C "$repo" remote add origin "https://github.com/$user/$name.git"
		git -C "$repo" config remote.origin.fetch '+refs/heads/*:refs/heads/*'
		git -C "$repo" config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'
	fi
	git -C "$repo" fetch -q --prune origin
	git -C "$repo" symbolic-ref HEAD "refs/heads/$branch"

	# Metadata read by stagit and stagit-index. No trailing newline, or it
	# ends up inside <title>.
	printf '%s' "$desc" > "$repo/description"
	printf '%s' "$user" > "$repo/owner"
	printf '%s' "$lang" > "$repo/language"
	if [ "$serve_git" = 1 ]; then
		printf '%s' "$site_url$name.git" > "$repo/url"
	else
		printf '%s' "https://github.com/$user/$name.git" > "$repo/url"
	fi

	# Pages are regenerated from scratch every run: stagit never rewrites an
	# existing commit page, so incremental output goes stale on force pushes
	# or description changes.
	mkdir -p "$out/$name"
	(
		cd "$out/$name"
		"$root/stagit" ${site_url:+-u "$site_url$name/"} "$repo"
		# stagit writes index.html from the README; without one, open
		# on the log.
		[ -f index.html ] || cp log.html index.html
		copyassets .
	)

	if [ "$serve_git" = 1 ]; then
		git -C "$repo" update-server-info
		cp -R "$repo" "$out/$name.git"
	fi

	echo "$(git -C "$repo" log -1 --format=%ct) $repo" >> "$work/index.lst"
done 3< "$work/repos.lst"

# Index page, most recently committed to first.
sort -rn -o "$work/index.lst" "$work/index.lst"
set --
while read -r _ repo; do
	set -- "$@" "$repo"
done < "$work/index.lst"
"$root/stagit-index" \
	-s "Read-only mirror of my public repositories on <a href=\"https://github.com/$user\">GitHub</a>." \
	"$@" > "$out/index.html"

# CI Watcher

Poll GitHub check-runs for the latest commit until all checks have a conclusion (up to 20
minutes). Fetches failure logs automatically.

Determine the repo owner/name from the git remote:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)
REMOTE_URL=$(git -C "$REPO_ROOT" remote get-url origin)
REPO=$(echo "$REMOTE_URL" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
MAX=40; i=0
while [ $i -lt $MAX ]; do
  api_err=$(mktemp)
  result=$(GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" gh api \
    repos/$REPO/commits/$SHA/check-runs \
    --jq '.check_runs[] | {name,status,conclusion}' 2>"$api_err")
  if [ -s "$api_err" ]; then
    echo "API error (fatal):"; cat "$api_err"; rm -f "$api_err"; exit 1
  fi
  rm -f "$api_err"
  if [ -n "$result" ]; then
    pending=$(echo "$result" | jq -r 'select(.conclusion == null) | .name' 2>/dev/null)
    if [ -z "$pending" ]; then
      failed=$(echo "$result" | jq -r 'select(.conclusion == "failure") | .name' 2>/dev/null)
      if [ -n "$failed" ]; then
        echo "CI FAILED — failed checks:"; echo "$failed"
        GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" gh run list \
          --repo "$REPO" --commit "$SHA" \
          --json databaseId,conclusion \
          --jq '.[] | select(.conclusion == "failure") | .databaseId' 2>/dev/null \
          | while read run_id; do
              GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" gh run view "$run_id" \
                --repo "$REPO" --log-failed 2>&1 | tail -60
            done
        exit 1
      fi
      echo "All checks passed:"; echo "$result"; exit 0
    fi
  fi
  i=$((i+1)); sleep 30
done
echo "CI watcher timed out after 20 minutes"; exit 1
```

- Polls every 30 seconds, up to 40 times (20-minute hard limit).
- On failure: prints failed check names then fetches and tails the workflow run logs.
- Exits non-zero on failure or timeout.

Note: use `$GITHUB_PERSONAL_ACCESS_TOKEN`, NOT `$GITHUB_TOKEN`.

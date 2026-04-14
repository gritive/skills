#!/bin/bash
# scripts/push.sh - bump plugin version and push
set -e

PLUGIN_JSON=".claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

if [ -f "$PLUGIN_JSON" ] && ! git log -1 --format=%s | grep -q "^chore: bump version"; then
    current=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])")
    IFS='.' read -r major minor patch <<< "$current"
    new_version="$major.$minor.$((patch + 1))"

    python3 << PYEOF
import json

for path in ["$PLUGIN_JSON", "$MARKETPLACE_JSON"]:
    try:
        with open(path) as f:
            d = json.load(f)
        if "version" in d:
            d["version"] = "$new_version"
        if "metadata" in d and "version" in d["metadata"]:
            d["metadata"]["version"] = "$new_version"
        with open(path, "w") as f:
            json.dump(d, f, indent=2, ensure_ascii=False)
            f.write("\n")
    except FileNotFoundError:
        pass
PYEOF

    git add "$PLUGIN_JSON" "$MARKETPLACE_JSON" 2>/dev/null
    git commit -m "chore: bump version to $new_version"
    echo "✓ Bumped version to $new_version"
fi

git push "$@"

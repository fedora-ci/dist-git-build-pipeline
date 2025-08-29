# /// script
# dependencies = [
#   "valkey[libvalkey]",
# ]
# ///

import argparse
import datetime
import os
from pathlib import Path


import valkey


# Task-id caching is independent of any timeouts, might as well set it quite high
TASK_ID_CACHE_TIME = datetime.timedelta(days=14.0)


def find_koji_task(valkey_client: valkey.Valkey, args: argparse.Namespace) -> None:
    # Find the lask koji task-id matching the package and commit
    cache_path = (
        f"fedora-ci/dist-git-build-pipeline/{args.repo_full_name}@{args.pr_commit}"
    )
    cached_task_id = valkey_client.get(f"{cache_path}/task-id")
    cached_koji_url = valkey_client.get(f"{cache_path}/koji-url")
    task_id_file = Path("task_id")
    koji_url_file = Path("koji_url")
    # Make sure there were not previous files there similar to scratch-build.sh
    task_id_file.unlink(missing_ok=True)
    koji_url_file.unlink(missing_ok=True)
    if cached_task_id and cached_koji_url:
        print(f"Found cached koji task_id: {cached_task_id}")
        print(f"Found cached koji url: {cached_koji_url}")
        # We have the values cached, so write them to the file
        with task_id_file.open("w") as f:
            f.write(cached_task_id)
        with koji_url_file.open("w") as f:
            f.write(cached_koji_url)
    else:
        print("No cached koji task_id found")


def save_koji_task(valkey_client: valkey.Valkey, args: argparse.Namespace) -> None:
    # Save the koji task-id
    cache_path = (
        f"fedora-ci/dist-git-build-pipeline/{args.repo_full_name}@{args.pr_commit}"
    )
    task_id = Path("task_id").read_text().rstrip()
    koji_url = Path("koji_url").read_text().rstrip()
    valkey_client.set(
        f"{cache_path}/task-id",
        task_id,
        ex=TASK_ID_CACHE_TIME,
    )
    valkey_client.set(
        f"{cache_path}/koji-url",
        koji_url,
        ex=TASK_ID_CACHE_TIME,
    )
    print(f"Cached koji task_id: {task_id}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.environ.get("VALKEY_HOST", "localhost"))
    parser.add_argument("--port", default=6379, type=int)
    parser.add_argument("--db", default=0, type=int)

    actions = parser.add_subparsers(required=True, dest="action")

    find_parser = actions.add_parser("find")
    find_parser.add_argument("repo_full_name")
    find_parser.add_argument("pr_id")

    save_parser = actions.add_parser("save")
    save_parser.add_argument("repo_full_name")
    save_parser.add_argument("pr_id")

    args = parser.parse_args()

    # We store the current (cache) state of the jobs in a valkey server
    valkey_client = valkey.Valkey(
        host=args.host,
        port=args.port,
        db=args.db,
    )

    match args.action:
        case "find":
            find_koji_task(valkey_client, args)
        case "save":
            save_koji_task(valkey_client, args)
        case _:
            raise NotImplementedError

# /// script
# dependencies = [
#   "valkey[libvalkey]",
# ]
# ///

import argparse
import datetime
import os


import valkey


# Using a high build_id cache time higher than the actual timeout
# This should delete any leftover caches if they leaked
BUILD_ID_CACHE_TIME = datetime.timedelta(days=1.25)


def replace_build(valkey_client: valkey.Valkey, args: argparse.Namespace) -> None:
    # Set the current build-id for the running jobs and get the previous one if it existed
    running_job_var = f"fedora-ci/dist-git-build-pipeline/{args.repo_full_name}#{args.pr_id}/running-job"
    old_build = valkey_client.set(
        running_job_var,
        args.build_id,
        get=True,
        ex=BUILD_ID_CACHE_TIME,
    )
    if old_build:
        print(old_build.decode())


def finish_build(valkey_client: valkey.Valkey, args: argparse.Namespace) -> None:
    # Delete the current build-id from the cache store
    running_job_var = f"fedora-ci/dist-git-build-pipeline/{args.repo_full_name}#{args.pr_id}/running-job"
    current_build_id = valkey_client.get(running_job_var)
    if not current_build_id:
        print("Unexpected: The build ID was not in the running-job")
    elif current_build_id.decode() != args.build_id:
        print("Unexpected: There is a different build ID currently running")
    else:
        # Expected case
        valkey_client.delete(running_job_var)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.environ.get("VALKEY_HOST", "localhost"))
    parser.add_argument("--port", default=6379, type=int)
    parser.add_argument("--db", default=0, type=int)

    actions = parser.add_subparsers(required=True, dest="action")

    replace_parser = actions.add_parser("replace")
    replace_parser.add_argument("repo_full_name")
    replace_parser.add_argument("pr_id")
    replace_parser.add_argument("--build-id", default=os.environ.get("BUILD_ID"))

    finish_parser = actions.add_parser("finish")
    finish_parser.add_argument("repo_full_name")
    finish_parser.add_argument("pr_id")
    finish_parser.add_argument("--build-id", default=os.environ.get("BUILD_ID"))

    args = parser.parse_args()
    assert args.build_id

    # We store the current (cache) state of the jobs in a valkey server
    valkey_client = valkey.Valkey(
        host=args.host,
        port=args.port,
        db=args.db,
    )

    match args.action:
        case "replace":
            replace_build(valkey_client, args)
        case "finish":
            finish_build(valkey_client, args)
        case _:
            raise NotImplementedError


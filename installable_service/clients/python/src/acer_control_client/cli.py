from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Sequence

from .client import AcerControlClient, AcerControlError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="acer-service-control")
    parser.add_argument("command", choices=("status", "fan", "keyboard", "led", "profile", "settings"))
    parser.add_argument("arguments", nargs="*")
    parser.add_argument("--base-url")
    parser.add_argument("--token")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    options = parser.parse_args(argv)
    client = AcerControlClient(base_url=options.base_url, token=options.token)
    try:
        result = _dispatch(client, options.command, options.arguments)
    except (AcerControlError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    if result is not None:
        print(json.dumps(result, indent=2))
    return 0


def _dispatch(
    client: AcerControlClient,
    command: str,
    arguments: list[str],
) -> dict[str, object] | None:
    if command == "status" and not arguments:
        return client.get_status()
    if command == "fan":
        return _fan(client, arguments)
    if command in ("keyboard", "led"):
        return _keyboard(client, arguments)
    if command == "profile":
        return _profile(client, arguments)
    if command == "settings" and arguments == ["apply"]:
        client.apply_settings()
        return None
    raise ValueError(f"invalid arguments for {command}")


def _fan(client: AcerControlClient, arguments: list[str]) -> dict[str, object]:
    if arguments == ["status"]:
        return client.get_fan()
    if len(arguments) == 1 and arguments[0].lower() in ("auto", "max"):
        return client.set_fan(arguments[0])
    if len(arguments) == 3 and arguments[0].lower() == "custom":
        arguments = arguments[1:]
    if len(arguments) == 2:
        return client.set_fan("custom", int(arguments[0]), int(arguments[1]))
    raise ValueError("fan requires status, auto, max, or CPU and GPU percentages")


def _keyboard(client: AcerControlClient, arguments: list[str]) -> dict[str, object]:
    if arguments == ["status"]:
        return client.get_keyboard()
    if len(arguments) != 4:
        raise ValueError("keyboard requires color RRGGBB brightness 0-100")
    pairs = dict(zip(arguments[0::2], arguments[1::2], strict=True))
    if set(pairs) != {"color", "brightness"}:
        raise ValueError("keyboard requires color and brightness")
    return client.set_keyboard(pairs["color"], int(pairs["brightness"]))


def _profile(client: AcerControlClient, arguments: list[str]) -> dict[str, object]:
    if arguments == ["status"]:
        return client.get_profile()
    if arguments == ["next"]:
        return client.next_profile()
    if len(arguments) == 1:
        return client.set_profile(arguments[0])
    raise ValueError("profile requires status, next, or a profile name")


if __name__ == "__main__":
    sys.exit(main())
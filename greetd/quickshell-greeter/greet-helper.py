#!/usr/bin/env python3
import json
import os
import socket
import struct
import sys


def send_msg(sock, obj):
    body = json.dumps(obj).encode("utf-8")
    sock.sendall(struct.pack("<I", len(body)) + body)


def recv_msg(sock):
    header = b""
    while len(header) < 4:
        chunk = sock.recv(4 - len(header))
        if not chunk:
            raise ConnectionError("greetd closed the socket while reading header")
        header += chunk
    (length,) = struct.unpack("<I", header)
    body = b""
    while len(body) < length:
        chunk = sock.recv(length - len(body))
        if not chunk:
            raise ConnectionError("greetd closed the socket while reading body")
        body += chunk
    return json.loads(body.decode("utf-8"))


def fail(reason):
    print(f"FAIL:{reason}")
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        fail("usage: greet-helper.py <username> <session_cmd...>")

    username = sys.argv[1]
    session_cmd = sys.argv[2:]

    password = sys.stdin.readline().rstrip("\n")

    sock_path = os.environ.get("GREETD_SOCK")
    if not sock_path:
        fail("GREETD_SOCK not set - this must be run inside a greetd session")

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(sock_path)

        send_msg(sock, {"type": "create_session", "username": username})
        resp = recv_msg(sock)

        # Answer any number of auth prompts with the same password.
        # Fine for simple PAM password auth; a real MFA setup would
        # need per-prompt handling.
        while resp.get("type") == "auth_message":
            send_msg(sock, {
                "type": "post_auth_message_response",
                "response": password,
            })
            resp = recv_msg(sock)

        if resp.get("type") == "error":
            fail(resp.get("description", "auth error"))

        if resp.get("type") != "success":
            fail(f"unexpected response: {resp}")

        # Auth succeeded - actually start the session.
        send_msg(sock, {"type": "start_session", "cmd": session_cmd})
        resp = recv_msg(sock)

        if resp.get("type") == "error":
            fail(resp.get("description", "start_session error"))

        print("OK")
    except Exception as e:
        fail(str(e))
    finally:
        sock.close()


if __name__ == "__main__":
    main()

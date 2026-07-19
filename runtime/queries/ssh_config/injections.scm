((condition
  criteria: "exec"
  argument: (string) @injection.content)
  (#set! injection.language "bash"))

((parameter
  keyword:
    [
      "KnownHostsCommand"
      "LocalCommand"
      "RemoteCommand"
      "ProxyCommand"
    ]
  argument: (string) @injection.content)
  (#set! injection.language "bash"))

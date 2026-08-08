{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ahdg.podman.proxyLlm;
  serviceName = "proxy-llm.service";

  composeFile = pkgs.writeText "proxy-llm-compose.yaml" ''
    services:
      postgres:
        image: docker.io/library/postgres@sha256:a02db8cac496f15b094798a38254f14d6e00741f709360e5e00bb6668ea31636
        restart: unless-stopped
        environment:
          POSTGRES_USER: ''${DB_USER:-postgres}
          POSTGRES_PASSWORD: ''${DB_PASSWORD:?DB_PASSWORD is required}
          POSTGRES_DB: ''${DB_NAME:-claude_code_hub}
          PGDATA: /data/pgdata
          TZ: Asia/Shanghai
          PGTZ: Asia/Shanghai
        volumes:
          - ${cfg.stateDir}/postgres:/data
        tmpfs:
          - /var/lib/postgresql

      dragonfly:
        image: docker.dragonflydb.io/dragonflydb/dragonfly@sha256:ebf3c6c213e82fb51b4521660cca13f06f3421dc5b1ed14f2f474c50b5e29986
        restart: unless-stopped
        ulimits:
          memlock: -1
        volumes:
          - ${cfg.stateDir}/dragonfly:/data
        command:
          - --logtostderr
          - --dir=/data
          - --dbfilename=dump
          - --snapshot_cron=*/5 * * * *
          - --maxmemory=1gb
          - --proactor_threads=2
          - --default_lua_flags=allow-undeclared-keys

      sing-box:
        image: ghcr.io/sagernet/sing-box@sha256:ba3a37088461712e8438de1d18d817a6b9964fe8c7bc7dd10218f6fd18214303
        restart: unless-stopped
        command: [ "-D", "/var/lib/sing-box", "-C", "/etc/sing-box", "run" ]
        volumes:
          - ${cfg.stateDir}/sing-box.json:/etc/sing-box/config.json:ro
          - ${cfg.stateDir}/sing-box:/var/lib/sing-box

      api:
        image: ghcr.io/pluxeljs/proxy-llm-api@sha256:6dda40f3538b50f4fbb51c36e1c9147ca1169e0f72daa88b6463c1dca935e3b1
        restart: unless-stopped
        user: "0:0"
        depends_on:
          sing-box:
            condition: service_started
        environment:
          TZ: Asia/Taipei
          HTTP_PROXY: socks5h://sing-box:1080
          HTTPS_PROXY: socks5h://sing-box:1080
          ALL_PROXY: socks5h://sing-box:1080
          NO_PROXY: 127.0.0.1,localhost,::1,api,cli-proxy-api
          http_proxy: socks5h://sing-box:1080
          https_proxy: socks5h://sing-box:1080
          all_proxy: socks5h://sing-box:1080
          no_proxy: 127.0.0.1,localhost,::1,api,cli-proxy-api
        networks:
          default:
            aliases:
              - cli-proxy-api
        ports:
          - "''${PROXY_LLM_API_BIND:-127.0.0.1}:''${PROXY_LLM_API_PORT:-8317}:8317"
          - "''${PROXY_LLM_CALLBACK_BIND:-127.0.0.1}:''${PROXY_LLM_CODEX_CALLBACK_PORT:-1455}:1455"
          - "''${PROXY_LLM_CALLBACK_BIND:-127.0.0.1}:''${PROXY_LLM_CLAUDE_CALLBACK_PORT:-54545}:54545"
          - "''${PROXY_LLM_CALLBACK_BIND:-127.0.0.1}:''${PROXY_LLM_ANTIGRAVITY_CALLBACK_PORT:-51121}:51121"
        volumes:
          - ${cfg.stateDir}/api-config.yaml:/CLIProxyAPI/config.yaml:ro
          - ${cfg.stateDir}/auth:/data/auth
          - ${cfg.stateDir}/logs:/CLIProxyAPI/logs
          - ${cfg.stateDir}/plugins:/CLIProxyAPI/plugins

      hub:
        image: ghcr.io/ding113/claude-code-hub@sha256:4ae48e6e88b0cc2ce6949a6e13e390dafe35e37066e8b6280140b5368e5c5079
        restart: unless-stopped
        depends_on:
          postgres:
            condition: service_started
          dragonfly:
            condition: service_started
          api:
            condition: service_started
        environment:
          NODE_ENV: production
          DSN: postgresql://''${DB_USER:-postgres}:''${DB_PASSWORD:?DB_PASSWORD is required}@postgres:5432/''${DB_NAME:-claude_code_hub}
          REDIS_URL: redis://dragonfly:6379
          AUTO_MIGRATE: ''${AUTO_MIGRATE:-true}
          ADMIN_TOKEN: ''${ADMIN_TOKEN:?ADMIN_TOKEN is required}
          APP_URL: ''${APP_URL:-}
          API_TEST_TIMEOUT_MS: ''${API_TEST_TIMEOUT_MS:-15000}
          ENABLE_SECURE_COOKIES: ''${ENABLE_SECURE_COOKIES:-true}
          ENABLE_RATE_LIMIT: ''${ENABLE_RATE_LIMIT:-true}
          SESSION_TTL: ''${SESSION_TTL:-300}
          STORE_SESSION_MESSAGES: ''${STORE_SESSION_MESSAGES:-false}
          ENABLE_CIRCUIT_BREAKER_ON_NETWORK_ERRORS: ''${ENABLE_CIRCUIT_BREAKER_ON_NETWORK_ERRORS:-false}
          MAX_RETRY_ATTEMPTS_DEFAULT: ''${MAX_RETRY_ATTEMPTS_DEFAULT:-2}
          ENABLE_SMART_PROBING: ''${ENABLE_SMART_PROBING:-false}
          PROBE_INTERVAL_MS: ''${PROBE_INTERVAL_MS:-30000}
          PROBE_TIMEOUT_MS: ''${PROBE_TIMEOUT_MS:-5000}
          ENABLE_MULTI_PROVIDER_TYPES: ''${ENABLE_MULTI_PROVIDER_TYPES:-false}
          TZ: Asia/Shanghai
        ports:
          - "''${PROXY_LLM_HUB_BIND:-0.0.0.0}:''${PROXY_LLM_HUB_PORT:-23000}:3000"
  '';
in
{
  options.ahdg.podman.proxyLlm = {
    enable = lib.mkEnableOption "Proxy-LLM-API and Claude Code Hub compose stack";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable and start the generated user systemd service during activation.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/proxy-llm";
      description = "Local configuration and persistent data for the compose stack.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.prepareProxyLlmState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      umask 0077
      ${pkgs.coreutils}/bin/mkdir -p \
        ${lib.escapeShellArg cfg.stateDir} \
        ${lib.escapeShellArg "${cfg.stateDir}/postgres"} \
        ${lib.escapeShellArg "${cfg.stateDir}/dragonfly"} \
        ${lib.escapeShellArg "${cfg.stateDir}/sing-box"} \
        ${lib.escapeShellArg "${cfg.stateDir}/auth"} \
        ${lib.escapeShellArg "${cfg.stateDir}/logs"} \
        ${lib.escapeShellArg "${cfg.stateDir}/plugins"}
      ${pkgs.coreutils}/bin/chmod 0700 ${lib.escapeShellArg cfg.stateDir}
    '';

    home.activation.ensureProxyLlmService =
      lib.hm.dag.entryAfter
        [
          "ensurePodmanSocket"
          "linkGeneration"
          "prepareProxyLlmState"
        ]
        ''
          if command -v systemctl >/dev/null 2>&1 && command -v podman >/dev/null 2>&1; then
            systemctl --user daemon-reload >/dev/null 2>&1 || true
            ${lib.optionalString cfg.autoStart ''
              systemctl --user enable --now ${serviceName} >/dev/null 2>&1 || true
            ''}
          fi
        '';

    xdg.configFile."systemd/user/${serviceName}".text = ''
      [Unit]
      Description=Proxy-LLM-API and Claude Code Hub
      Wants=podman.socket
      After=podman.socket
      ConditionPathExists=${cfg.stateDir}/.env
      ConditionPathExists=${cfg.stateDir}/api-config.yaml
      ConditionPathExists=${cfg.stateDir}/sing-box.json

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      WorkingDirectory=${cfg.stateDir}
      Environment=DOCKER_HOST=unix://%t/podman/podman.sock
      ExecStartPre=/usr/bin/env sh -c 'test -S "$XDG_RUNTIME_DIR/podman/podman.sock" || systemctl --user restart podman.socket'
      ExecStart=/usr/bin/env podman compose --env-file ${cfg.stateDir}/.env -f ${composeFile} -p proxy-llm up -d --remove-orphans
      ExecStop=/usr/bin/env podman compose --env-file ${cfg.stateDir}/.env -f ${composeFile} -p proxy-llm down --remove-orphans
      TimeoutStartSec=0
      TimeoutStopSec=90

      [Install]
      WantedBy=default.target
    '';
  };
}

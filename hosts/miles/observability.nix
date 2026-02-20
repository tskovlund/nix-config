# Observability stack — Prometheus, Grafana, Loki, Promtail, node exporter.
#
# All services listen on localhost only. Grafana is exposed via Caddy
# (vhost defined in default.nix). No additional firewall ports needed.
#
# Post-deploy setup:
#   1. Add Cloudflare DNS: grafana.skovlund.dev CNAME miles.skovlund.dev
#   2. Open https://grafana.skovlund.dev, set admin password
#   3. Import Node Exporter Full dashboard (ID 1860)
#   4. Configure alerts → Ntfy webhook (https://ntfy.skovlund.dev/alerts)
{ pkgs, ... }:

{
  # Generate Grafana secret key on first boot (never enters the Nix store)
  systemd.services.grafana-secret-key = {
    description = "Generate Grafana secret key if missing";
    wantedBy = [ "grafana.service" ];
    before = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      KEY_FILE="/var/lib/grafana/secret_key"
      if [ ! -f "$KEY_FILE" ]; then
        mkdir -p /var/lib/grafana
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$KEY_FILE"
        chown grafana:grafana "$KEY_FILE"
        chmod 400 "$KEY_FILE"
      fi
    '';
  };

  # Node exporter — system metrics (CPU, memory, disk, network, systemd units)
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  # Prometheus — metrics storage and scraping
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "30d";
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          { targets = [ "localhost:9100" ]; }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          { targets = [ "localhost:9090" ]; }
        ];
      }
    ];
  };

  # Loki — log aggregation
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_port = 3100;
        http_listen_address = "127.0.0.1";
        grpc_listen_address = "127.0.0.1";
      };
      memberlist = {
        bind_addr = [ "127.0.0.1" ];
        advertise_addr = "127.0.0.1";
      };
      frontend.address = "127.0.0.1";
      frontend_worker.frontend_address = "127.0.0.1:9095";
      common = {
        ring = {
          kvstore.store = "inmemory";
          instance_addr = "127.0.0.1";
        };
        replication_factor = 1;
        path_prefix = "/var/lib/loki";
      };
      schema_config.configs = [
        {
          from = "2026-02-20";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      storage_config.filesystem.directory = "/var/lib/loki/chunks";
      limits_config = {
        retention_period = "30d";
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };
    };
  };

  # Ensure Promtail data directory exists (required before systemd namespace setup)
  systemd.tmpfiles.rules = [
    "d /var/lib/promtail 0700 promtail promtail -"
  ];

  # Promtail — ships systemd journal logs to Loki
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      positions.filename = "/var/lib/promtail/positions.yaml";
      clients = [
        { url = "http://localhost:3100/loki/api/v1/push"; }
      ];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels.job = "systemd-journal";
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
          ];
        }
      ];
    };
  };

  # Grafana — dashboards and alerting
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_port = 3002;
        http_addr = "127.0.0.1";
        root_url = "https://grafana.skovlund.dev";
      };
      security = {
        admin_user = "thomas";
        secret_key = "$__file{/var/lib/grafana/secret_key}";
      };
      "auth.anonymous".enabled = false;
      users.allow_sign_up = false;
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
          isDefault = true;
          editable = false;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://localhost:3100";
          editable = false;
        }
      ];
    };
  };
}

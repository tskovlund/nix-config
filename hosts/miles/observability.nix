# Observability stack — Prometheus, Grafana, Loki, Promtail, node exporter.
#
# All services listen on localhost only. Grafana is exposed via Caddy
# (vhost defined in default.nix). No additional firewall ports needed.
#
# Post-deploy setup:
#   1. Verify services: systemctl status grafana prometheus loki promtail
#   2. Test contact points: Grafana → Alerting → Contact points → Test
#   3. Create Grafana service account for MCP (see docs/miles.md)
{ pkgs, ... }:

let
  # Node Exporter Full dashboard (ID 1860, rev 37) — fetched at build time, pinned by hash.
  nodeExporterDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
    hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
  };

  # Patch the dashboard JSON to use our explicit datasource UID ("prometheus")
  # and remove the __inputs section so Grafana doesn't prompt for input mapping.
  nodeExporterDashboardPatched =
    pkgs.runCommand "node-exporter-full.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        jq '
          # Remove __inputs (Grafana uses this for import wizard, not provisioning)
          del(.__inputs) |
          # Remove __elements and __requires (not needed for provisioning)
          del(.__elements) |
          del(.__requires) |
          # Set a stable UID so it does not regenerate on every provision
          .uid = "node-exporter-full" |
          # Remove id so Grafana assigns one
          .id = null |
          # Replace datasource references: the dashboard uses ''${DS_PROMETHEUS}
          # templating variable — set its default to our Prometheus UID
          (.templating.list[] | select(.name == "DS_PROMETHEUS")) |= (
            .current = {"selected": true, "text": "Prometheus", "value": "prometheus"} |
            .query = "prometheus" |
            .type = "datasource"
          )
        ' ${nodeExporterDashboard} > $out
      '';
in
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

  # Copy Resend API key for Grafana SMTP (from agenix-decrypted home path)
  systemd.services.grafana-smtp-password = {
    description = "Copy Resend API key for Grafana SMTP";
    wantedBy = [ "grafana.service" ];
    before = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      DEST="/var/lib/grafana/smtp_password"
      SRC="/home/thomas/.config/resend/api-key"
      if [ ! -f "$DEST" ]; then
        mkdir -p /var/lib/grafana
        if [ -f "$SRC" ]; then
          cp "$SRC" "$DEST"
        else
          # Placeholder so Grafana starts even without the real key.
          # SMTP auth will fail until the real key is deployed via:
          #   make deploy-miles  (which runs home-manager → agenix decryption)
          #   then: rm /var/lib/grafana/smtp_password && systemctl restart grafana-smtp-password grafana
          echo "not-yet-configured" > "$DEST"
        fi
        chown grafana:grafana "$DEST"
        chmod 400 "$DEST"
      fi
    '';
  };

  # Create ntfy user for Grafana alert notifications
  systemd.services.grafana-ntfy-auth = {
    description = "Create ntfy user for Grafana alerts";
    wantedBy = [ "grafana.service" ];
    before = [ "grafana.service" ];
    after = [ "ntfy-sh.service" ];
    path = [
      pkgs.ntfy-sh
      pkgs.openssl
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      PASSWORD_FILE="/var/lib/grafana/ntfy_password"
      if [ ! -f "$PASSWORD_FILE" ]; then
        mkdir -p /var/lib/grafana
        PASSWORD=$(openssl rand -hex 16)
        # Create ntfy user (ignore error if already exists).
        # ntfy reads auth-file location from /etc/ntfy-sh/server.yml automatically.
        printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" \
          | ntfy user add grafana-alerts 2>/dev/null || true
        # Grant write-only access to the alerts topic
        ntfy access grafana-alerts alerts write-only 2>/dev/null || true
        printf '%s' "$PASSWORD" > "$PASSWORD_FILE"
        chown grafana:grafana "$PASSWORD_FILE"
        chmod 400 "$PASSWORD_FILE"
      fi
    '';
  };

  # Provision dashboard JSON to a path Grafana can read
  environment.etc."grafana/dashboards/node-exporter-full.json" = {
    source = nodeExporterDashboardPatched;
    mode = "0444";
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
      {
        job_name = "caddy";
        static_configs = [
          { targets = [ "localhost:2019" ]; }
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

  # Grafana — dashboards, alerting, and visualization
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
      smtp = {
        enabled = true;
        host = "smtp.resend.com:587";
        user = "resend";
        password = "$__file{/var/lib/grafana/smtp_password}";
        from_address = "grafana@notify.skovlund.dev";
        from_name = "Grafana (miles)";
        startTLS_policy = "MandatoryStartTLS";
      };
    };
    provision = {
      enable = true;

      # Datasources — explicit UIDs so alert rules and dashboards can reference them
      datasources.settings.deleteDatasources = [
        {
          name = "Prometheus";
          orgId = 1;
        }
        {
          name = "Loki";
          orgId = 1;
        }
      ];
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          uid = "prometheus";
          url = "http://localhost:9090";
          isDefault = true;
          editable = false;
        }
        {
          name = "Loki";
          type = "loki";
          uid = "loki";
          url = "http://localhost:3100";
          editable = false;
        }
      ];

      # Dashboards — provisioned from JSON files
      dashboards.settings.providers = [
        {
          name = "default";
          type = "file";
          options.path = "/etc/grafana/dashboards";
        }
      ];

      # Contact points — Ntfy (primary) + Email/Resend (secondary)
      alerting.contactPoints.settings = {
        apiVersion = 1;
        contactPoints = [
          {
            orgId = 1;
            name = "ntfy-and-email";
            receivers = [
              {
                uid = "ntfy";
                type = "webhook";
                settings = {
                  url = "https://ntfy.skovlund.dev/alerts";
                  httpMethod = "POST";
                  username = "grafana-alerts";
                  password = "$__file{/var/lib/grafana/ntfy_password}";
                };
              }
              {
                uid = "email";
                type = "email";
                settings = {
                  addresses = "thomas@skovlund.dev";
                };
              }
            ];
          }
        ];
      };

      # Notification policy — route all alerts to ntfy + email
      alerting.policies.settings = {
        apiVersion = 1;
        policies = [
          {
            orgId = 1;
            receiver = "ntfy-and-email";
            group_by = [ "alertname" ];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
          }
        ];
      };

      # Alert rules
      alerting.rules.settings = {
        apiVersion = 1;
        groups = [
          {
            orgId = 1;
            name = "miles-system";
            folder = "System";
            interval = "1m";
            rules = [
              # Disk usage > 80% (warning)
              {
                uid = "disk-80";
                title = "Disk usage > 80%";
                condition = "threshold";
                for = "5m";
                noDataState = "NoData";
                execErrState = "Error";
                labels = {
                  severity = "warning";
                };
                annotations = {
                  summary = "Disk usage above 80% on {{ $labels.mountpoint }}";
                  description = "{{ $labels.device }} ({{ $labels.mountpoint }}) is {{ $values.usage | printf \"%.1f\" }}% full.";
                };
                data = [
                  {
                    refId = "usage";
                    datasourceUid = "prometheus";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      expr = ''(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay",mountpoint!~"/boot.*"} / node_filesystem_size_bytes) * 100'';
                      refId = "usage";
                    };
                  }
                  {
                    refId = "threshold";
                    datasourceUid = "-100";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      type = "threshold";
                      refId = "threshold";
                      conditions = [
                        {
                          type = "query";
                          evaluator = {
                            type = "gt";
                            params = [ 80 ];
                          };
                          operator.type = "and";
                          query.params = [ "usage" ];
                          reducer.type = "last";
                        }
                      ];
                    };
                  }
                ];
              }
              # Disk usage > 90% (critical)
              {
                uid = "disk-90";
                title = "Disk usage > 90%";
                condition = "threshold";
                for = "5m";
                noDataState = "NoData";
                execErrState = "Error";
                labels = {
                  severity = "critical";
                };
                annotations = {
                  summary = "Disk usage above 90% on {{ $labels.mountpoint }}";
                  description = "{{ $labels.device }} ({{ $labels.mountpoint }}) is {{ $values.usage | printf \"%.1f\" }}% full. Immediate action required.";
                };
                data = [
                  {
                    refId = "usage";
                    datasourceUid = "prometheus";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      expr = ''(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay",mountpoint!~"/boot.*"} / node_filesystem_size_bytes) * 100'';
                      refId = "usage";
                    };
                  }
                  {
                    refId = "threshold";
                    datasourceUid = "-100";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      type = "threshold";
                      refId = "threshold";
                      conditions = [
                        {
                          type = "query";
                          evaluator = {
                            type = "gt";
                            params = [ 90 ];
                          };
                          operator.type = "and";
                          query.params = [ "usage" ];
                          reducer.type = "last";
                        }
                      ];
                    };
                  }
                ];
              }
              # Memory usage > 85%
              {
                uid = "memory-85";
                title = "Memory usage > 85%";
                condition = "threshold";
                for = "5m";
                noDataState = "NoData";
                execErrState = "Error";
                labels = {
                  severity = "warning";
                };
                annotations = {
                  summary = "Memory usage above 85%";
                  description = "Memory usage is {{ $values.usage | printf \"%.1f\" }}%.";
                };
                data = [
                  {
                    refId = "usage";
                    datasourceUid = "prometheus";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      expr = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100";
                      refId = "usage";
                    };
                  }
                  {
                    refId = "threshold";
                    datasourceUid = "-100";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      type = "threshold";
                      refId = "threshold";
                      conditions = [
                        {
                          type = "query";
                          evaluator = {
                            type = "gt";
                            params = [ 85 ];
                          };
                          operator.type = "and";
                          query.params = [ "usage" ];
                          reducer.type = "last";
                        }
                      ];
                    };
                  }
                ];
              }
              # CPU usage > 90% (sustained 5 min)
              {
                uid = "cpu-90";
                title = "CPU usage > 90% (5m avg)";
                condition = "threshold";
                for = "5m";
                noDataState = "NoData";
                execErrState = "Error";
                labels = {
                  severity = "warning";
                };
                annotations = {
                  summary = "CPU usage above 90% for 5 minutes";
                  description = "CPU usage is {{ $values.usage | printf \"%.1f\" }}%.";
                };
                data = [
                  {
                    refId = "usage";
                    datasourceUid = "prometheus";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                      refId = "usage";
                    };
                  }
                  {
                    refId = "threshold";
                    datasourceUid = "-100";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      type = "threshold";
                      refId = "threshold";
                      conditions = [
                        {
                          type = "query";
                          evaluator = {
                            type = "gt";
                            params = [ 90 ];
                          };
                          operator.type = "and";
                          query.params = [ "usage" ];
                          reducer.type = "last";
                        }
                      ];
                    };
                  }
                ];
              }
              # Systemd service failed
              {
                uid = "systemd-failed";
                title = "Systemd service failed";
                condition = "threshold";
                for = "1m";
                noDataState = "OK";
                execErrState = "Error";
                labels = {
                  severity = "critical";
                };
                annotations = {
                  summary = "Systemd unit {{ $labels.name }} has failed";
                  description = "The service {{ $labels.name }} entered a failed state.";
                };
                data = [
                  {
                    refId = "failed";
                    datasourceUid = "prometheus";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      expr = "node_systemd_unit_state{state=\"failed\"} == 1";
                      refId = "failed";
                    };
                  }
                  {
                    refId = "threshold";
                    datasourceUid = "-100";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      type = "threshold";
                      refId = "threshold";
                      conditions = [
                        {
                          type = "query";
                          evaluator = {
                            type = "gt";
                            params = [ 0 ];
                          };
                          operator.type = "and";
                          query.params = [ "failed" ];
                          reducer.type = "last";
                        }
                      ];
                    };
                  }
                ];
              }
              # Prometheus scrape target down
              {
                uid = "target-down";
                title = "Prometheus scrape target down";
                condition = "threshold";
                for = "5m";
                noDataState = "Alerting";
                execErrState = "Error";
                labels = {
                  severity = "critical";
                };
                annotations = {
                  summary = "Scrape target {{ $labels.job }} ({{ $labels.instance }}) is down";
                  description = "Prometheus cannot reach {{ $labels.instance }} for job {{ $labels.job }}.";
                };
                data = [
                  {
                    refId = "up";
                    datasourceUid = "prometheus";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      expr = "up";
                      refId = "up";
                    };
                  }
                  {
                    refId = "threshold";
                    datasourceUid = "-100";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    model = {
                      type = "threshold";
                      refId = "threshold";
                      conditions = [
                        {
                          type = "query";
                          evaluator = {
                            type = "lt";
                            params = [ 1 ];
                          };
                          operator.type = "and";
                          query.params = [ "up" ];
                          reducer.type = "last";
                        }
                      ];
                    };
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mdatp;
  packageDefault = pkgs.callPackage ../pkgs/mdatp { nurTests = { }; };
  prepare = pkgs.writeShellScript "mdatp-prepare" ''
    set -euo pipefail

    if [[ -r /proc/config.gz ]]; then
      install -d -m 0755 /boot
      ${pkgs.gzip}/bin/gzip -dc /proc/config.gz >"/boot/config-$(${pkgs.coreutils}/bin/uname -r)"
    fi

    ${lib.optionalString (cfg.onboardingPath != null) ''
      install -m 0600 ${lib.escapeShellArg cfg.onboardingPath} \
        /etc/opt/microsoft/mdatp/mdatp_onboard.json
    ''}
  '';
in
{
  options.services.mdatp = {
    enable = lib.mkEnableOption "Microsoft Defender for Endpoint";

    package = lib.mkOption {
      type = lib.types.package;
      default = packageDefault;
      defaultText = lib.literalExpression "pkgs.callPackage ./pkgs/mdatp { }";
      description = "The mdatp package to use.";
    };

    onboardingPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/mdatp_onboard.json";
      description = ''
        Runtime path to the Microsoft Defender onboarding JSON. The file is
        copied into place when the service starts, so its contents are not
        copied into the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    users.groups.mdatp = { };
    users.users.mdatp = {
      description = "Microsoft Defender for Endpoint service user";
      group = "mdatp";
      isSystemUser = true;
    };

    systemd.tmpfiles.rules = [
      "d /opt/microsoft 0755 root root -"
      "L+ /opt/microsoft/mdatp - - - - ${cfg.package}"
      "d /etc/opt/microsoft/mdatp 0755 root root -"
      "d /etc/opt/microsoft/mdatp/managed 0755 root root -"
      "d /var/opt/microsoft/mdatp 0755 root root -"
      "d /var/log/microsoft/mdatp 0775 root mdatp -"
    ];

    systemd.services.mdatp = {
      description = "Microsoft Defender for Endpoint";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        coreutils
        findutils
        gnugrep
        gzip
        iproute2
        iptables
        nftables
        procps
        systemd
        util-linux
      ];
      environment = {
        ENABLE_CRASHPAD = "1";
        LD_AUDIT = "";
        LD_LIBRARY_PATH = "${cfg.package}/lib";
        LD_PRELOAD = "";
        MALLOC_ARENA_MAX = "2";
      };
      serviceConfig = {
        Type = "simple";
        ExecStartPre = prepare;
        ExecStart = "${cfg.package}/sbin/wdavdaemon";
        WorkingDirectory = "${cfg.package}/sbin";
        NotifyAccess = "main";
        LimitNOFILE = 65536;
        Restart = "always";
        RestartSec = 5;
        Delegate = true;
      };
      unitConfig = {
        StartLimitIntervalSec = 120;
        StartLimitBurst = 3;
      };
    };

    systemd.sockets.mde_netfilter_v2 = {
      description = "Microsoft Defender Netfilter Activation Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig.ListenStream = "/run/mde_netfilter.sock";
    };

    systemd.services.mde_netfilter_v2 = {
      description = "Microsoft Defender Netfilter Platform";
      after = [
        "network.target"
        "local-fs.target"
      ];
      requires = [ "mde_netfilter_v2.socket" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        coreutils
        iptables
        nftables
      ];
      environment.LD_LIBRARY_PATH = "${cfg.package}/lib";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/sbin/mde_netfilter";
        WorkingDirectory = "${cfg.package}/sbin";
        NotifyAccess = "main";
        LimitCORE = "infinity";
        KillMode = "process";
        Restart = "on-failure";
        PrivateTmp = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
      };
      unitConfig = {
        StartLimitIntervalSec = 120;
        StartLimitBurst = 3;
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ codgician ];
}

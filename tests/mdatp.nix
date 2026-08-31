{
  pkgs,
  mdatp,
}:

pkgs.testers.runNixOSTest {
  name = "mdatp";

  nodes.machine = {
    imports = [ ../modules/mdatp.nix ];

    services.mdatp = {
      enable = true;
      package = mdatp;
    };

    virtualisation.memorySize = 4096;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("mdatp.service")
    machine.wait_for_unit("mde_netfilter_v2.socket")
    machine.succeed("test $(readlink -f /opt/microsoft/mdatp) = ${mdatp}")
    machine.succeed("systemctl is-active --quiet mdatp.service")
    machine.wait_until_succeeds("mdatp version | grep -F ${mdatp.version}", timeout=120)
    machine.wait_until_succeeds("test -s /var/opt/microsoft/mdatp/wdavstate", timeout=120)
    machine.succeed("test $(systemctl show -P Result mde_netfilter_v2.service) = success")
  '';
}

# TODO: replace with the output of `nixos-generate-config` on the real machine.
{ self, ... }:
{
  flake.nixosModules.laptopHardware =
    { lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # STUB — required so evaluation succeeds; replace with real values.
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];
    };
}

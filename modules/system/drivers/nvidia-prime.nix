# NVIDIA Prime — hybrid graphics for laptops (iGPU + dGPU)
# Offload mode: iGPU drives the display; dGPU used on-demand via nvidia-offload
{ ... }:
{
  flake.nixosModules.nvidia-prime = {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      open = false; # proprietary driver: better suspend/resume for laptops
      nvidiaSettings = true;

      powerManagement.enable = true;
      powerManagement.finegrained = true; # runtime D3 power saving

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true; # `nvidia-offload <cmd>` to run on dGPU
        };
        # TODO: replace with your hardware's bus IDs
        # Run: lspci | grep -E "VGA|3D"
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}

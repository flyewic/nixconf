{ ... }:
{
  flake.nixosModules.zed =
    { pkgs, config, ... }:
    {
      home-manager.users.${config.username}.programs.zed-editor = {
        enable = true;
        extensions = [
          "nix"
          "toml"
        ];
        extraPackages = with pkgs; [
          nixd
          nixfmt-rfc-style
        ];
        themes = {
          "dank-zed-theme" = ./themes/dank-zed-theme.json;
        };
        userSettings = {
          agent_servers = {
            opencode = {
              type = "registry";
            };
            custom-opencode = {
              type = "custom";
              command = "opencode";
              args = [ "acp" ];
            };
          };
          terminal = {
            dock = "right";
          };
          cli_default_open_behavior = "new_window";
          language_models = {
            opencode = {
              show_free_models = true;
              show_go_models = true;
              show_zen_models = false;
            };
          };
          project_panel = {
            dock = "left";
          };
          outline_panel = {
            dock = "left";
          };
          collaboration_panel = {
            dock = "left";
          };
          git_panel = {
            dock = "left";
          };
          debugger = {
            dock = "right";
          };
          context_servers = {
            mcp-server-brave-search = {
              enabled = true;
              remote = false;
              settings = { };
            };
            mcp-server-github = {
              enabled = true;
              remote = false;
              settings = { };
            };
          };
          agent = {
            dock = "right";
            default_model = {
              provider = "opencode";
              model = "go/kimi-k2.6";
              enable_thinking = false;
            };
            favorite_models = [ ];
            model_parameters = [ ];
          };
          auto_indent = "none";
          edit_predictions = {
            mode = "subtle";
            provider = "zed";
          };
          icon_theme = "Catppuccin Mocha";
          ui_font_size = 16;
          buffer_font_size = 15;
          theme = {
            mode = "system";
            light = "One Light";
            dark = "Catppuccin Mocha - No Italics";
          };
          file_types = {
            Lua = [ "lua" ];
            Xmake = [ "xmake.lua" ];
          };
          lsp = {
            lua-language-server = {
              initialization_options = {
                workspace = {
                  ignoreDir = [ ".xmake" "build" ];
                  library = [ ];
                };
                diagnostics = {
                  globals = [ "sol" "malm" ];
                };
              };
            };
            jdtls = {
              initialization_options = {
                settings = {
                  java = {
                    configuration = {
                      updateBuildConfiguration = "interactive";
                    };
                    import = {
                      gradle = {
                        enabled = true;
                      };
                    };
                  };
                };
              };
            };
          };
          tab_size = 4;
          languages = {
            C++ = {
              tab_size = 4;
              format_on_save = "on";
              hard_tabs = false;
            };
            Assembly = {
              language_servers = [ ];
            };
            Java = {
              language_servers = [ "jdtls" ];
            };
          };
        };
      };
    };
}

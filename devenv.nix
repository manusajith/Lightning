{ pkgs, ... }:

{

  packages = [
    pkgs.openssl
    pkgs.pkg-config
    pkgs.openssl.dev
    pkgs.yarn
  ];

  difftastic.enable = true;
  dotenv.enable = true;

  languages.nix.enable = true;
  languages.javascript.enable = true;
  languages.elixir = {
    enable = true;
    package = pkgs.beam.packages.erlangR26.elixir.overrideAttrs (oldAttrs: {
      src = pkgs.fetchFromGitHub {
        owner = "elixir-lang";
        repo = "elixir";
        rev = "main";
        sha256 = "bhRxfn8sqGJPwdtHZzYP9PI6feHQUOwIOHscrJMQ5fg=";
      };
    });
  };
}



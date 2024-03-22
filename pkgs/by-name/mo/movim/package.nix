{ lib
, fetchFromGitHub
, dash
, php
, phpCfg ? null
, withPgsql ? true # “strongly recommended” according to docs
, withMysql ? false
}:

php.buildComposerProject (finalAttrs: {
  pname = "movim";
  version = "0.23.0.20240328";

  src = fetchFromGitHub {
    owner = "movim";
    repo = "movim";
    rev = "c3a43cd7e3a1a3a6efd595470e6a85b2ec578cba";
    hash = "sha256-x0C4w3SRP3NMOhGSZOQALk6PNWUre4MvFW5cESr8Wvk=";
  };

  php = php.buildEnv ({
    extensions = ({ all, enabled }:
      enabled
        ++ (with all; [ curl dom gd imagick mbstring pdo simplexml ])
        ++ lib.optionals withPgsql (with all; [ pdo_pgsql pgsql ])
        ++ lib.optionals withMysql (with all; [ mysqli mysqlnd pdo_mysql ])
    );
  } // lib.optionalAttrs (phpCfg != null) {
    extraConfig = phpCfg;
  });

  # no listed license
  # pinned commonmark
  composerStrictValidation = false;

  vendorHash = "sha256-RFIi1I+gcagRgkDpgQeR1oGJeBGA7z9q3DCfW+ZDr2Y=";

  postPatch = ''
    # BUGFIX: Imagick API Changes for 7.x+
    # See additionally: https://github.com/movim/movim/pull/1122
    substituteInPlace src/Movim/Image.php \
      --replace-fail "Imagick::ALPHACHANNEL_REMOVE" "Imagick::ALPHACHANNEL_OFF" \
      --replace-fail "Imagick::ALPHACHANNEL_ACTIVATE" "Imagick::ALPHACHANNEL_ON"
  '';

  postInstall = ''
    mkdir -p $out/bin
    echo "#!${lib.getExe dash}" > $out/bin/movim
    echo "${lib.getExe finalAttrs.php} $out/share/php/${finalAttrs.pname}/daemon.php \"\$@\"" >> $out/bin/movim
    chmod +x $out/bin/movim

    mkdir -p $out/share/{bash-completion/completion,fish/vendor_completions.d,zsh/site-functions}
    $out/bin/movim completion bash | sed "s/daemon.php/movim/g" > $out/share/bash-completion/completion/movim.bash
    $out/bin/movim completion fish | sed "s/daemon.php/movim/g" > $out/share/fish/vendor_completions.d/movim.fish
    $out/bin/movim completion zsh | sed "s/daemon.php/movim/g" > $out/share/zsh/site-functions/_movim
    chmod +x $out/share/{bash-completion/completion/movim.bash,fish/vendor_completions.d/movim.fish,zsh/site-functions/_movim}
  '';

  meta = {
    description = "a federated blogging & chat platform that acts as a web front end for the XMPP protocol";
    homepage = "https://movim.eu";
    license = lib.licenses.agpl3Plus;
    maintainers = with lib.maintainers; [ toastal ];
    mainProgram = "movim";
  };
})

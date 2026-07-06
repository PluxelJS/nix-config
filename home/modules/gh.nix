{ ... }:
{
  xdg.configFile."gh/config.yml".text = ''
    git_protocol: ssh
    editor: NotepadNext
    prompt: enabled
  '';

  programs.git.settings.credential = {
    "https://github.com" = {
      helper = "!gh auth git-credential";
    };
    "https://gist.github.com" = {
      helper = "!gh auth git-credential";
    };
  };
}

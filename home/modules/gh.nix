{ ... }:
{
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;

    settings = {
      git_protocol = "ssh";
      editor = "NotepadNext";
      prompt = "enabled";
    };
  };
}

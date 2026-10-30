{
  home = {
    username = "example";
    homeDirectory = "/home/example";
    stateVersion = "26.05";
  };

  programs.herdr = {
    enable = true;

    # Replace this alias with an SSH host configured by the consumer.
    machines.example = {
      label = "Example machine";
      target = "herdr-example";
    };

    integrations.pi.enable = true;
  };
}

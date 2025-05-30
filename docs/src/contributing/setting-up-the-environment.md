# Setting up the Environment

This section will guide you through setting up the required environment to develop rakuyomi.

## Prerequisites

Before proceeding, you'll need the following tools installed:

- Linux, macOS or Windows (under [WSL](https://learn.microsoft.com/en-us/windows/wsl/install))
- A working [Git](https://git-scm.com/) installation
- [devenv](https://devenv.sh/getting-started/#installation), used to centralize development dependencies
- [direnv](https://direnv.net/docs/installation.html), used to automatically enter the development environment generated by `devenv`
- [Visual Studio Code](https://code.visualstudio.com/)

```admonish note
Running KOReader under WSL requires [WSLg](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps) to be configured.
```

## Cloning and Setting Up Your IDE

First, clone the repository, copy the `.envrc.dist` to `.envrc` and allow it to be loaded:

```bash
$ git clone https://github.com/hanatsumi/rakuyomi.git
$ cd rakuyomi
$ cp .envrc.dist .envrc
$ direnv allow
```

```admonish tip
If you've enabled [direnv's shell integration](https://direnv.net/docs/hook.html), you should automatically enter a _developer shell_: a shell containing all development dependencies and useful scripts!

Don't worry if you haven't though, you can always enter it by yourself by running `devenv shell`.
```

After that, open the repository in VSCode. You'll be prompted to install the recommended extensions – installing them is highly recommended, as it'll make developing rakuyomi _much_ easier.

After installing the recommended extensions, another prompt will show up - asking whether you want to reload the environment. Accept it, and then you're ready to work with rakuyomi! Here are some useful commands available in the development environment:

- `dev`: starts KOReader with the rakuyomi plugin built from source. Run this in your terminal when you want to test your changes.
- `debug`: starts KOReader with the rakuyomi plugin, and attaches a Rust debugger to the `server` process. Use this when you need to debug issues in the server component.

# headscale-installer

## Usage

### Installation

```sh
sudo sh -c "$(curl -sL https://github.com/MarksonHon/headscale-installer/raw/refs/heads/main/installer.sh)"
```

### Uninstallation

```sh
sudo sh -c "$(curl -sL https://github.com/MarksonHon/headscale-installer/raw/refs/heads/main/uninstaller.sh)"
```

## Notice

### Alpine Linux

If you try to install Headscale on Alpine Linux, install curl and shadow at first.

```sh
doas apk add curl shadow libcap-setcap
```

### Ubuntu

Ubuntu might come with fucking snap-packaged curl, remove it and install curl from apt if you meet error(s).
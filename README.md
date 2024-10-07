# headscale-installer

## Usage

```sh
sudo sh -c "$(curl -sL https://github.com/MarksonHon/headscale-installer/raw/refs/heads/main/installer.sh)"
```

## Alpine Linux Notice

If you try to install Headscale on Alpine Linux, install curl, setcap at first.

```sh
doas apk add curl libcap-setcap
```
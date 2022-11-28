# bsp-var-imx8mp-kirkstone

## Download

```bash
git clone https://github.com/shalex88/bsp-var-imx8mp-yocto.git -b kirkstone bsp-var-imx8mp-kirkstone
```

## Build

### 1. Build docker container

```bash
./scripts/start.sh -b
```

### 2. Run docker container

```bash
./scripts/start.sh
```

### 3. Get yocto sources

```bash
./scripts/clone_yocto.sh
```

### 4. Prepare build environment

```bash
cd var-fsl-yocto
MACHINE=imx8mp-var-dart DISTRO=fslc-xwayland . var-setup-release.sh build
```

### 5. Setup build environment

```bash
./../../scripts/project_setup.sh
```

### 6. Fetch all sources

```bash
In site.conf uncomment the lines used to fetch packages via external network
bitbake fsl-image-qt5 --runonly=fetch -k
bitbake imx-boot --runonly=fetch -k
bitbake meta-toolchain --runonly=fetch -k
```

### 7. Build the image

```bash
# Append MemoryLimit=8G to limit the memory usage
bitbake fsl-image-qt5
```

### 8. Create package

```bash
./create_bsp_package.sh -r 2
```

## Deploy

```bash
./install_bsp.sh -t 10.199.250.4 -r 2 -f
```

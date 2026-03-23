# JAF ODU SSH Access Via ADB

_Disclaimer: This is ONLY for educational purposes, No one is responsible for any type of damage. So be aware._

_NOTE: Works only for the models supporting ADB access._

Credits: [@sumishimii](https://github.com/sumishimii/)

## Prerequisites

- [ADB](https://developer.android.com/tools/releases/platform-tools) installed on your PC.
- Clone the repo: <https://github.com/sumishimii/JioODU-ssh>

## Overview

The sshd binary exists on the JAF ODU at `/usr/sbin/sshd`. However, the root filesystem is read-only, which prevents modifying the sshd config directly or changing the root password, that's why I used SSH key-based auth to get access to the ODU.

> ⚠️ **This method is not persistent and you'll lose ssh connection if the ODU is restarted.** ⚠️

## Steps to Enable SSH

### Step 1: Generate an SSH key pair on your PC

> You can leave the passphrase empty if you want.

- On Linux/MacOS:

    ```bash
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa
    ```

- On Windows:

    ```cmd
    ssh-keygen -t rsa -b 2048
    ```

    The `id_rsa.pub` file can be found at `%USERPROFILE%\.ssh\id_rsa.pub`.

**Once the keys are generated, copy the content of id_rsa.pub to the authorized_keys file in `get-ssh` folder of the cloned repo.**

### Step 2: Push the get-ssh folder using adb

Push the `get-ssh` folder of the cloned repo to the `/tmp` directory of the ODU using ADB.

```bash
adb push get-ssh/ /tmp/
```

### Step 3: Run the `run.sh` script in adb shell

```bash
adb shell
```

In adb shell run the command

```bash
cd /tmp/get-ssh/ && chmod +x run.sh && ./run.sh
```

You can now SSH into the ODU either directly from it's IPv4 address if you are in (Router Mode/Bridge Mode/Connected to ODU directly) OR instead a better way to access the ODU ssh would be using SSH Tunnel which we use for accessing the ODU WEB-UI. Just change the destination ports from 443 to 22 and change 8443 to any free port on your (PC/local device) being used to access the ODU.

After establishing a SSH tunnel, proceed with the below command to access the ODU.

```bash
ssh root@localhost -P <whatever_port_you_used_instead_of_8443>
```

# Single Command Tunnel for OpenWrt

**UPD** the OpenWrt feed now has the `cloudflared` package and Luci Application `luci-app-cloudflared` that provides a GUI for configuration.
You can install them with the command `opkg install cloudflared luci-app-cloudflared`

### You want to expose a device in your local network to the Internet? Easy.

This script simplifies the process of setting up a Cloudflare Tunnel on an OpenWrt router. It allows you to run Cloudflared Tunnel on your router without needing to permanently install the large Cloudflared package, making it suitable for routers with limited storage. Access your home network, server, or database from anywhere. Fast, easy, and free!

## Prerequisites

- An OpenWrt router with SSH access.
- Optional (if you need a custom domain): A free Cloudflare account with a connected domain

## Usage (without a Cloudflare Account)

1. SSH into your OpenWrt router as the root user:

   ```sh
   ssh root@<your-openwrt-ip>
   ```

2. Copy and execute the following command (adjust the `--url` parameter for your needs)

   ```sh
   wget -qO- https://raw.githubusercontent.com/adshrc/openwrt-cloudflared/main/script.sh | ash -s -- --url=http://<device-ip>:80
   ```
`<device-ip>` is your Device's IP Address, that you are builing a Tunnel to. E.g. `192.168.1.10`.

That's it! Just copy the `*.trycloudflare.com` sub-domain you get from the script and enjoy!

## Usage (with a Cloudflare Account and custom Domain)

1. SSH into your OpenWrt router as the root user:

   ```sh
   ssh root@<your-openwrt-ip>
   ```

2. Copy and execute the following command:

    ```sh
     wget -qO- https://raw.githubusercontent.com/adshrc/openwrt-cloudflared/main/script.sh | ash -s -- -l
     ```

3. The script will automatically set up a Cloudflare Tunnel. If you are executing it for the first time, you will need to log in to your Cloudflare account when prompted. After successful login, the script will create a Cloudflare Tunnel named "openwrt".

4. After a few seconds, check your Cloudflare Dashboard. You should see the "HEALTHY" status for the tunnel "openwrt":

   ![image](https://user-images.githubusercontent.com/16599151/269317318-795b6104-c2b0-4a57-9268-1f0450d161ad.png)

5. In the Cloudflare Dashboard, click "configure" to "migrate" the tunnel. This allows you to manage various aspects from the Dashboard, eliminating the need to update configuration files manually.

   ![image](https://github.com/adshrc/openwrt-cloudflared/assets/16599151/521058a9-3c74-48b9-9f61-881a8fe85181)

6. Add a public hostname and enjoy!

7. To start the Cloudflare Tunnel after a router restart or to automate the process, run the command provided by the script. It looks like this:

   ```sh
   wget -qO- https://raw.githubusercontent.com/adshrc/openwrt-cloudflared/main/script.sh | ash -s -- --import="<base64_config_string>"
   ```

   You will see a link, where `<base64_config_string>` is already attached to the command above. Just copy and use later again!

## Options

- `-l`: Start the script with Cloudflare login (Domain + Account required).
- `--import=<base64_config_string>`: Import a Cloudflared configuration from a base64-encoded string.
- `--url=<tunnel_url>`: Specify a custom tunnel URL when starting the Quick tunnel.

## Notes

- This setup is not persistent, and you need to repeat these steps after restarting your router.
- You can automate the setup by adding the provided command to a start script on your router.


## License

This project is licensed under the GNU General Public License v3.0 License - see the [LICENSE](LICENSE) file for details.

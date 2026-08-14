**Note: This is a personal project I have adapted for a local group and therefore will not be providing any support. Feel free to use this project for your own media server but be aware that it is mainly configured for my own needs and may not be updated. This guide assumes a basic familiarity with Linux which is the only platform supported currently.**



This contains everything you'll need to get a server up and running with Navidrome and SLSKD along with Caddy as your reverse proxy. It will also keep your IP address updated with Cloudflare so that you don't need to manage this yourself. Lastly it leverages Beets as a music library manager/importer to automatically move files and tag them.

There are a "couple" of setup steps you'll need to take:

First, make sure you have either Docker and the "docker-compose" package installed, or Podman and the "podman-docker" package. I personally use Podman but that's due to my interminable need to be different from everyone. Both should have a pretty good gui, I like Podman Desktop. If you're running this in Podman, the compose file will create a pod which allows you to start, stop, restart, etc. all of its containers at once. Podman also allows creating "quadlets", which will run your containers as a systemctl service and will allow them to start at boot. Quadlets are complicated and kind of annoying, we won't be covering them here.

Owning a domain isn't necessary for the project to work but is a good way to get your services online and access them from outside the home. Other options are to use your router's firmware to forward the ports for each container to your server. They're listed below. You can also use services like Tailscale, which will allow you access to your home network from outside. You can set up a tunnel with Cloudflare as well. Any option has its drawbacks and risks, you're either exposing services to the outside world or you're having to install additional software on your other devices. Just be careful not to expose a service you don't trust. If you're not going to use a domain, which is what this project covers, comment out the Caddy and Cloudflare-DDNS containers in the docker-compose.yaml file. This is done by placing a "#" before every line belonging to these sections.

If you're using a domain you'll of course need to obtain one, if you want something free I suggest DigitalPlat (https://domain.digitalplat.org/). Then follow these steps to set up your DNS records through Cloudflare, unless you want to be in charge of your own DNS records (https://github.com/DigitalPlatDev/FreeDomain/blob/main/documents/tutorial/getting-started/1.2-dns-hosting.md). You'll need to add A and AAAA DNS records for your public-facing IP addresses, which can be found at whatismyip.com (A is for IPV4, AAAA is for IPV6).

Next, in the Cloudflare dashboard, you'll also need to add some CNAME DNS records. In the "name" field, enter the subdomain you'd like to use for your service (I use shorthand, such as "navi" for Navidrome or "jelly" for Jellyfin, which we're not setting up in this tutorial). The next box should contain your domain (i.e. "example.com"). Leave proxying on, this will help hide your actual IP address and it should expose one of Cloudflare's instead.

You're going to need to add these subdomains to Caddy now. Go into the "caddy" folder and open Caddyfile in a text editor (this is case-sensitive). Enter your Cloudflare API key where shown (this can be found at the page linked in the document). Follow the examples to assign each subdomain to a container (replace "container_name") and its *internal* port. For example, SLSKD uses "5030" as its internal port, you can forward a different one from your machine but you won't enter that here. The internal port for each container can be seen in docker-compose.yaml, it's in the format "external:internal" under the "ports" section.
Services you're running outside of a container will require "host.docker.internal" as the hostname for that service (see the Caddyfile for an example).
Next, using your router's administration interface, forward ports 8000 and 8443 to the machine hosting the server. These will be passed to Caddy without you having to open some low ports on your machine (which isn't a great idea and requires hacky workarounds to do as a standard, non-root user).

Open the "secrets" folder and edit the env files with any relevant information. You'll need your Cloudflare API token, directions on how to obtain this are available on the page linked in the document. You'll also be setting up your SLSKD webUI login and your Soulseek network login here.

Next, go back and open the "webhook" folder. This is what will handle automatic Beets imports from SLSKD. When a directory finishes, SLSKD sends a web request to your machine (at least if you're using my config). That will trigger webhook to run directory-finished.sh, which will locate the downloaded directory and ask Beets to import it. You'll need to edit directory-finished.sh to point to the directory where SLSKD saves your downloads. You'll also need to edit hooks.yaml to point to the full path of directory-finished.sh, i.e. the "webhook" folder inside of wherever this project is kept. Then in the terminal, "sudo mkdir -p /etc/webhook" and run "sudo cp ./ hooks.yaml /etc/webhook/hooks.yaml" in the directory that contains it. If you like, you can also edit the webhook.service file to point to a different location for hooks.yaml. Feel free to add your own webhooks to hooks.yaml if you like, you can use something like notify-send to create a notification when a download is complete.

You'll need to edit webhook.service as well. Fill in the user and group (your own username, the group you'll want to use is most likely your username as well) that you want the service to run as. Then, while still in the webhook directory, run "systemctl --user enable --now ./webhook.socket" and "systemctl --user enable --now ./webhook.service". As long as your Linux distribution uses systemd this should cause these to run when you log in. If yours doesn't... well, you're probably aware of how to create services for your system and can adapt these.
Download the latest webhook binary from https://github.com/adnanh/webhook/releases/. Now either add the directory containing the webhook binary to your path, or "sudo cp" it into a place that is in the path like /bin or ~/.local/bin.

Webhook sometimes stops responding. This is annoying. I like to add a cron job to restart it: run "crontab -e", and in the file that opens add "@hourly systemctl --user restart webhook.service". Add another line: "@hourly systemctl --user restart webhook.socket". Save the file and exit. This should hopefully solve the issue.

You may want to make some changes to navidrome.toml in your "navidrome" folder. I have it set up the way I like it but your preferences may differ. You'll probably at least want to change the value of "PasswordEncryptionKey". Configuration options can be found at https://www.navidrome.org/docs/usage/configuration/options/.

Now we're going back to the parent directory to deal with docker-compose.yaml. This file will work whether you have Docker or Podman installed. In this file, you'll need to do one of two things:

1) replace any instance of "Music" under a container's volume header with your music library directory and "Downloads" (watch the case on both of these, only replace those starting with a capital letter) with your downloads directory. I don't use my user/Downloads folder for this because SLSKD can leave empty folders and clutter things up. You'll then need to remove the following lines from docker-compose.yaml:
  Downloads:
    external: true
  Music:
    external: true

2) use your container engine's volumes command to bind these volumes to a local folder. (If you're using podman you'll first need to run "podman unshare") Then run "docker/podman volume mount [volume name, i.e. Downloads] [folder location, i.e. /home/liana/Music/Downloads]". The "Downloads" folder is where slskd will save completed files, the "Music" folder is the location of your music library (i.e. /home/liana/Music or something like /mnt/Media/Music if you're keeping this on a second hard drive).

Finally, you'll need to run "docker/podman volume create caddy_data". If something goes wrong with your setup down the line, it may be necessary to tell your container engine to delete this volume and recreate it.

So! That should be all the messing around in config files that you'll have to do to get this running. In the directory containing docker-compose.yaml, run "docker compose up -d" or "podman compose up -d". This command starts the containers and runs them in the background. You'll probably need to choose the host for a few of these containers, and if it complains about a container not existing then try to run it again after they've been downloaded. This file will bring up containers for SLSKD, Navidrome, Cloudflare-DDNS, and Caddy.

If you're using podman, one last step to get these containers to start automatically when you log in: in the terminal, run "systemctl --user enable --now podman-restart.service". Since there is a restart policy ("unless-stopped") set in our compose file, podman should start the containers for you. Again, this only works if your distribution is using systemd but if yours isn't you probably already know how to handle this.

You can visit your services at the subdomains you set up, or on your local network at the following ports:
SLSKD: (localhost or IP of server):5030
Navidrome: (localhost or IP of server):4533

Navidrome will have you create an admin account the first time you access it. Be sure to look through the configuration files and set SLSKD and Navidrome up the way you want them.

Download Beets (https://beets.io/), set it up the way you like it which is outside the scope of this tutorial because it's a highly-configurable program and there are many plugins available. I do recommend doing it through pipx for a global install ("sudo pipx install --global beets"). You can then use "sudo pipx inject --global beets [plugin name]" to add third-party plugins to beets. Read its documentation here: https://beets.readthedocs.io/en/stable/. There's a lot of good information on how to set up your config file, how to use and configure each plugin, etc. Beets is a really cool platform and has some very powerful capabilities. I've included an example config which uses a lot of plugins, be sure to read their documentation. If you'd like to use the same plugins you'll need to run "sudo pipx inject --global beets [plugin name]" on each of the following: 
      - beetcamp
      - beets-check
      - beets-describe
      - beets-extended-metadata
      - beets-filetote
      - beets-lyrics-manager
      - beets-tcp (for this one, inject "git+https://github.com/trapd00r/beets-tcp")
      - beets-yearfixer


Beets can be used to manage or query your library as well as the import step we're using it for. It's very cool! I've also included "timid.yaml". This is in case Beets doesn't automatically import something. Copy it into your "[home directory]/.config/beets" folder along with the example config. You can run "beet -c '[home directory]/.config/beets/timid.yaml' import" on the directory in question and it should prompt you to make a selection rather than just skipping the folder. I recommend creating an alias for this, like "beet-skipped".

Don't pull your hair out troubleshooting anything that's going wrong. You might be running into permissions issues, the bane of my time working with containers. Google any error messages you come across, check your logs, etc. These things can be fickle but it's good to learn how to deal with the isses that do crop up.

Have fun!


Projects used here:
Beets (https://github.com/beetbox/beets)
Caddy (https://github.com/caddyserver/caddy)
Cloudflare DDNS (https://github.com/favonia/cloudflare-ddns)
Navidrome (https://github.com/navidrome/navidrome)
SLSKD (https://github.com/slskd/slskd)

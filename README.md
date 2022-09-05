# minictinit.sh
`minictinit.sh` is a simple init script for use with LXC containers based on Debian/Ubuntu. It helps to prepare containers in virtualization systems, such as [ProxMox VE](https://github.com/proxmox). Basically, it's [cloudinit](https://github.com/canonical/cloud-init) with only one config source (command line) and infnitely less features. `minictinit.sh` can be used for:
* initial image configuration
  * update system
  * add apt sources
  * add/remove packages
* first time boot configuration
  * SSH configuration (create host keys, enable root login, enable service)
  * Zabbix agent configuration (configure autoregistration, limit log file size)
  * default editor in /etc/bash.bashrc

Initial image configuration is run from a command line. First time boot configuration is done by a systemd service.

## Sample usage
In ProxMox VE, download Ubuntu or Debian-based container template, create an LXC container and follow the steps below.
### Prepare software in container
Download minictinit.sh by wget or just paste the source into file and make it executable:

    wget 'https://raw.githubusercontent.com/alkalim/minictinit/master/minictinit.sh' && chmod u+x ./minictinit.sh

Prepare software in the container by running `minictinit.sh prepare`:

    ./minictinit.sh prepare 'pkgrm(postfix),pkgadd(curl),repoadd(https://repo.example.com/download/repo.deb),update'

### Installation
Install the init service. It will be run only once on a first boot:

    ./minictinit.sh install "ssh,zabbix(zbx.example.com),editor(/usr/bin/vi)"

Remove the working copy of `minictinit.sh` (install command copied the script to `/usr/bin`):

    rm ./minictinit.sh

Convert the container to container template. Now your template is cloneable. Every time you clone the template and run it for the first time it will configure host ssh keys, enable ssh, configure Zabbix agent and set the default editor to vi.

## Reference

<pre>
Usage: minictinit.sh &lt;command>
    Initialization script for LXC-based Debian/Ubuntu containers

Commands:
    prepare              - prepare system by executing &lt;functions&gt;
    install &lt;functions&gt;  - install systemd service with &lt;functions&gt;
    start &lt;functions&gt;    - start service (should be run by systemd)
    uninstall            - remove systemd service

Functions for "prepare":
    pkgadd(&lt;package&gt;)          - install &lt;package&gt;
    pkgrm(&lt;package&gt;)           - remove &lt;package&gt;
    repoadd(&lt;repo_url&gt;)        - add &lt;repo_url&gt; to apt sources
    upgrade                    - upgrade packages

Functions for "install" / "start":
    ssh                        - configure ssh (keys, root user, service)
    zabbix(&lt;server_ip&gt;)        - configure Zabbix agent (autoregistration,
                                 server ip, log limit)
    editor(&lt;path_to_editor&gt;)   - set default editor in /etc/bash.bashrc

Examples:
$ ./minictinit.sh prepare 'pkgrm(postfix),pkgrm(nano),pkgadd(curl),upgrade'
$ ./minictinit.sh install 'ssh,zabbix(zbx.example.com),editor(/usr/bin/vi)'
</pre>

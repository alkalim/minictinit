#!/usr/bin/env bash
#
# minictinit.sh - mini container init
#
# Simple script to init ProxMox LXC container clones
# that are based on Debian/Ubuntu
#

flag_file=/var/lib/myctinit.flag
log_file=/var/log/minictinit.log
ssh_key=/etc/ssh/ssh_host_dsa_key
service_file=/etc/systemd/system/minictinit.service
run_dir=/usr/bin
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
target_exe_file=$run_dir/$BASH_SOURCE
zabbix_conf=/etc/zabbix/zabbix_agentd.conf
zabbix_conf_dir=/etc/zabbix/zabbix_agentd.conf.d

function log
{
    echo $(date "+%Y/%m/%d %H:%M:%S ") $@ >> $log_file
}

function die
{
    echo -n "fatal: "
    echo $@
    exit -1
}

function usage
{
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") <command>
    Initialization script for LXC-based Debian/Ubuntu containers

Commands:
    prepare              - prepare system by executing <functions>
    install <functions>  - install systemd service with <functions>
    start <functions>    - start service (should be run by systemd)
    uninstall            - remove systemd service

Functions for "prepare":
    pkgadd(<package>)          - install <package>
    pkgrm(<package>)           - remove <package>
    repoadd(<repo_url>)        - add <repo_url> to apt sources
    upgrade                    - upgrade packages

Functions for "install" / "start":
    ssh                        - configure ssh (keys, root user, service)
    zabbix(<server_ip>)        - configure Zabbix agent (autoregistration,
                                 server ip, log limit)
    editor(<path_to_editor>)   - set default editor in /etc/bash.bashrc

Examples:
$ ./minictinit.sh prepare 'pkgrm(postfix),pkgrm(nano),pkgadd(curl),upgrade'
$ ./minictinit.sh install 'ssh,zabbix(zbx.example.com),editor(/usr/bin/vi)'

EOF
    exit
}

function parse_func_arg
{
    echo $(echo $@|sed -e '/(/!d' -e '/)/!d' -e 's/^.*(\(.*\))/\1/')
}

function start
{
    IFS=',' read -ra funcs <<< "$1"

    for func in "${funcs[@]}"; do
        case $func in
            ssh)
                log "recreate ssh host keys"
                if [ ! -f "$ssh_key" ]; then 
                    log "$ssh_key not found, running dpkg-reconfigure"
                    dpkg-reconfigure openssh-server
                fi
                log "enable ssh root access"
                ssh_config="/etc/ssh/sshd_config"
                if [ -f "$ssh_config" ]; then
                    sed -i "s/#PermitRootLogin /PermitRootLogin /" $ssh_config
                fi
                systemctl stop ssh
                systemctl enable --now ssh
                ;;
            editor*)
                editor=$(parse_func_arg $func)
                cat >>/etc/bash.bashrc <<EOF
# added by minictinit.sh
export EDITOR=$editor
export VISUAL=\$EDITOR
# end of minitctinit.sh changes
EOF
                ;;
            zabbix*)
                log "configuring Zabbix agent"
                if [ -f "$zabbix_conf" ]; then
                    server_ip=$(parse_func_arg $func)
                    sed -i "s/^Hostname=\(.*\)/# Hostname=\1/" $zabbix_conf
                    sed -i "s/^LogFileSize=0/LogFileSize=5/" $zabbix_conf
                    sed -i "s/^Server=127.0.0.1/Server=$server_ip/" $zabbix_conf
                    sed -i "s/^ServerActive=127.0.0.1/ServerActive=$server_ip/" $zabbix_conf
                    sed -i "s/# HostnameItem=system.hostname/HostnameItem=system.hostname/" $zabbix_conf
                    sed -i "s/# HostMetadataItem=/HostMetadataItem=minictinit.metadata/" $zabbix_conf
                    cat > /etc/zabbix/zabbix_agentd.d/minictinit.conf <<EOF
# added by minictinit.sh
UserParameter=minictinit.metadata,echo Linux-pm-\$(cat /etc/machine-id)
# end of minitctinit.sh changes
EOF
                    systemctl restart zabbix-agent.service
                else
                    log "$zabbix_conf doesn't exist"
                fi
                ;;
            *)
                die "unknown function: $func"
                ;;
        esac
    done

    if [ -f "$flag_file" ]; then
        log "found $flag_file, exiting"
        exit
    fi

    log "creating $flag_file"
    >$flag_file

    exit
}

function install
{
    funcs=$1
    if [ -z "$funcs" ]; then
        funcs="ssh,zabbix(127.0.0.1),editor(/usr/bin/vi)"
    fi

    log "installing systemd service with functions $funcs"

    # Create systemd unit file
    cat >$service_file <<EOF
[Unit]
Description=Mini Container Init Script
After=network.target

[Service]
ExecStart=$target_exe_file start $funcs

[Install]
WantedBy=multi-user.target
EOF

    # copy self to run dir
    [ -d "$run_dir" ] || die "can not find $run_dir"
    sudo cp "$script_dir/$BASH_SOURCE" $target_exe_file
    sudo chmod a+x "$target_exe_file"

    # recondigure systemd and start service
    sudo systemctl daemon-reload

    exit
}

function prepare
{
    if [ -z "$1" ]; then
        usage
    fi

    if which wget >/dev/null; then
        log "wget found"
    else
        log "wget not found, installing"
        apt-get update
        apt-get install -y wget
    fi

    log "preparing system with functions $funcs"

    IFS=',' read -ra funcs <<< "$1"

    for func in "${funcs[@]}"; do
        case $func in
            pkgadd*)
                pkg=$(parse_func_arg $func)
                log "adding package $pkg"
                apt install -y $pkg
                ;;
            pkgrm*)
                pkg=$(parse_func_arg $func)
                log "removing package $pkg"
                apt remove --purge -y $pkg
                ;;
            repo*)
                repourl=$(parse_func_arg $func)
                log "adding repo $repourl"
                tmppkg=$(mktemp)
                wget -q -O $tmppkg $repourl && dpkg -i $tmppkg && rm -f $tmppkg && apt update -y
                ;;
            upgrade)
                log "upgrading packages"
                apt update -y && apt dist-upgrade -y && apt autoremove -y
                ;;
            *)
                die "unknown function: $func"
                ;;
        esac
    done

    exit
}

function uninstall()
{
    if [ -f $service_file ]; then
        log "removing $service_file,$target_exe_file,$flag_file"
        sudo rm -f $service_file $target_exe_file $flag_file
        # recondigure systemd
        sudo systemctl daemon-reload
        echo "removed $service_file and other files"
    else
        echo "$service_file not found"
    fi

    exit
}

function check_distro
{
    if [ $(uname) != "Linux" ]; then
        die "not running under Linux"
    fi

    egrep -qi 'ubuntu|debian' /etc/*release
    if [ $? -ne 0 ]; then
        die "not running under Debian/Ubuntu"
    fi
}

check_distro

while [ $# -gt 0 ]; do
    case $1 in
        install)
            shift
            install $1
            ;;
        prepare)
            shift
            prepare $1
            ;;
        start)
            shift
            start $1
            ;;
        uninstall)
            shift
            uninstall
            ;;
        *)
            usage
    esac
done

usage

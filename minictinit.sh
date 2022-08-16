#!/usr/bin/env bash
#
# minictinit.sh - mini container init
#
# Simple script to init ProxMox LXC containers
# based on Debian/Ubuntu
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

function log()
{
    echo $(date "+%Y%m%d %H:%M:%S ") $@ >> $log_file
}

function die()
{
    echo -n "fatal: "
    echo $@
    exit -1
}

function usage()
{
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") install | start [<functions>]| uninstall
    Container initialization script
Commands:
    install     - install systemd service
    start       - start service (should be run by systemd)
    uninstall   - remove systemd service
Functions:
    ssh         - recreate ssh host keys
    zabbix      - add zabbix autoregistration settings
EOF
    exit
}

function start()
{
    IFS=',' read -ra funcs <<< "$funcs"

    for func in "${funcs[@]}"; do
        echo $func
    done

    case $func in
        ssh)
            log "recreate ssh host keys"
            if [ ! -f "$ssh_key" ]; then 
                log "$ssh_key not found, running dpkg-reconfigure"
                dpkg-reconfigure openssh-server
            fi
            ;;
        zabbix)
            log "add zabbix autoregistration settings"
            sed -i "s/^Hostname=\(.*\)/# Hostname=\1/" $zabbix_conf
            ;;
        *)
            die "unknown function: $func"
            ;;
    esac

    if [ -f "$flag_file" ]; then
        log "found $flag_file, exiting"
        exit
    fi

    log "creating $flag_file"
    >$flag_file

    exit
}

function install()
{
    funcs=$1
    if [ -z "$funcs" ]; then
        funcs="ssh,zabbix"
    fi

    # Create systemd unit file
    cat >$service_file <<EOF
[Unit]
Description=Mini Container Init Script

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

function uninstall()
{
    if [ -f $service_file ]; then
        log "Removing $service_file,$target_exe_file,$flag_file"
        sudo rm -f $service_file $target_exe_file $flag_file

        # recondigure systemd
        sudo systemctl daemon-reload

        echo "removed $service_file and other files"
    else
        echo "$service_file not found"
    fi

    exit
}

function check_distro()
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

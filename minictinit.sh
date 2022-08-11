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
Usage: $(basename "${BASH_SOURCE[0]}") install | start | uninstall
Commands:
    install     - install systemd service
    start       - start service (should be run by systemd)
    uninstall   - remove systemd service
EOF
    exit
}

function start()
{
    if [ -f "$flag_file" ]; then
        log "Found $flag_file, exiting"
        exit
    fi

    if [ ! -f "$ssh_key" ]; then 
        log "$ssh_key not found, running dpkg-reconfigure"
        dpkg-reconfigure openssh-server
    fi

    log "Creating $flag_file"
    >$flag_file

    exit
}

function install()
{
    # Create systemd unit file
    cat >$service_file <<EOF
[Unit]
Description=Mini Container Init Script

[Service]
ExecStart=$target_exe_file start

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
            install
            ;;
        start)
            shift
            start
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

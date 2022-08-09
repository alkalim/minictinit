#!/usr/bin/env bash

flag_file=/run/myctinit.flag
log_file=/tmp/minictinit.log
ssh_key=/etc/ssh/ssh_host_dsa_key
service_file=/etc/systemd/system/minictinit.service
run_dir=/run
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

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
Usage: $(basename "${BASH_SOURCE[0]}") install | start
Commands:
    install     - install systemd service
    start       - start service (should be run by systemd)
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
}

function install()
{
    # Create systemd unit file
    cat >$service_file <<EOF
[Unit]
Description=Mini Container Init Script

[Service]
ExecStart=$run_dir/minictinit.sh start

[Install]
WantedBy=multi-user.target
EOF

    # copy self to run dir
    [ -d "$run_dir" ] || die "can not find $run_dir"
    sudo cp "$script_dir/$BASH_SOURCE" $run_dir
    sudo chmod a+x "$run_dir/$BASH_SOURCE"

    # recondigure systemd and start service
    sudo systemctl daemon-reload
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
        *)
            usage
    esac
done

usage

#! /bin/sh
#

torify=proxychains

username="$1"

# input file
if [ "$2" = "-" ]; then
    # stdin
    infile=
else
    # servers.txt
    infile=servers.txt
fi

execute() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    cmd=$*

    timeout 30 sshpass -p "$pass" "$torify" ssh -o StrictHostKeyChecking=no -p "$port" \
        "$user@$ip" "echo $cmd | /bin/sh -s -" 2>/dev/null
}

copyto() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    what=$1; shift
    where=$1;

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$what" "$user@$ip:$where" 2>/dev/null
}

copyfrom() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    what=$1; shift
    where=$1

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$user@$ip:$what" "$where" 2>/dev/null
}

deploy() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift

    # Credentials for a VPS
    creds="$ip $user $pass $port"
    # Installer TCL script params (params for openvpn-install.sh)
    tclparms="$username"

    # Copy ovpn-adduser.tcl to server
    echo -n "Copy ovpn-adduser.tcl to server... "
    copyto $creds ovpn-adduser.tcl "/root"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Start OpenVPN installer
    echo -n "Start OpenVPN installer... "
    execute $creds "/usr/bin/expect -f ovpn-adduser.tcl $tclparms"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Copy config file to local machine
    echo -n "Copy config file to local machine... "
    copyfrom $creds /root/$username.ovpn `pwd`/files/
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi
}

cat $infile | grep -v '^#' | grep -v '^$' | sed -e "s/\s+#.*$//" | \
\
while read line; do
    deploy $line
done | tee log.txt

exit 0

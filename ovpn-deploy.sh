#! /bin/sh
#

torify=proxychains

# input file
if [ "$1" = "-" ]; then
    # stdin
    infile=&0
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
        "$user@$ip" "echo $cmd | /bin/sh -s -" #2>/dev/null
}

copyto() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    what=$1; shift
    where=$1;

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$what" "$user@$ip:$where" #2>/dev/null
}

copyfrom() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    what=$1; shift
    where=$1;

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$user@$ip:$what" "$where" #2>/dev/null
}

deploy() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift

    ovpnip=$1; shift
    ovpnip6=$1; shift
    ovpnport=$1; shift
    ovpnproto=$1; shift
    ovpndns=$1; shift

    # Credentials for a VPS
    creds="$ip $user $pass $port"
    # Installer TCL script params (params for openvpn-install.sh)
    tclparms="$ovpnip $ovpnip6 $ovpnport $ovpnproto $ovpndns"

    # Copy openvpn-install.sh to server
    copyto $creds openvpn-install.sh "/root"
    # Copy ovpn-inst.tcl to server
    copyto $creds ovpn-inst.tcl "/root"

    # Install software
    cmd="apt install mc nano screen net-tools psmisc wget curl expect -y"
    execute $creds $cmd

    # Start OpenVPN installer
    execute $creds "/usr/bin/expect -f ovpn-inst.tcl $tclparms"
}

cat $infile | grep -v '^#' | grep -v '^$' | sed -e "s/\s+#.*$//" | \
\
while read line; do
    deploy $line
done | tee log.txt

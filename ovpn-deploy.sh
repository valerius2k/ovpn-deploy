#! /bin/sh
#

torify=proxychains

# input file
if [ "$1" = "-" ]; then
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
    where=$1;

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$user@$ip:$what" "$where" 2>/dev/null
}

deploy() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift

    domainweb=$1; shift
    portweb=$1; shift
    domainvpn=$1; shift
    portvpn=$1; shift

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
    echo -n "Copy openvpn-install.sh to server... "
    copyto $creds openvpn-install.sh "/root"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Copy ovpn-inst.tcl to server
    echo -n "Copy ovpn-inst.tcl to server... "
    copyto $creds ovpn-inst.tcl "/root"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Copy letsencrypt.tcl to server
    echo -n "Copy letsencrypt.tcl to server... "
    copyto $creds letsencrypt.tcl "/root"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Install software
    cmd="apt install mc nano screen net-tools psmisc wget \
         curl expect nginx ssl-cert certbot -y"
    echo -n "Install software... "
    execute $creds $cmd
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Start OpenVPN installer
    echo -n "Start OpenVPN installer... "
    execute $creds "/usr/bin/expect -f ovpn-inst.tcl $tclparms"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Change IP of ovpn server to $domainvpn
    echo -n "Change IP of ovpn server to $domainvpn #1... "
    execute $creds "sed -i /etc/openvpn/client-common.txt -e 's/[0-9]\\\{1,3\\\}\\\.[0-9]\\\{1,3\\\}\\\.[0-9]\\\{1,3\\\}\\\.[0-9]\\\{1,3\\\}/$domainvpn/'"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    echo -n "Change IP of ovpn server to $domainvpn #2... "
    execute $creds "sed -i /root/client.ovpn -e 's/[0-9]\\\{1,3\\\}\\\.[0-9]\\\{1,3\\\}\\\.[0-9]\\\{1,3\\\}\\\.[0-9]\\\{1,3\\\}/$domainvpn/'"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Copy Nginx main config file
    echo -n "Copy Nginx main config file... "
    copyto $creds files/nginx/nginx.conf /etc/nginx
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Copy default Nginx config
    echo -n "Copy default Nginx config... "
    cp files/nginx/sites-available/default.tmpl /tmp/default
    sed -i /tmp/default \
        -e "s/{{ port_web }}/$portweb/g" \
        -e "s/{{ domain_web }}/$domainweb/g"
    copyto $creds /tmp/default /etc/nginx/sites-available
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Copy stream.conf
    echo -n "Copy stream.conf... "
    cp files/nginx/stream.conf.tmpl /tmp/stream.conf
    sed -i /tmp/stream.conf \
        -e "s/{{ domain_web }}/$domainweb/g" \
        -e "s/{{ domain_vpn }}/$domainvpn/g" \
        -e "s/{{ port_web }}/$portweb/g" \
        -e "s/{{ port_vpn }}/$portvpn/g"
    copyto $creds /tmp/stream.conf /etc/nginx
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Start make-ssl-cert
    echo -n "Start make-ssl-cert... "
    execute $creds "make-ssl-cert generate-default-snakeoil"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Remove /etc/letsencrypt directory (if exists)
    echo -n "Remove /etc/letsencrypt directory (if exists)... "
    #execute $creds "rm -rf /etc/letsencrypt"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Create a Let's Encrypt cert
    echo -n "Create a Let's Encrypt cert... "
    execute $creds "/usr/bin/expect -f letsencrypt.tcl $domainweb $domainvpn"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Change certs snakeoil to Let's Encrypt
    echo -n "Change certs snakeoil to Let's Encrypt... "
    execute $creds "mv /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-cert-snakeoil.pem~; \
        mv /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil.key~; \
        ln -sf /etc/letsencrypt/live/$domainweb/fullchain.pem /etc/ssl/certs/ssl-cert-snakeoil.pem; \
        ln -sf /etc/letsencrypt/live/$domainweb/privkey.pem /etc/ssl/private/ssl-cert-snakeoil.key"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Set iptables rules
    echo -n "Set iptables rules... "
    cp files/systemd/system/openvpn-iptables.service.tmpl /tmp/openvpn-iptables.service
    sed -i /tmp/openvpn-iptables.service \
        -e "s/{{ ovpn_ip }}/$ovpnip/g" \
        -e "s/{{ ovpn_proto }}/$ovpnproto/g" \
        -e "s/{{ port }}/$port/g"
    copyto $creds /tmp/openvpn-iptables.service /etc/systemd/system
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Restart Nginx
    echo -n "Restart Nginx... "
    execute $creds "systemctl daemon-reload"
    execute $creds "systemctl restart nginx"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Restart OpenVPN
    echo -n "Restart OpenVPN... "
    execute $creds "systemctl restart openvpn"
    rc="$?"

    if [ "$rc" -ne "0" ]; then
        echo "rc=$rc"
        exit 1
    else
        echo "ok"
    fi

    # Restart firewall rules
    echo -n "Restart firewall rules... "
    execute $creds "systemctl restart openvpn-iptables"
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

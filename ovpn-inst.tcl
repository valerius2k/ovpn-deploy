#! /usr/bin/expect
#

#exp_internal 1

set removed 0
set ip      "1"
set ip6     "1"
set ipaddr  [lindex $argv 0]
set ip6addr [lindex $argv 1]
set dns     [lindex $argv 4]

if { $argc != 5 } {
    puts "You need to specify two arguments to this script:\n"
    puts "<ip> <ip6> <port> <protocol> <dns>"
    exit 1
}


while (1) {
    spawn /bin/sh -c "cd /root; ./openvpn-install.sh"

    while (1) {
        expect {
            "Option: " {
                # удалить OpenVPN (потом переустановим снова)
                send "3\n"
            }
            "Confirm OpenVPN removal?" {
                # Флаг, означающий, что мы удалили OpenVPN
                set removed 1
                send "y\n"
            }
            "  Confirm removal: " { send "yes\n" }
            -re {     ([0-9]+)\) ([a-fA-F0-9:]+)} {
                if { "$expect_out(2,string)" == "$ip6addr" } {
                    set ip6 "$expect_out(1,string)"
                }
            }
            "IPv6 address \\\[" {
                send "$ip6\n"
            }
            -re {     ([0-9]+)\) ([0-9.]+)} {
                if { "$expect_out(2,string)" == "$ipaddr" } {
                    set ip "$expect_out(1,string)"
                }
            }
            "IPv4 address \\\[" {
                # ipv4 IP, 1-й параметр
                send "$ip\n"
            }
            "Public IPv4 address" { send "\n" }
            "Protocol " {
                # Протокол, 3-й параметр
                # udp/tcp: 1/2
                set proto "1"
                if { [lindex $argv 3] == "tcp" } { set proto "2" }
                send "$proto\n"
            }
            "Port " {
                # Порт, 2-й параметр
                set port [lindex $argv 2]
                send "$port\n"
            }
            -re { *([0-9]+)\) ([a-zA-Z0-9.]+)} {
                if { "$expect_out(2,string)" == "$dns" } {
                    set ip "$expect_out(1,string)"
                }
            }
            "DNS server \\\[" {
                send "$ip\n"
            }
            "Name " { send "client\n" }
            "Press any key to continue" { send "\n" }
            eof { break }
        }
    }

    if ($removed) {
        # Если мы только что удалили OpenVPN,
        # значит рестартуем установку с начала
        set removed 0
        continue
    } else {
        # прервать внешний цикл
        break
    }
}

exit 0

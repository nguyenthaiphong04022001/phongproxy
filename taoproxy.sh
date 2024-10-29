#!/bin/sh

# Hàm tạo chuỗi ngẫu nhiên
random() {
  tr </dev/urandom -dc A-Za-z0-9 | head -c5
  echo
}

# Hàm cài đặt 3proxy
install_3proxy() {
  echo "Đang cài đặt 3proxy"
  URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
  wget -qO- $URL | bsdtar -xvf-
  cd 3proxy-3proxy-0.8.6
  make -f Makefile.Linux
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
  cp src/3proxy /usr/local/etc/3proxy/bin/
  cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
  chmod +x /etc/init.d/3proxy
  chkconfig 3proxy on
  cd $WORKDIR
}

# Tạo file cấu hình cho 3proxy
gen_3proxy() {
  cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -n -a -p" $4 " -i" $3 "\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Tạo file proxy.txt cho người dùng
gen_proxy_file_for_user() {
  cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Upload file proxy lên file.io
upload_2file() {
  local PASS=$(random)
  zip --password $PASS proxy.zip proxy.txt
  JSON=$(curl -F "file=@proxy.zip" https://file.io)
  URL=$(echo "$JSON" | jq --raw-output '.link')

  echo "Proxy đã sẵn sàng! Định dạng IP:PORT:LOGIN:PASS"
  echo "Download zip archive từ: ${URL}"
  echo "Password: ${PASS}"
}

# Tạo dữ liệu proxy
gen_data() {
  seq $FIRST_PORT $LAST_PORT | while read port; do
    echo "usr$(random)/pass$(random)/$IP4/$port"
  done
}

# Tạo cấu hình iptables để mở cổng cho proxy
gen_iptables() {
  cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

# Thiết lập thư mục làm việc và tải xuống địa chỉ IP
echo "Đang cài đặt các ứng dụng cần thiết"
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "Thư mục làm việc = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

# Lấy địa chỉ IPv4 của máy
IP4=$(curl -4 -s icanhazip.com)
echo "Địa chỉ IP nội bộ = ${IP4}"

# Yêu cầu người dùng nhập số lượng proxy cần tạo
echo "Bạn muốn tạo bao nhiêu proxy? Ví dụ: 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

# Tạo file cấu hình và cài đặt
gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
chmod +x boot_*.sh /etc/rc.local

# Tạo file cấu hình cho 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Thêm vào rc.local để khởi động cùng hệ thống
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
ulimit -n 10048
service 3proxy start
EOF

# Chạy rc.local để khởi động cấu hình
bash /etc/rc.local

# Tạo file proxy cho người dùng
gen_proxy_file_for_user

# Upload file proxy
install_jq
upload_2file
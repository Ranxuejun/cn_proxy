FROM centos:6.4
ADD . /src
EXPOSE 80:80

RUN iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Bother to set a locale, mostly for ruby
RUN localedef --no-archive -i en_US -f UTF-8 en_US.UTF-8 
ENV LC_CTYPE en_US.UTF-8
ENV LANG en_US.UTF-8

# Install build tools
RUN yum groupinstall -y 'Development Tools'

# Install package dependencies
RUN yum install -y libxslt libxml2 openssl openssl-devel raptor wget libev libev-devel
RUN yum install -y apr-devel apr-util-devel httpd httpd-devel curl curl-devel zlib zlib-devel

# Install js from EPEL (extra packages)
RUN cd /tmp; wget http://ftp.riken.jp/Linux/fedora/epel/RPM-GPG-KEY-EPEL-6
RUN cd /tmp; rpm --import RPM-GPG-KEY-EPEL-6
RUN cd /tmp; wget http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
RUN cd /tmp; rpm -ivh epel-release-6-8.noarch.rpm
RUN yum install -y js

# Install ruby
RUN cd /tmp; wget ftp://ftp.ruby-lang.org//pub/ruby/1.9/ruby-1.9.2-p180.tar.gz
RUN cd /tmp; tar zxvf ruby-1.9.2-p180.tar.gz
RUN cd /tmp/ruby-1.9.2-p180; ./configure
RUN cd /tmp/ruby-1.9.2-p180; make
RUN cd /tmp/ruby-1.9.2-p180; make install

# Install gems
RUN gem install --no-rdoc --no-ri bundler passenger
RUN cd /src; bundle install

# Install passenger
RUN passenger-install-apache2-module --auto
RUN passenger-install-apache2-module --snippet >> /etc/httpd/conf/httpd.conf

# Set up virtual hosts
RUN cp /src/config/cn_proxy.conf /etc/httpd/conf.d/cn_proxy.conf

# Disable selinux and iptables
RUN echo 0 > /selinux/enforce

# Run!
CMD httpd -f /etc/httpd/conf/httpd.conf -D FOREGROUND 
